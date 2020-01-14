# iOS多线程使用方法记录
本文是多年使用多线程开发的心得，偏基础。

# pthread&NSThread
## pthread
pthread，即POSIX Thread，是一套可以跨平台通用的多线程API，基于C语言。
它可以在许多类似Unix且符合POSIX的操作系统上可用，例如FreeBSD，NetBSD，OpenBSD，Linux，iOS/macOS，Android。如果要实现一个跨平台的库，使用它实际上是个很不错的选择，不过单就iOS平台而言，并不推荐使用，而且我也确实没有使用过，就不做过多的介绍。在阅读源码发现使用pthread的时候，现查就可以了。

## NSThread

NSThread是苹果官方提供的一个操作线程的API，比pthread更加简单使用，可以**直接操作**线程对象，但是同样的也需要我们手动的管理线程的生命周期。
因为往往手动处理线程的生命周期往往会带来很多麻烦，所以苹果官方**强烈建议**我们不要手动的终止线程；即使非要用，也要在一开始就[设计好线程以响应取消或退出消息](https://github.com/BiBoyang/Study/blob/master/File/Thread_00.md#%E7%BB%88%E6%AD%A2%E7%BA%BF%E7%A8%8B)。
官方建议我们使用`initWithTarget:selector:object:`方法，然后手动启动。
```
NSThread* myThread = [[NSThread alloc] initWithTarget:self   
                                selector:@selector(myThreadMainMethod:)
                                        object:nil];
[myThread start];  // Actually create the thread
......
[myThread exit];  // Terminates the current thread.

```
我使用NSThread的地方也很少，一般仅限以下的几种方法：
> * 获取当前线程
        `NSThread *current = [NSThread currentThread];`
> * 是否是多线程
        `BOOL isMainThread = [NSThread isMultiThreaded];`

对，仅此而已了。
原本NSThread还有两处地方可以使用--线程保活和判断是否是主线程。
但是这个两个都存在一些问题，已经不建议使用。
在AFNetWorking的2.x版本里，有这样一段线程保活的代码。
```C++
        [[NSThread currentThread] setName:@"AFNetworking"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
```
但是这仅仅只是权宜之计，在后来的版本里已经替换为GCD的API了，这是为什么呢？
第一，NSThread本身已经很老的，很多设计已经过时，它会持续的占用新开辟线程的资源；第二，使用NSThread创建的长寿线程，并不能持续的满载的运行，这个实际上也是一种资源的莱菲，而GCD通过内核调度，动态的分配资源，相对的节约了资源。
在SDWebImage的老版本里，因为UI操作一定要在主线程上运行，所以会在很多地方判断当前手否是主线程。当时使用的是下面这个API。
```C++
#define dispatch_main_sync_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_sync(dispatch_get_main_queue(), block);\
    }
```
但是如果对SDWebImage源码比较熟悉的话，我们会知道在大约4.0之后的版本里，这个API被替换成了下面。
```C++
#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)\
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }
#endif
```
这个原因，可以查看这个[issue](https://github.com/lionheart/openradar-mirror/issues/7053),
