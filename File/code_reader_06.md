#SDWebImage源码解读 (六)

暂时告一段落，剩余的有时间再去阅读。
这里准备写一下相关的问题。
![](https://ws4.sinaimg.cn/large/006tNbRwly1fw9j22ymlpj310c0qwtj1.jpg)
![](https://ws4.sinaimg.cn/large/006tNbRwly1fw9j2i2012j31e40inae0.jpg)
## （一） 加载大图的内存暴涨的原因
这个应该写到压缩解码里的。但是那边没写完，就放到这里。
```
[[SDImageCache sharedImageCache] setShouldDecompressImages:NO];
[[SDWebImageDownloader sharedDownloader] setShouldDecompressImages:NO];
```
使用这两个方法。
我们将图片存储的时候，是二维化的存储的，会将图像存储为位图数据，如果图像过大，将它存储的结果也会过大。这个是空间换时间的做法，但是同样会也带来内存暴涨，甚至被系统干掉的危险。
所以，为了避免这种情况，我们可能要对大图片做专门的设计。比如说点击高清，或者停止缓存。
有关解码[可以查看这篇文章](http://blog.leichunfeng.com/blog/2017/02/20/talking-about-the-decompression-of-the-image-in-ios/)
## （二） setNeedsLayout方法的作用
直接点说，就是给当前的UIView添加一个标记，让它马上开始刷新布局。
我们可以看一下官方解释
```
Invalidates the current layout of the receiver and triggers a layout update during the next update cycle.
Call this method on your application’s main thread when you want to adjust the layout of a view’s subviews. This method makes a note of the request and returns immediately. Because this method does not force an immediate update, but instead waits for the next update cycle, you can use it to invalidate the layout of multiple views before any of those views are updated. This behavior allows you to consolidate all of your layout updates to one update cycle, which is usually better for performance.
使接收器的当前布局无效，并在下一更新周期触发布局更新。
当您想调整视图的子视图布局时，请在应用程序的主线程上调用此方法。该方法记录请求并立即返回。因为此方法不强制立即更新，而是等待下一个更新周期，所以您可以使用它来在更新任何视图之前使多个视图的布局无效。这种行为允许您将所有布局更新合并到一个更新周期，这通常对性能更好。
```
![](https://ws4.sinaimg.cn/large/006tNbRwly1fw9l4lop5ej30yu0icqeu.jpg)
这里我们借用这张图，简单阐述一下（只说最右边的方框内的方法）：
> 在Touches传递到了视图上的时候，会调整视图的UI属性，比如frame，透明度神马的；会被表示为setNeedsLayout；会被标识为setNeedsDisplay。
> 接着会被传到layoutSubviews，如果确定要被重新布局，就会开始调用layoutsubviews方法；
> 如果需要重新绘制，会调用drawRect方法。

这里要了解一个概念：[The View Drawing Cycle](https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/ViewPG_iPhoneOS/WindowsandViews/WindowsandViews.html#//apple_ref/doc/uid/TP40009503-CH2-SW9)

>The UIView class uses an on-demand drawing model for presenting content. When a view first appears on the screen, the system asks it to draw its content. The system captures a snapshot of this content and uses that snapshot as the view’s visual representation. If you never change the view’s content, the view’s drawing code may never be called again. The snapshot image is reused for most operations involving the view. If you do change the content, you notify the system that the view has changed. The view then repeats the process of drawing the view and capturing a snapshot of the new results.
When the contents of your view change, you do not redraw those changes directly. Instead, you invalidate the view using either the setNeedsDisplay or setNeedsDisplayInRect: method. These methods tell the system that the contents of the view changed and need to be redrawn at the next opportunity. The system waits until the end of the current run loop before initiating any drawing operations. This delay gives you a chance to invalidate multiple views, add or remove views from your hierarchy, hide views, resize views, and reposition views all at once. All of the changes you make are then reflected at the same time.

我们可以很容易的理解，将多次修改聚合到一起，放进一个runloop中统一管理，以节约性能，而不至于重复性的去修改UI。
> 这里顺便加上layoutIfNeeded的要点：
 如果发现了需要刷新的标记，会立即调用layoutSubview方法去进行布局。
 所以我们想要立即刷新的时候，需要这么写
 ```
[self setNeedsLayout];
[self layoutIfNeeded];
 ```
 
## （三） 为什么替换@synchronize
简单的说，就是@synchronize性能太差了点。而替代者dispatch_semaphore在保证安全的情况下，是性能最高的。

## （四）block和delegate的区别
只限于SDWebImage中。
类似于单个图片的下载这种使用次数不多的，可以选择使用block；
如果方法很多，或者想要方法长驻，可以选择delegate方法。

## （五）NSMapTable的使用
NSMapTable本身就是可变类型，可以看做是NSMutableDictionary的一种替代。
而NSDictionary对key会进行copy，对value有强引用。
简单来讲，NSMapTable更加灵活。
## （六）啥是内联函数
内联函数是C++的一个概念。
我们编写代码的时候会编写各种各样的函数来方便调用。但是，函数调用的本身是会降低程序的执行效率，增加时间和空间方面的开销。因此，对于一些功能简单，规模小且使用频繁的函数，就设计成为了内联函数。
内联函数不是在调用的时候发生控制转移，而是在编译时将函数体嵌入在每一个调用处。
它和宏有着本质上的区别。
宏是在代码处不加任何验证的简单替代，而内联函数是将代码直接插入调用处，而减少了普通函数调用时的资源消耗。
1.内联函数在运行时可调试，而宏定义不可以;
2.编译器会对内联函数的参数类型做安全检查或自动类型转换（同普通函数），而宏定义则不会； 
3.内联函数可以访问类的成员变量，宏定义则不能； 

> 但是有一点要注意，iinline关键字只是表示了一个要求，编译器不一定一定会把inline关键字修饰的函数作为内联函数。


 



