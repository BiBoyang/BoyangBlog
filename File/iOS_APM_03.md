# 启动时间
应用启动流程
iOS应用的启动可分为pre-main阶段和main()阶段，其中系统做的事情依次是：
> 1. pre-main阶段
1.1. 加载应用的可执行文件
1.2. 加载动态链接库加载器dyld（dynamic loader）
1.3. dyld递归加载应用所有依赖的dylib（dynamic library 动态链接库）
> 2. main()阶段
2.1. dyld调用main() 
2.2. 调用UIApplicationMain() 
2.3. 调用applicationWillFinishLaunching
2.4. 调用didFinishLaunchingWithOptions

## 启动耗时的测量
在进行优化之前，我们首先应该能测量各阶段的耗时。

### 1. pre-main阶段
对于pre-main阶段，Apple提供了一种测量方法，在 Xcode 中 Edit scheme -> Run -> Auguments 将环境变量DYLD_PRINT_STATISTICS 设为1 。之后控制台会输出类似内容：
```
Total pre-main time: 228.41 milliseconds (100.0%)
         dylib loading time:  82.35 milliseconds (36.0%)
        rebase/binding time:   6.12 milliseconds (2.6%)
            ObjC setup time:   7.82 milliseconds (3.4%)
           initializer time: 132.02 milliseconds (57.8%)
           slowest intializers :
             libSystem.B.dylib : 122.07 milliseconds (53.4%)
                CoreFoundation :   5.59 milliseconds (2.4%)
```
这样我们可以清晰的看到每个耗时了。
### 2.main()阶段
mian()阶段主要是测量mian()函数开始执行到**didFinishLaunchingWithOptions**执行结束的时间，我们直接插入代码就可以了。
```
CFAbsoluteTime StartTime;
int main(int argc, char * argv[]) {
      StartTime = CFAbsoluteTimeGetCurrent();
```
再在AppDelegate.m文件中用extern声明全局变量StartTime
```
extern CFAbsoluteTime StartTime;
```
最后在**didFinishLaunchingWithOptions**里，再获取一下当前时间，与StartTime的差值即是main()阶段运行耗时。
```
double launchTime = (CFAbsoluteTimeGetCurrent() - StartTime);
```
## 改善启动时间
### pre-main阶段
在这一阶段，我们能做的主要是优化dylib
#### 加载 Dylib

之前提到过加载系统的 dylib 很快，因为有优化。但加载内嵌（embedded）的 dylib 文件很占时间，所以尽可能把多个内嵌 dylib 合并成一个来加载，或者使用 static archive。
使用 `dlopen()` 来在运行时懒加载是不建议的，这么做可能会带来一些问题，并且总的开销更大。

#### Rebase/Binding

之前提过 Rebaing 消耗了大量时间在 I/O 上，而在之后的 Binding 就不怎么需要 I/O 了，而是将时间耗费在计算上。所以这两个步骤的耗时是混在一起的。

之前说过可以从查看 `__DATA` 段中需要修正（fix-up）的指针，所以减少指针数量才会减少这部分工作的耗时。对于 ObjC 来说就是减少 `Class`,`selector` 和 `category` 这些元数据的数量。从编码原则和设计模式之类的理论都会鼓励大家多写精致短小的类和方法，并将每部分方法独立出一个类别，其实这会增加启动时间。对于 C++ 来说需要减少虚方法，因为虚方法会创建 vtable，这也会在 `__DATA` 段中创建结构。虽然 C++ 虚方法对启动耗时的增加要比 ObjC 元数据要少，但依然不可忽视。
#### Objc setup
大部分ObjC初始化工作已经在Rebase/Bind阶段做完了，这一步dyld会注册所有声明过的ObjC类，将分类插入到类的方法列表里，再检查每个selector的唯一性。
在这一步倒没什么优化可做的，Rebase/Bind阶段优化好了，这一步的耗时也会减少。
#### Initializers
到了这一阶段，dyld开始运行程序的初始化函数，调用每个Objc类和分类的+load方法，调用C/C++ 中的构造器函数（用attribute((constructor))修饰的函数），和创建非基本类型的C++静态全局变量。Initializers阶段执行完后，dyld开始调用main()函数。
在这一步，我们可以做的优化有：
> 1.少在类的+load方法里做事情，尽量把这些事情推迟到+initiailize
2.减少构造器函数个数，在构造器函数里少做些事情
3.减少C++静态全局变量的个数

### main()阶段的优化
这一阶段的优化主要是减少`didFinishLaunchingWithOptions`方法里的工作，在`didFinishLaunchingWithOptions`方法里，我们会创建应用的window，指定其rootViewController，调用window的`makeKeyAndVisible`方法让其可见。由于业务需要，我们会初始化各个二方/三方库，设置系统UI风格，检查是否需要显示引导页、是否需要登录、是否有新版本等，由于历史原因，这里的代码容易变得比较庞大，启动耗时难以控制。

所以，满足业务需要的前提下，`didFinishLaunchingWithOptions`在主线程里做的事情越少越好。在这一步，我们可以做的优化有：
> 1.梳理各个二方/三方库，找到可以延迟加载的库，做延迟加载处理，比如放到首页控制器的viewDidAppear方法里。
2.梳理业务逻辑，把可以延迟执行的逻辑，做延迟执行处理。比如检查新版本、注册推送通知等逻辑。
3.避免复杂/多余的计算。
4.避免在首页控制器的viewDidLoad和viewWillAppear做太多事情，这2个方法执行完，首页控制器才能显示，部分可以延迟创建的视图应做延迟创建/懒加载处理。
> 5.首页控制器用纯代码方式来构建。

## 总结
总结起来，好像启动速度优化就一句话：让系统在启动期间少做一些事。当然我们得先清楚工程里做的哪些事是在启动期间做的、对启动速度的影响有多大，然后case by case地分析工程代码，通过放到子线程、延迟加载、懒加载等方式让系统在启动期间更轻松些。

## 引用
[阿里数据iOS端启动速度优化的一些经验](https://www.jianshu.com/p/f29b59f4c2b9)
[优化 App 的启动时间](http://yulingtianxia.com/blog/2016/10/30/Optimizing-App-Startup-Time/#%E6%94%B9%E5%96%84%E5%90%AF%E5%8A%A8%E6%97%B6%E9%97%B4) 
[今日头条iOS客户端启动速度优化](https://techblog.toutiao.com/2017/01/17/iosspeed/)
[dylib动态库加载过程分析](https://feicong.github.io/2017/01/14/dylib/index.html)
[Mach-O 文件格式探索](https://www.desgard.com/iosre-1/)