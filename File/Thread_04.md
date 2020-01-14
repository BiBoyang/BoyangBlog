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
这个原因，可以查看这个[issue](https://github.com/lionheart/openradar-mirror/issues/7053)。简单而言，就是因为在`MapKit`中有一个坑，导致有问题了，所以现在基本上都弃用原有的方法。

# GCD
GCD就不必过多介绍了，我们一般使用的最多的异步API。不必手动管理创建的线程，只需要讲想要异步使用的代码放到适当的Dispatch Queue当中，GCD就会生成必要的线程来执行任务。
GCD实际上是由内核来直接调度资源分配，所以会比上面的更加有效率和节约。
下面简单描述一下用的比较多的功能。

## 多线程应用
在其他线程运行程序有两种方法。
第一种。
```C++
    dispatch_queue_t queue = dispatch_queue_create("testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        sleep(1);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"mainQueue");
        });
    });
    
``` 
第二种方法。
```C++
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(5);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"mainQueue");
        });
    });
```

## 延后执行
```C++
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5* NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"wait 5 sec");
    });
```
这里有些地方需要注意。
dispatch_after方法实际上并不是在指定时间后执行处理，而是在指定的时间处加入到DispatchQueue中。
因为主队列在主线程中RunLoop中执行，RunLoop有时间间隔的，block中的方法最快是在5后执行，最慢则是在 5+1/60 秒后执行。


## 队列
假如有多个任务要一起处理，就可以使用这个方法。
```C++
+ (void)dispatchGroup {
    dispatch_queue_t queue = dispatch_queue_create("queue_test", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, queue, ^{
        NSLog(@"任务1");
        sleep(3);
        NSLog(@"任务2");
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务完成");
        NSLog(@"%d",[NSThread isMainThread]);
    });
}
```

## 快速遍历
dispatch_appy是GCD提供的一个快速遍历的方法。但是要注意，这个遍历的方法是无序的，并且最好自己去新建一个异步任务。
```C++
    dispatch_queue_t queue = dispatch_queue_create("myqueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_apply(1000, queue, ^(size_t index) {
        NSLog(@"apply is %zu",index);
    });
```
dispatch_apply的优点在于，它比forin遍历还要快速！！！
如果看过我之前的[文章]的话，应该知道forin遍历在大多数遍历里算得上最快的了，而dispatch_apply比forin遍历还要快速。在某些数量很大并且不需要顺序的遍历操作中可以使用。

## Semaphore
这个实际上是一个信号量。我们可以把它理解为一种锁。
Semaphore是一个有计数的信号。计数为0的时候回阻塞线程，大于0则不会，所以我们可以通过控制semaphore的值，来达成线程同步。

这里主要是三个函数起作用。
> * `dispatch_semaphore_create`创建一个semaphore信号量;
> * `dispatch_semaphore_signal` 发送一个信号让信号量+1;
> * `dispatch_semaphore_wait` 如果信号量计数为0则阻塞等待、否则通过。

```C++
        dispatch_group_t group = dispatch_group_create();
    // 创建信号量，并且设置值为10
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(10);
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        for (int i = 0; i < 100; i++){
            //信号-1
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            dispatch_group_async(group, queue, ^{
                NSLog(@"%i",i);
                sleep(2);
                //信号+1，
                dispatch_semaphore_signal(semaphore);
            });
        }
```
dispatch_semaphore有个优点是性能比较好，如果看过SDWebImage的源码的话，会发现它的很多锁是从@synchronized慢慢的替换为dispatch_semaphore。

## 单例
这个可能是我们使用的最多的地方了。
比较安全的单例写法是这样的。
```C++
#ifdef __has_feature(objc_arc) 

#define singleton_h +(instancetype)sharedInstance;

#define singleton_m static id _instanceType = nil;\
+(instancetype)sharedInstance\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
        _instanceType = [[self alloc]init];\
    });\
    return _instanceType;\
}\
+ (instancetype)allocWithZone:(struct _NSZone *)zone\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
        _instanceType = [super allocWithZone:zone];\
    });\
    return _instanceType;\
}\
-(id)copyWithZone:(NSZone *)zone\
{\
    return _instanceType;\
}

#else 

#define singleton_h +(instancetype)sharedInstance;

#define singleton_m static id _instanceType = nil;\
+(instancetype)sharedInstance\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
        _instanceType = [[self alloc]init];\
    });\
    return _instanceType;\
}\
+ (instancetype)allocWithZone:(struct _NSZone *)zone\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
        _instanceType = [super allocWithZone:zone];\
    });\
    return _instanceType;\
}\
-(id)copyWithZone:(NSZone *)zone\
{\
    return _instanceType;\
}\
-(oneway void)release\
{\
\
}\
-(instancetype)retain\
{\
    return _instanceType;\
}\
-(instancetype)autorelease\
{\
    return _instanceType;\
}\
- (NSUInteger)retainCount\
{\
    return 1;\
}

#endif
```

## 定时器
直接去[看这里](https://github.com/BiBoyang/Study/blob/master/File/003.md#gcd)

```C++
@interface ViewController ()

@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 创建
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    // 开始时刻
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (ino64_t)(1.0 * NSEC_PER_SEC));
    uint64_t interval = (uint64_t)(2.0 * NSEC_PER_SEC);
    dispatch_source_set_timer(self.timer, start, interval, 0);
    dispatch_source_set_event_handler(self.timer, ^{

        NSLog(@"time");

    });

    // 启动
    dispatch_resume(self.timer);

}

//暂停
-(void) pauseTimer{  
    if(_timer){  
        dispatch_suspend(_timer);  
    }  
}  
//恢复
-(void) resumeTimer{  
    if(_timer){  
        dispatch_resume(_timer);  
    }  
}  
//销毁
-(void) stopTimer{  
    if(_timer){  
        dispatch_source_cancel(_timer);  
        _timer = nil;  
    }  
}  

@end
```

# NSOperation
>  比较惭愧的说，我其实使用NSOperation的并不多。

NSOperation是对GCD的封装，更加的面相对象。

它主要有三种对象。
> * NSInvocationOperation
> * NSBlockOperation
> * 自定义NSOperation

## NSInvocationOperation
```C++
+ (void)InvocationOperation {
    
    // 1.创建 NSInvocationOperation 对象
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];

    // 2.调用 start 方法开始执行操作
    [op start];
}


- (void)task1 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
    }
}
```
我们可以发现，队列实际上还是在主线程中。
## NSBlockOperation
```C++
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op start];
```
我们可以发现，队列实际上还是在主线程中。

## 自定义NSOperation
通过重写NSOperation的方法来处理，代码略过。

## addOperationWithBlock
我们使用这个方法来添加异步任务。
```C++
- (void)addOperationWithBlockToQueue {
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    // 2.使用 addOperationWithBlock: 添加操作到队列中
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
}
```
我们可以发现，使用 addOperationWithBlock: 将操作加入到操作队列后能够开启新线程，进行并发执行。

## 操作依赖
我在少数使用NSOperation的地方就是这里了。
有时候我们会遇到a任务、b任务要先后执行，然后在执行完毕之后才能继续执行c操作。这个时候NSOperation就有用了。
示例代码如下：
```C++
+ (void)addDependency {
    //创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //创建操作
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    //添加依赖
    [op2 addDependency:op1]; 
    //添加操作到队列中
    [queue addOperation:op1];
    [queue addOperation:op2];
}
```