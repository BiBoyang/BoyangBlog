# UI操作为什么不应该在子线程中操作

# 前言
> 讲道理，都9021年了，不应该在写这个问题了，不过最近恰好想要整理一下自己的思绪，就趁着还关注的这个问题，就写下来，权当记录自己的想法。文章比较务虚，大多数是自己的想法，可能会比较片面。

本来想把题目写成：“UI操作为什么要在主线程中操作”，但是想来，这么起标题有些不严谨，就换个**相对**严谨的标题。

我们但凡开始做iOS开发的那一天开始，就经常听到关于UI不能在子线程操作的警告。我们已经把这句话都快融进骨子离了，但是这种事情还是会时有发生，最典型是案例就是在子线程里去进行图片的加载。

# UI线程不安全
我们其实都明白，UI其实是一个比较笼统的概念，我们能看到的所有东西都可以称之为UI。换句话说，UI是使用者直接接触，并且操作的东西，甚至算得上用户体验的最直接的度量。如果在UI上出了问题，会极大地打击用户的使用感受，造成大问题。而UI的线程的安全与否，也是我们直接需要关注的事，因为这里实在是太容易出问题了。

我们一般创建UI的时候会使用属性，比如这样：
```C++
@property (nonatomic, strong) UILabel *label;
```
我们一般都是使用`nonatomic`来修饰UI，这个其实就已经变相表明他们在多线程下的困境----需要自己去控制它们。
在[线程安全类的设计](https://objccn.io/issue-2-4/)这篇老文章中，直接说明了一个简单的答案：
> 对于一个像 UIKit 这样的大型框架，确保它的线程安全将会带来巨大的工作量和成本。将 non-atomic 的属性变为 atomic 的属性只不过是需要做的变化里的微不足道的一小部分。通常来说，你需要同时改变若干个属性，才能看到它所带来的结果。为了解决这个问题，苹果可能不得不提供像 Core Data 中的 performBlock: 和 performBlockAndWait: 那样类似的方法来同步变更。另外你想想看，绝大多数对 UIKit 类的调用其实都是以配置为目的的，这使得将 UIKit 改为线程安全这件事情更显得毫无意义了。


下面我们从多个方向，理解一下UI在多线程上的问题。

# 线程消耗
我们要先说明一个问题：`dealloc`方法其实是可以在子线程中调用的。

为了搭建一个不错的UI页面和效果，我们可能会频繁的创建UI、使用`addSubView`方法、销毁UI。这里的创建、销毁都是需要进行内存操作。如果我们在销毁一个UI的时候，不小心在另外线程中进行了其他的操作（比如说改变颜色），欧吼，UI都没了，还怎么搞啊。这样寻找不到应有的UI，就会直接crash（也应该crash）。那么为了解决这个问题，为了保障UI在不同线程的上的安全操纵，还需要去**加锁**。好吧，这个是一个大消耗！

而且，线程的创建和通信并非毫无消耗的。在子线程上操作UI，你需要频繁的进行线程的切换，尤其是一个控件上的子控件，操作不在一个线程上，可以想象这会造成多大的性能浪费。


# 渲染
我们的iOS，是基于60FPS构建的，也即是说，每两帧的中间时间是16.67ms。在这么短的时间里，会需要完一个UI页面的整个创作。

而一个页面UI的展示，是需要CPU和GPU协同合作的。CPU负责显示内容的创建、布局计算、图片解码、文本绘制，然后再讲计算好的内容提交给GPU，让CPU去进行合成渲染；再接着，GPU会将渲染的结果提交到帧缓冲区，等待展示到屏幕上。

而如果在子线程上操作了UI，最有可能出线两种情况：
> 会导致时间的不同步，页面错乱。本该在这个时间创建出来的UI，结果在下一个渲染区间才出现。
> 多个线程都提出了UI的操作，CPU需要从多个线程去获取将要渲染内容的各种计算，然后提交给GPU统一处理，这个本身就很难同步。

CPU和GPU渲染一个页面已经很累了，就不要再让它们干多余的事了。

# 事件循环和传递
在Cocoa Touch中，在主线程上设置了UIApplication。这是启动应用程序时实例化的应用程序的第一部分，也是最主要的部分；它存在于最开始的那个自动创建的MainRunloop上。当我们点击某个控件的时候，产生了点击事件，是需要通过主线程的Runloop去传递和驱动。

我们可以设想这个这样的情况，有多个子线程去创建了button。而button的点击事件是需要传递到Runloop上才能继续的去传递。如果真的要进行了跨线程的事件传递，平白多耗费时间在切换线程上，会让事件延迟。

并且，我们都知道，UI的变化其实并不是瞬间的变化。如果真要这样，UI一旦多了起来，光互相传递UI操作，让其他UI响应的信息就会随着UI数量的上升而指数型上升。

这里打一个现实的比方。从中国到美国的货运飞机，相当大的一部分，是从中国少数几个起点城市，比如说北京、深圳等起飞，让后降落在少数几个美国城市，比如说西雅图和纽约（你可以从北极点上看地球，你就会发现，为什么会这么飞了）。为什么不让每个发货地都直飞收货地呢？
相信你稍微算一下，就会明白了。

所以，存在一个**总线**是有利于节约资源的，我们可以把主线程的Runloop当成事件的**总线**，所有的事件，不应该去跨越多个线程再传递到Runloop上，直接在统一的单独Runloop上收发，会节约CPU的资源。


# 在主线程上就一定是安全的吗？

那可不一定哦！

这里有一个很经典的[issue](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2635#issuecomment-170215083)，告诉我们在某些特殊的情况下，在主线程操作UI也是不安全的。

在我们不知道这个问题之前，我们常常这么写。
```C++
#define dispatch_main_sync_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_sync(dispatch_get_main_queue(), block);\
    }
```
但是这么来，还是无法防御上面的可能的bug，那么，我们要怎么办呢？换个写法。
```C++
#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
        block();\
    } else {\
        dispatch_async(queue, block);\
    }
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif
```
strcmp()是c语言的字符串比较函数. strcmp(s1，s2) 判断两个字符串s1和s2是否相同，相同== 0； 如果当前线程已经是主线程了，那么在调用`dispatch_async(dispatch_get_main_queue(), block)`有可能会出现crash；如果当前线程不是主线程，调用`dispatch_async(dispatch_get_main_queue(), block)`。 通过这样的判断，可以保证是主线程当前队列。

这个方法是不是很眼熟？没错，这两个都是SDWebImage的宏，只不过上面的是旧的，下面的是新的。

在iOS里，主队列的任务只会在主线程上执行。这个实际上是和Runloop有关系，[这篇文章](http://sindrilin.com/2018/03/03/weird_thread.html)提出了一个想法，我也同样认可。
> * 主队列的Runloop一旦启动，就只会被该线程执行任务
> * 子队列的Runloop无法绑定队列和线程的执行关系

# 如何防范子线程UI
在实际操作中，子线程操作UI还是偶有发生的一个重要原因就是----如果你真的在子线程进行了UI操作，它不是必然崩溃的！很多时候写着写着就这么过去了。

为了防止这个问题，实际上有两种解决办法。
> 1. hook所有的UIView的`setNeedsLayout`、`setNeedsDisplay`、`setNeedsDisplayInRect:`的方法，让它们直接在开发阶段就发出提醒。
> 2. hook所有的UIView的`setNeedsLayout`、`setNeedsDisplay`、`setNeedsDisplayInRect:`的方法，在线上做好防护，让所有子线程的UI操作强制回到主线程上去。

在这里，我强烈推荐第一种方法。这里引用[DoraemonKit](https://github.com/didi/DoraemonKit)的方法。
```C++
@implementation UIView (Doraemon)

+ (void)load{
    [[self  class] doraemon_swizzleInstanceMethodWithOriginSel:@selector(setNeedsLayout) swizzledSel:@selector(doraemon_setNeedsLayout)];
    [[self class] doraemon_swizzleInstanceMethodWithOriginSel:@selector(setNeedsDisplay) swizzledSel:@selector(doraemon_setNeedsDisplay)];
    [[self class] doraemon_swizzleInstanceMethodWithOriginSel:@selector(setNeedsDisplayInRect:) swizzledSel:@selector(doraemon_setNeedsDisplayInRect:)];
}

- (void)doraemon_setNeedsLayout{
    [self doraemon_setNeedsLayout];
    [self uiCheck];
}

- (void)doraemon_setNeedsDisplay{
    [self doraemon_setNeedsDisplay];
    [self uiCheck];
}

- (void)doraemon_setNeedsDisplayInRect:(CGRect)rect{
    [self doraemon_setNeedsDisplayInRect:rect];
    [self uiCheck];
}

- (void)uiCheck{
    if([[DoraemonCacheManager sharedInstance] subThreadUICheckSwitch]){
        if(![NSThread isMainThread]){
            NSString *report = [BSBacktraceLogger bs_backtraceOfCurrentThread];
            NSDictionary *dic = @{
                                  @"title":[DoraemonUtil dateFormatNow],
                                  @"content":report
                                  };
            [[DoraemonSubThreadUICheckManager sharedInstance].checkArray addObject:dic];
        }
    }
}

@end
```
我当初的做法没有这样精细，比较简单粗暴的直接让程序直接闪退，已达到警告的效果。

至于我为什么不采用第二种的方法，是因为我有这样的一个观点：
* hook不应该被滥用，尤其是不应该在线上代码中滥用，如果能不使用hook就能解决问题，就不要使用hook，这是把双刃剑，非常容易伤到自己。

# 引用
[线程安全类的设计](https://objccn.io/issue-2-4/)


