# iOS启动优化简述：图像加载



1. 布局计算优化
2. 对象创建优化（不必要的不创建、懒加载）
3. 文本计算/渲染
4. 图像绘制
5. 图片的解码
6. 控制图片的清晰度

# 一般计算机的渲染过程

我们看到的屏幕上展示的动画，其实是一连串连续的静态画面，因为图像变化速度过快，所以我们会觉得看到的画面是动的，如果一秒钟展示的画面非常多，那么就会让我们觉得动画是流畅的。

这里面每展示一次的静态画面，被称为之一帧。一秒钟展示的画面数量，就是帧数，比如一秒钟展示了60张静态画面，那么帧数就是60，即 FPS（Frames Per Second：每秒传输帧数)为60。

电脑里的帧是由GPU渲染出来的，你看到的动画，都是由GPU一张一张画出来的， 并输出到显示屏上。 60 FPS即为GPU在这一秒里画出了60张静态画面，然后发送给了显示器。

当显示器接收到这些静态画面之后，还需要进行展示到显示屏上才可以看见。

<font color=red  size=5>此处应有图片</font>

显示器在进行显示的时候，并不是轮播图一般一张一张进行播放的，而是进行的逐行扫描（Progressive Scan）完成的，在接收到一张完整的静态画面之后，会从屏幕的左上角开始逐行进行绘制。当绘制到右下角的时候，会重新回到左上角重新开始绘制过程。

这个过程被称为 Vertical Blanking Interval，简称 VBI 或者 V-Blank。

每秒钟 VBI 的数量，就是屏幕的刷新率。60Hz的屏幕，就是这个屏幕在1 秒内可以可以进行60词逐行扫描过程。

## FrameBuffer

 但是因为GPU在渲染传出图像的过程可能不是稳定的，和显示器的帧率不一致，所以这里使用了一个 FrameBuffer（帧缓存）的技术。
 
 一般情况下有两个FrameBuffer，FrontBuffer和BackBuffer，即前缓存和后缓存。
 
 显卡在渲染静态画面的时候并不会直接将其传递给显示器，而是先写入BackBuffer。在BackBuffer写入完毕之后，与FrontBuffer发生交替，这个过程被称之为BufferSwap。
 
 <font color=red  size=5>此处应有图片</font>
 
 
 如果显示器的刷新率和GPU的FPS是匹配的，那么GPU会按部就班的绘制 BackBuffer，显示器按部就班的绘制FrontBuffer，在每次BufferSwap都是发生在双方刚好绘制完成。
 
 但是我们都知道，GPU 的帧率有时候并不如我们所想的那样稳定绘图，有可能会发生不匹配。
 
 举个例子，如果GPU的绘制速度没有显示器快。
 
 
 
 
 显示器在显示 帧A，正在逐行扫描FrontBuffer里的帧B，GPU在绘制BackBuffer里的帧C，如果这时候GPU的绘制速度没有显示器快，显示器在绘制完成展示帧B之后GPU还没有绘制完成，不会发生帧传递，俺么显示器会重新绘制一次帧B；在第二次绘制帧 B 的过程时，帧C绘制完成，此时发生帧传递，显示器开始绘制帧C，那么就会发生，显示器的上半部分绘制的是帧B，下半部分绘制的是帧C的情况了。
 
 
 这种情况被称之为画面撕裂。



<font color=red  size=5>此处应有图片</font>



解决画面撕裂的一个最有效的办法技术垂直同步，垂直同步会强制帧传递，发生在显示器的VBlank的完成阶段。如果显卡绘制完成，但是显示器没有完成一次完整的 VBlank ，就不会允许发生真传递，GPU 就在这里空等待显示器绘制完成。 等待绘制完成，再允许发生帧传递。


所以说，显卡的刷新率会被限制在显示器的刷新率之下，最大的帧率只能是显示器的刷新率了。

但是如果显卡性能在某一时刻不足以输出60帧时，显示器会重新绘制一次Front缓存，等待下次Vblank的时候，如果GPU画好了，在执行帧传递。


这就相当于降低了显示器的刷新率，所以，会发生画面不流畅的现象了。也就是我们常说的”掉帧“。



# iOS 中的渲染流程

在这里，只记录 Core Animation 过程。

Core Animation 并不如名字一样只是用于绘制动画的，实际上，我们能看到的绝大多数视图，都是由 Core Animation进行绘制的。如下图所示。

![](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/Art/ca_architecture_2x.png)



todo：分析UIView 和CALayer




Core Animation 是基于直接作用域 GPU 的 Metal 和基于CPU 的 Core Graphics。

<!--![](https://upload-images.jianshu.io/upload_images/1776554-90c595e36d3694bd.png)-->






![](https://raw.githubusercontent.com/RickeyBoy/Rickey-iOS-Notes/master/backups/iOSRender/CApipeline.png)









