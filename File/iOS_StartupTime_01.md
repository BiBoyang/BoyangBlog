# iOS启动优化简述（一）：总览
因为疫情的缘故待在家中，就把之前做过的启动优化做一个记录，记录遇到过的坑，以及一些技术的探索。文章会夹杂我的一些思考，因为个人水平有限，不免出线疏漏，还请斧正。

# 真正的启动全过程是什么？
在这里，我很想问大家一个问题----**一个真正的App启动过程是什么**？

最开始，我的理解是，一个App从点击图标开始，到App开始运行起来的过程----即点击图标到`didFinishLaunchingWithOptions`的过程。但是当我研究的逐渐深入，并且偶尔跳出一个开发者的视角，去以一个使用者的身份换位思考，便修改了这个想法。

假设一下，我刚刚从睡梦中醒来--昨晚的觉睡得不错--然后去洗了一把脸，随手打开一个应用。这会是个什么过程呢？（我们姑且给这个App起个代号--小A）。
 
 1. 找到熟悉的小A的图标，点击进去；
 2. 嗯，这个应用很好，不带广告直接进入了主页面；
 3. 主页面开始加载动画；
 4. 动画加载完毕，我们看到了首页的内容。


好了，这个就是我们以用户的身份接触到的启动过程。对于用户来说，一个正常的App的启动流程，应该是从点击App图标开始，接收到完整的首页为止--即首页各种元素都渲染完毕。

从这个思路出法，再切换到开发者的视角，我们就可以将这个过程大体上化为三个部分：
1. 点击应用到接触到代码；
2. 发出网络请求；
3. 收到数据开始渲染。

当然，这个过程看起来十分简单，但是这三个环节，每一个环节，都可以拿出来细细拆分成许多次要环节，我们需要从代码加载环节、网络请求环节、页面渲染环节来层层分析，才能真正理解如何优化好一个App的启动过程。

![过程](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/AppStartUp_00.png?raw=true)


## 冷启动x热启动
其实上面的那个流程，有个叫法叫**冷启动**，表示**App完全重启，但是内存中并没有缓存下来什么东西**；而与此对应的则是**热启动**，表示**只是用户按了home键，让App继续在后台存活**。

一般来说，我们启动优化，都是为冷启动做优化。


# 如何检测App的启动时间
这个我们需要分段的去检测：

## pre-main阶段
谢天谢地，苹果提供了一个检测这个阶段的方法。
在 Xcode 中 `Edit scheme` -> `Run` -> `Auguments` 将环境变量**DYLD_PRINT_STATISTICS**设为1 。之后控制台会输出类似内容：
```C++
Total pre-main time: 400.15 milliseconds (100.0%)
         dylib loading time: 211.53 milliseconds (52.8%)
        rebase/binding time:   5.03 milliseconds (1.2%)
            ObjC setup time:  26.33 milliseconds (6.5%)
           initializer time: 157.05 milliseconds (39.2%)
           slowest intializers :
             libSystem.B.dylib :   6.30 milliseconds (1.5%)
    libMainThreadChecker.dylib :  63.60 milliseconds (15.8%)
           DoraemonLoadAnalyze :  24.14 milliseconds (6.0%)
                    PalmTicket :  99.58 milliseconds (24.8%)
```
好吧，在pre-main阶段就耗费了400ms，不优化是真的不行了。

## 后main阶段
mian()阶段主要是测量mian()函数开始执行到didFinishLaunchingWithOptions执行结束的时间，我们直接插入代码就可以了。
```C++
CFAbsoluteTime StartTime;
int main(int argc, char * argv[]) {
      StartTime = CFAbsoluteTimeGetCurrent();
......
```
在AppDelegate.m文件中用extern声明全局变量StartTime
```C++
extern CFAbsoluteTime StartTime;
```
最后在`didFinishLaunchingWithOptions`里，再获取一下当前时间，与StartTime的差值即是main()阶段运行耗时。
```
double launchTime = (CFAbsoluteTimeGetCurrent() - StartTime);
```

## 页面加载完成
这一步是比较麻烦的。因为页面上的元素其实是很多的，每个人都会遇到不同的情况，要针对场景做优化。我评判小A的首页加载完成，是通过`viewDidAppear`的时间来进行评判的。

当然，如果想要粒度更细一点，是可以将图片的加载完成时间当做依据；不过这里有个问题，去检测图片的加载完成时间，一般都使用hook的方式，去添加hook，本身就是增加了一些消耗，而且图片繁多，这点消耗积累起来也不可小觑。

如果不进行代码层面的统计也可以，这里的渲染时间等等，完全可以直接使用**Time Profiler**来进行判断，虽然会有些误差，但是大体没错。


# 其他

除了上述直接检测时间的方法外，我们还需要检测其他的维度以及粒度更细的数据。
### 方法耗时

我们可以使用[Messier](https://messier.app/)来进一步挖掘在主线程上每一个方法的耗时。
不过这个事实上也是优缺点的，因为hook了每一个方法，它自身也会带来一些损耗，造成数据的不稳定。如果非要细致的去分析，最好的办法就是一个方法一个方法的手动埋点。

### 网络耗时
一般到达主页ViewController的时候，我们就会马上发起请求。请求的流程一般如下：

* 1. DNS解析。
        请求DNS服务器，获取域名对应的IP地址。
* 2. SSL/TLS握手+TCP三次握手
        建立连接。
* 3. 发送数据，接收数据。
        整合数据。


### CPU
事实上，在首页中的操作，大多数都是非常耗费CPU资源的操作。CPU的任务一旦过多，很容易造成发热降频，影响了计算力。比如说网络请求中的建立连接和加密解密，下载，图片解码，首页创建过多线程，这些都是消耗CPU资源的大户。

在遇到有些手机的CPU比较落后~~（说的就是你A10芯片，你out了！）~~的情况下，这些都会拉长时间。虽然我们很相信A系列芯片的能力，但是总要多留个心思。**要知道，某些性能已经并非顶尖CPU，它们在仍然在手机上，被很多人使用着。**


### 内存和I/O操作

这个不必过多解释，大家明白，很多让内存暴增的操作，都是耗时操作，需要处理；而I/O操作则是十分消耗CPU的，也是会增加消耗时间的。


# 总结 
简单的说，在一个App的早期，启动时间完全不会是一个性能问题，然而随着开发进程的不断推进，业务复杂度会不断的升高。冷启动时间不可避免的持续增加。当我们真的想要去优化的时候，就会发现现在App的启动优化真的是一个很有趣的问题，有很多值得研究和思考的地方。

在接下来的文章，我会逐步的将启动中的每个流程都细细的拆分，有些东西是经历过实践考研，而有些不过是我的思考，我都会一一奉上。



# 资料
* 经典WWDC视频
        [WWDC2016:Optimizing App Startup Time](https://developer.apple.com/videos/play/wwdc2016/406)
        [WWDC2016:Optimizing I/O for Performance and Battery Life](https://developer.apple.com/videos/play/wwdc2016/719/)
        [WWDC2017:App Startup Time: Past, Present, and Future](https://developer.apple.com/videos/play/wwdc2017/413/)
* 图片的加载过程
        [Core Image: Performance, Prototyping, and Python](https://developer.apple.com/videos/play/wwdc2018/719/)
* Facebook的二进制优化，开拓思路
        [通过优化二进制布局提升iOS启动性能](https://www.bilibili.com/video/BV1NJ411w7hv) 



