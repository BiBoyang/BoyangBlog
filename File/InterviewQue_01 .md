> 实现代码https://github.com/BiBoyang/BBY_TESTDEMO/blob/master/%E9%9D%A2%E8%AF%95%E9%A2%98(%E4%B8%80)/ViewController.m

```
@property (nonatomic, strong) NSString *target;
//....

dispatch_queue_t queue = dispatch_queue_create("parallel", DISPATCH_QUEUE_CONCURRENT);
for (int i = 0; i < 1000000 ; i++) {
    dispatch_async(queue, ^{
        self.target = [NSString stringWithFormat:@"ksddkjalkjd%d",i];
    });
}
```
这里的崩溃是这样表示
![](https://ws2.sinaimg.cn/large/006tNbRwgy1fw38hofyd5j30ke06gabn.jpg)
可以发现，这里是一个**EXC_BAD_ACCESS**的bug。

> 在OC中，操作各种对象基本上就是在操作各种指针。指针，存储了内存地址。当向着一个对象发送消息的时候，就会调用响应的指针，获取内存地址。
 当这个内存地址无法访问的时候，内核会抛出异常（EXC），告诉你应用程序不能访问存储器区域（BAD_ACCESS）。
 这里的原因可能是因为内存地址出错，但是只有访问到出错内存地址的时候才会报错；也有可能是因为指针出错，但是同样是使用出错指针的时候才会报错；
 
 这里使用僵尸对象来解决
 ![](https://ws4.sinaimg.cn/large/006tNbRwgy1fw39ngs6ckj30p10dyjw8.jpg)
 接着会打印如下的代码
 ```
2018-10-10 17:06:31.321649+0800 TaggedPointer[29305:49278901] *** -[CFString release]: message sent to deallocated instance 0x60000041d100
2018-10-10 17:06:31.322036+0800 TaggedPointer[29305:49278907] *** -[CFString release]: message sent to deallocated instance 0x60000045ab20
 ```
 这里我们可以看出来，是self.target被release的时候出的错。
 我们知道，ARC自动实现了对象的retain和release方法。如果将它们复原出来，是这样的
 ```
 - (void)setTarget:(NSString *)target {
    ···
    [target retain];//1.先保留新值
    _target = target;//2.再进行赋值
    [pre release];//3.释放旧值
    ···
}

 ```
 这里我们就可以明白了，要考虑到DISPATCH_QUEUE_CONCURRENT方法，这是个 **并发队列**。
 并发队列里调度的线程A执行到retain，线程B执行到release，那么当线程A再执行release时，旧值就会被过度释放，导致向已释放内存对象发送消息而崩溃。
 
## 那么该怎么解决呢
#### 方法一
改成串行队列
```
    dispatch_queue_t queue = dispatch_queue_create("parallel", DISPATCH_QUEUE_SERIAL);
```

#### 方法二
```
@property (nonatomic, weak) NSString *target;
```
weak的setter没有保留新值或者保留旧值的操作，所以不会引发重复释放。当然这个时候要看具体情况能否使用weak，可能值并不是所需要的值。

#### 方法三
使用Tagged Pointer方法。
```
self.target = [NSString stringWithFormat:@"aa%d",i];
```
[原理解释](https://github.com/BiBoyang/Study/wiki/iOS%E4%B8%AD%E7%B1%BB%E7%B0%87%E7%9A%84%E4%BD%BF%E7%94%A8#nstaggedpointerstring)
#### 方法四
```
@property (atomic, strong) NSString *target;
```
atomic关键字相当于在setter方法加锁，这样每次执行setter都是线程安全的，但这只是单独针对setter方法而言的狭义的线程安全。
(此方法严重不推荐，实际上在实际开发中，atomic也不能绝对的说线程安全，而且在iOS开发中基本上不会使用atomic)。
这里我们可以查看MrPeak的文章[iOS多线程到底不安全在哪里？](https://www.jianshu.com/p/fd81fec31fe7)
> 简而言之，atomic的作用只是给getter和setter加了个锁，atomic只能保证代码进入getter或者setter函数内部时是安全的，一旦出了getter和setter，多线程安全只能靠程序员自己保障了。所以atomic属性和使用property的多线程安全并没什么直接的联系。另外，atomic由于加锁也会带来一些性能损耗，所以我们在编写iOS代码的时候，一般声明property为nonatomic，在需要做多线程安全的场景，自己去额外加锁做同步。
