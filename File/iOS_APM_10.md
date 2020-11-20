# 从MLeaksFinder理解如何实时监测内存泄露

内存是移动设备上的共享资源，如果一个 App 无法正确地进行内存管理的话，将会导致内存消耗殆尽，闪退以及性能的严重下降。
我们的App的许多功能模块共用了同一份内存空间，如果其中的某一个模块消耗了特别多的内存资源的话，将会对整个 App 造成严重影响。
> 注意：我们下文中的各种情景，都是基于 ARC。

# 一般检测内存泄露的几种方式
我们在开发的时候，有些非常明显的内存泄露，编译器会直接发现并警告出来的，比如下图

## 静态检测
![静态内存泄露.png](https://upload-images.jianshu.io/upload_images/1342490-634f558aac3ed8e7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

或者，我们也可以使用 Product->Analyze，进一步的发现一些浅显简单的内存泄露，当然，这种方式实际上并不是我们研究的重点，因为这种方式太简单浅显了。

## Instrument
Instrument 现在是 Xcode 自带的一个测试工具了。我们可以使用里面的 Leaks/Allocations 进行内存泄露的排查。

> 从苹果的开发者文档里可以看到，一个 app 的内存分三类：

> * **Leaked memory**: Memory unreferenced by your application that cannot be used again or freed (also detectable by using the Leaks instrument).
> * **Abandoned memory**: Memory still referenced by your application that has no useful purpose.
> * **Cached memory**: Memory still referenced by your application that might be used again for better performance.

Leaks 工具只负责检测 Leaked memory,在 MRC 时代 Leaked memory 很常见，因为很容易忘了调用 release，但在 ARC 时代更常见的内存泄露是循环引用导致的 Abandoned memory，Leaks 工具查不出这类内存泄露，应用有限。

对于 Abandoned memory，可以用 Instrument 的 Allocations 检测出来。检测方法是用 Mark Generation 的方式，当你每次点击 Mark Generation 时，Allocations 会生成当前 App 的内存快照，而且 Allocations 会记录从上回内存快照到这次内存快照这个时间段内，新分配的内存信息。举一个最简单的例子：

我们可以不断重复 push 和 pop 同一个 UIViewController，理论上来说，push 之前跟 pop 之后，app 会回到相同的状态。因此，在 push 过程中新分配的内存，在 pop 之后应该被 dealloc 掉，除了前几次 push 可能有预热数据和 cache 数据的情况。如果在数次 push 跟 pop 之后，内存还不断增长，则有内存泄露。因此，我们在每回 push 之前跟 pop 之后，都 Mark Generation 一下，以此观察内存是不是无限制增长。这个方法在 WWDC 的视频里：[Session 311 - Advanced Memory Analysis with Instruments](https://link.jianshu.com?t=http://developer.apple.com/videos/wwdc/2010/)，以及苹果的开发者文档：[Finding Abandoned Memory](https://link.jianshu.com?t=https://developer.apple.com/library/mac/recipes/Instruments_help_articles/FindingAbandonedMemory/FindingAbandonedMemory.html) 里有介绍。

> 用这种方法来发现内存泄露还是很不方便的：
> * 首先，你得打开 Allocations
> * 其次，你得一个个场景去重复的操作
> * 无法及时得知泄露，得专门做一遍上述操作，十分繁琐

## MLeaksFinder
[MLeaksFinder](https://link.jianshu.com/?t=https://github.com/Zepo/MLeaksFinder) 提供了内存泄露检测更好的解决方案。
1、只需要引入 MLeaksFinder，就可以自动在 App 运行过程检测到内存泄露的对象并立即提醒，
2、无需打开额外的工具。
3、也无需为了检测内存泄露而一个个场景去重复地操作。

原理：当一个 ViewController 被 pop 或 dismiss 之后，我们认为该 ViewController，包括它上面的子 ViewController，以及它的 View，View 的 subView 等等，都很快会被释放，如果某个 View 或者 ViewController 没释放，我们就认为该对象泄漏了。
### 源码解读
#### 1.MLeaksFinder.h
```
#import "NSObject+MemoryLeak.h"

//#define MEMORY_LEAKS_FINDER_ENABLED 0

#ifdef MEMORY_LEAKS_FINDER_ENABLED

//_INTERNAL_MLF_ENABLED 宏用来控制 MLLeaksFinder库
//什么时候开启检测，可以自定义这个时机，默认则是在DEBUG模式下会启动，RELEASE模式下不启动
//它是通过预编译来实现的
#define _INTERNAL_MLF_ENABLED MEMORY_LEAKS_FINDER_ENABLED
#else
#define _INTERNAL_MLF_ENABLED DEBUG
#endif

//_INTERNAL_MLF_RC_ENABLED 宏用来控制 是否开启循环引用的检测
#define MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED 0

#ifdef MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED
#define _INTERNAL_MLF_RC_ENABLED MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED
//COCOAPODS 因为MLeaksFinder引用了第三库(FBRetainCycleDetector)用来检查循环引用，所以必须是当前项目中使用了COCOAPODS，才能使用这个功能。
#elif COCOAPODS
#define _INTERNAL_MLF_RC_ENABLED COCOAPODS
#endif
```
_INTERNAL_MLF_ENABLED 作为条件编译的表达式判断条件，用于控制MLeaksFinder的其他文件是否参与编译，在发布环境下，_INTERNAL_MLF_ENABLED为0，那么相当于该库的功能关闭。如果需要无论是调试环境还是发布环境都关闭代码，可以解注释#define MEMORY_LEAKS_FINDER_ENABLED 0. _INTERNAL_MLF_RC_ENABLED表示是否导入**FBAssociationManager**来监测循环引用。默认不开启

#### 2.MLeaksMessenger
这个文件主要负责展示内存泄露。
`MLeaksMessenger.h` 中有两个方法
```
+ (void)alertWithTitle:(NSString *)title message:(NSString *)message;
+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle;
```
我们查看.m文件可以发现，后一个方法实际上是第一个方法的 **Designated Initializer**，我们可以称之为**全能初始化方法**

```
#import "MLeaksMessenger.h"
static __weak UIAlertView *alertView;
@implementation MLeaksMessenger
+ (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    [self alertWithTitle:title message:message delegate:nil additionalButtonTitle:nil];
}
+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle {
    [alertView dismissWithClickedButtonIndex:0 animated:NO];
    UIAlertView *alertViewTemp = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:delegate
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:additionalButtonTitle, nil];
    [alertViewTemp show];
    alertView = alertViewTemp;
    
    NSLog(@"%@: %@", title, message);
}
@end
```

> 这里运用了一个技巧：使用静态全局变量用 `__weak` 修饰变量。

* **static __weak UIAlertView *alertView;**
        第一次调用**[alertView dismissWithClickedButtonIndex:0 animated:NO];**这个方法的时候，alertView为nil,  **[alertView dismissWithClickedButtonIndex:0 animated:NO]**不产生任何操作，只是一个弹框。
        再次调用这个方法(即点击查看retain cycle)，会通过alertView来dimiss现有的弹框，再显示新的弹框。所以alertView是记录当前显示的内存泄漏的弹框。同时设置__weak修饰让这个全局变量弱引用。一旦弹框消失，自动设置为nil.

### 3.MLeakedObjectProxy
这个文件是检测内存泄露的核心文件
对外提供了两个方法：

```
+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs;
+ (void)addLeakedObject:(id)object;
```

第一个方法用来判断 ptrs（NSSet类型）中是否有泄漏的对象，如果有返回 True
第二个方法是将对象加入泄漏对象的集合，同时调用 MLeaksMessenger 的弹窗方法
无论是判断还是比较，始终需要一个集合来保存所有泄漏对象。自然而然检查 MLeakedObjectProxy。

全局 static 变量 **static NSMutableSet** 、 **leakedObjectPtrs;** 就是用来做比较的对象。
上面两个方法都只在 NSObject 的 category 的 **assertNotDealloc** 中调用。

让我们看一下.m文件中方法的实现：

```
//用来检查当前泄漏对象是否已经添加到泄漏对象集合中，如果是，就不再添加也不再提示开发者
+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    /*
     #define NSAssert(condition, desc)
     condition是一个表达式，如果表达式为false，那么就抛出一个异常，并且在日志中输出desc内容。
     desc可以忽略不写。
     表达式为true时，不执行任何操作。
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        leakedObjectPtrs = [[NSMutableSet alloc] init];
    });
    
    if (!ptrs.count) {
        return NO;
    }
    //intersectsSet判断两个集合的交集是否至少存在一个元素
    //防止 addLeakedObject多次被调用
    if ([leakedObjectPtrs intersectsSet:ptrs]) {
        return YES;
    } else {
        return NO;
    }
}
+ (void)addLeakedObject:(id)object {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    //创建用于检查循环引用的objectProxy对象
    MLeakedObjectProxy *proxy = [[MLeakedObjectProxy alloc] init];
    proxy.object = object;
    proxy.objectPtr = @((uintptr_t)object);
    proxy.viewStack = [object viewStack];
    static const void *const kLeakedObjectProxyKey = &kLeakedObjectProxyKey;
    objc_setAssociatedObject(object, kLeakedObjectProxyKey, proxy, OBJC_ASSOCIATION_RETAIN);
    //将自己封装成 MLeakedObjectProxy对象加入leakedObjectPtrs中
    [leakedObjectPtrs addObject:proxy.objectPtr];
    
#if _INTERNAL_MLF_RC_ENABLED
    //带有循环引用检查功能的提示框
    [MLeaksMessenger alertWithTitle:@"Memory Leak"
                            message:[NSString stringWithFormat:@"%@", proxy.viewStack]
                           delegate:proxy
              additionalButtonTitle:@"Retain Cycle"];
#else
    //普通提示框
    [MLeaksMessenger alertWithTitle:@"Memory Leak"
                            message:[NSString stringWithFormat:@"%@", proxy.viewStack]];
#endif

- (void)dealloc {
    NSNumber *objectPtr = _objectPtr;
    NSArray *viewStack = _viewStack;
    dispatch_async(dispatch_get_main_queue(), ^{
        [leakedObjectPtrs removeObject:objectPtr];
        [MLeaksMessenger alertWithTitle:@"Object Deallocated"
                                message:[NSString stringWithFormat:@"%@", viewStack]];
    });
}
}
```

在上述两个方法的实现中，我们发现了几个要点
> * 使用这两个方法必须要在主线程中使用
> *  待检查的对象，必须要检查是否已经被记录，以防止重复添加，造成循环

展示循环引用的核心代码在下面：

```
#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (!buttonIndex) {
        return;
    }
    
    id object = self.object;
    if (!object) {
        return;
    }
    
#if _INTERNAL_MLF_RC_ENABLED
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
        [detector addCandidate:self.object];
        NSSet *retainCycles = [detector findRetainCyclesWithMaxCycleLength:20];
        
        BOOL hasFound = NO;
        //retainCycles中是找到的所有循环引用的链,所形成的循环引用树
        for (NSArray *retainCycle in retainCycles) {
            NSInteger index = 0;
            for (FBObjectiveCGraphElement *element in retainCycle) {
                //找到当前内存泄漏对象所在的循环引用的链
                if (element.object == object) {
                    //把当前对象调整到第一个的位置，方便查看
                    NSArray *shiftedRetainCycle = [self shiftArray:retainCycle toIndex:index];
                    //回到主线程展示
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MLeaksMessenger alertWithTitle:@"Retain Cycle"
                                                message:[NSString stringWithFormat:@"%@", shiftedRetainCycle]];
                    });
                    hasFound = YES;
                    break;
                }
                
                ++index;
            }
            if (hasFound) {
                break;
            }
        }
        if (!hasFound) {
            //回到主线程展示
            dispatch_async(dispatch_get_main_queue(), ^{
                [MLeaksMessenger alertWithTitle:@"Retain Cycle"
                                        message:@"Fail to find a retain cycle"];
            });
        }
    });
#endif
}
//把当前对象调整到第一个的位置，方便查看
- (NSArray *)shiftArray:(NSArray *)array toIndex:(NSInteger)index {
    if (index == 0) {
        return array;
    }
    
    NSRange range = NSMakeRange(index, array.count - index);
    NSMutableArray *result = [[array subarrayWithRange:range] mutableCopy];
    [result addObjectsFromArray:[array subarrayWithRange:NSMakeRange(0, index)]];
    return result;
}
```

我们发现，MLeaksFinder 在展示循环引用的时候，使用的是 **Facebook** 开源的  **FBRetainCycleDetector** 工具。
我们先通过 MLeaksFinder 找到内存泄漏的对象，然后再过 FBRetainCycleDetector 检测该对象有没有循环引用。
有关 FBRetainCycleDetector，我们可以查阅[这篇文章](https://code.facebook.com/posts/583946315094347/automatic-memory-leak-detection-on-ios/?spm=a2c4e.11153940.blogcont68473.11.3d804fa4z2vkPs)（需要科学上网）。

我们实际上可以了解，FBRetainCycleDetector 是将一个对象，一个 ViewController,或者一个 block 当成一个节点，相关的强引用关系则是线。他们实际上会形成有向无环图（DAG 图），我们则需要在其中寻找可能存在的环，这里使用了深度优先搜索算法来遍历它，并找到循环节点。

### 4.NSObject+MemoryLeak


这个文件主要用来存储对象的父子节点的树形结构，method swizzle 逻辑 ，白名单以及实施判断对象是否发生内存泄漏。

```
- (BOOL)willDealloc {
    NSString *className = NSStringFromClass([self class]);
    if ([[NSObject classNamesWhitelist] containsObject:className])
        return NO;
    NSNumber *senderPtr = objc_getAssociatedObject([UIApplication sharedApplication], kLatestSenderKey);
    if ([senderPtr isEqualToNumber:@((uintptr_t)self)])
        return NO;
    
    __weak id weakSelf = self;
    //在特定时间检查对象是否已经发生内存泄漏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong id strongSelf = weakSelf;
        [strongSelf assertNotDealloc];
    });
    
    return YES;
}
```
这个方法对外的时候主要是用来提供给各个方法退出的时候调用的。而内部，则是先筛选不会报告的若干情况，以下是三个判断条件：

> * [[NSObject classNamesInWhiteList] containsObject:className]为True.
显而易见，这个方法是判断是否加入白名单
> * [senderPtr isEqualToNumber:@((uintptr_t)self)]为True.
介绍在下方
> * __strong id strongSelf = weakSelf;中的strongify为nil.
这里先设置 __weak id weakSelf = self;，然后在进行__strong id strongSelf = weakSelf，假如对象已经被释放，strongSelf为nil 调用该方法什么也不发生。

这里我说明下第二条：

正在执行 target-Action 的 target 对象不监测内存泄漏。当用户触发执行 Target-Action 方法的时候，实际上在执行action方法前，是sender对象先执行**sendAction:to:forEvent**方法，然后**UIApplicatoin**执行
**sendAction:to:from:forEvent:**方法，其中from就是sender对象.
这里使用方法交换截获**sendAction:to:from:forEvent:**,然后截获了当前sender对象保存在kLatestSenderKey中。判断两者是否相同。
这里的原因涉及到了target-action原理，当前实际上会形成一个循环引用，这里推荐[这篇文章](http://southpeak.github.io/2015/12/13/cocoa-uikit-uicontrol/),我们可以得出结论
>对于_target成员变量，在UIControlTargetAction的初始化方法中调用了objc_storeWeak，即这个成员变量对外部传进来的target对象是以weak的方式引用的。

而如果发生恩泄露，则会调用以下方法：
```
- (void)assertNotDealloc {
    if ([MLeakedObjectProxy isAnyObjectLeakedAtPtrs:[self parentPtrs]]) {
        return;
    }
    [MLeakedObjectProxy addLeakedObject:self];
    
    NSString *className = NSStringFromClass([self class]);
    NSLog(@"Possibly Memory Leak.\nIn case that %@ should not be dealloced, override -willDealloc in %@ by returning NO.\nView-ViewController stack: %@", className, className, [self viewStack]);
}
```
这里面就是直接的判断方法了，作用在之前提过。
**-(void)willReleaseObject:(id)object relationship:(NSString *)relationship;***这个方法我没有查阅到相关引用，可能是已经废弃。如果有知道的，请不吝赐教。

接下来分析下面三个关键的方法：
```
- (void)willReleaseChild:(id)child;
- (void)willReleaseChildren:(NSArray *)children;
- (NSArray *)viewStack;
```
- (void)willReleaseChild:(id)child 其实只是将child对象添加到一个数组中执行 - (void)willReleaseChildren:(NSArray *)children方法
```
- (void)willReleaseChild:(id)child {
    if (!child) {
        return;
    }
    
    [self willReleaseChildren:@[ child ]];
}
```
第一个方法只在UIViewController+MemoryLeak中执行，
```
- (BOOL)willDealloc {
    if (![super willDealloc]) {
        return NO;
    }
    
    [self willReleaseChildren:self.childViewControllers];
    [self willReleaseChild:self.presentedViewController];
    if (self.isViewLoaded) {
        //判断一个UIViewController的view是否已经被加载
        [self willReleaseChild:self.view];
    }
    
    return YES;
}
```
而后一个方法则在很多地方都有执行，其内部实现如下
```
- (void)willReleaseChildren:(NSArray *)children {
    //NSArray *viewStack = [self viewStack];
    //NSSet *parentPtrs = [self parentPtrs];
    for (id child in children) {
        //NSString *className = NSStringFromClass([child class]);
        //[child setViewStack:[viewStack arrayByAddingObject:className]];
       // [child setParentPtrs:[parentPtrs setByAddingObject:@((uintptr_t)child)]];
        [child willDealloc];
    }
}
```
注释掉无关的代码，我们实际上发现，这里循环调用**willDealloc**方法。而注释掉的方法则是递归self.view，写入一个栈**viewStack**当中，最后在Alertview中展示出来。
构造堆栈信息的原理就是，递归遍历子对象，然后将父对象 class name 加上子对象 class name，一步步构造出一个 view stack。出现泄漏则直接打印此对象的 view stack 即可。


**+(void)addClassNamesToWhitelist:(NSArray *)classNames;***方法则一目了然，用于添加白名单。
最后一个方法
```
+ (void)swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL {
    //通过预编译控制是否hook方法
#if _INTERNAL_MLF_ENABLED
    //通过预编译控制是否检查循环引用
#if _INTERNAL_MLF_RC_ENABLED
    // Just find a place to set up FBRetainCycleDetector.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [FBAssociationManager hook];
        });
    });
#endif
    
    Class class = [self class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    BOOL didAddMethod =
    /*
    class_addMethod主要是用来给某个类添加一个方法，originalSEL相当于是方法名称,method_getImplementtation是方法实现, 它返回一个BOOL类型的值,在当前class中没有叫originalSEL的方法(具体不是看interface里没有没有声明，而是看implementaion文件里有没有方法实现)，并且有swizzledMethod方法的实现,这个时候该函数会返回true，其他情况均返回false
    */
    class_addMethod(class,
                    originalSEL,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        //didAddMethod为true 说明swizzledMethod之前不存在，通过class_addMethod函数添加了一个名字叫origninalSEL，实现swizzledMoethod函数。
        class_replaceMethod(class,
                            swizzledSEL,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        //didAddMethod为false 说明swizzledMethod方法已经存在，直接交换二者实现

        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
#endif
}
```

> 中间那一段BOOL类型的使用原因 
" 周全起见，有两种情况要考虑一下。第一种情况是要复写的方法(overridden)并没有在目标类中实现(notimplemented)，而是在其父类中实现了。第二种情况是这个方法已经存在于目标类中(does existin the class itself)。这两种情况要区别对待。 (译注: 这个地方有点要明确一下，它的目的是为了使用一个重写的方法替换掉原来的方法。但重写的方法可能是在父类中重写的，也可能是在子类中重写的。) 对于第一种情况，应当先在目标类增加一个新的实现方法(override)，然后将复写的方法替换为原先(的实现(original one)。 对于第二情况(在目标类重写的方法)。这时可以通过method_exchangeImplementations来完成交换."

这个方法为其他分类统一给出了一个Method Swizzling的方法。
### 其他类
关于其他类，基本上都是实现了交换方法。不细说。

### 总结

MleaksFinder中使用了AOP的思想，不会插入到业务代码当中，即插即用。检测流程可以简化为：
>1. 给分类统一提供一个交换方法的方法（此方法保证一定可以交换方法）
> 2.  然后在运行中统一遍历view，viewController，将名字加入栈中
>3. 规避掉一些方法（白名单，Target-Action方法）
>4.  检测是否有循环引用


但是，MLeaksFinder还是有些局限性。我们需要将其添加进cocoaPods当中，会影响App包的大小，另一方面，我们有时候需要随时添加一些白名单，另外，由于本身设计时考虑不完全，或者apple本身的错误，也会产生一些不必要的错误。
> 发生的缺点：
1.cocoaPods加入时无法区分编译环境
2.iOS 11.2之后textField都会报错（这个应该是apple的错误）
3.本身加上引用也会占用一部分大小
4.有时debug会闪退（这个可能是Facebook的错误，但是由于cocoaPods无法修改）

这时候，我们就需要发动自己的头脑了。
在当时的实际开发当中，我借鉴了MLeaksFinder的代码设计思路，将其改进。我当时实现了一个大的监测工具，将页面FPS监测，内存泄露检测，页面卡顿检测陆续的加入其中，并在使用时手动引入，在需要发布时，再手动取出，以减小包的大小。

[MLeaksFinder 新特性](http://wereadteam.github.io/2016/07/20/MLeaksFinder2/)
[UIKit: UIControl](http://southpeak.github.io/2015/12/13/cocoa-uikit-uicontrol/)
[Automatic memory leak detection on iOS](https://code.facebook.com/posts/583946315094347/automatic-memory-leak-detection-on-ios/)