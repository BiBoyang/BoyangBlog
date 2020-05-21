> [实现代码](https://github.com/BiBoyang/BBY_TESTDEMO/blob/master/%E9%9D%A2%E8%AF%95%E9%A2%98(%E4%B8%80)/ViewController.m)

```C++
@property (nonatomic, strong) NSString *target;
//....

dispatch_queue_t queue = dispatch_queue_create("parallel", DISPATCH_QUEUE_CONCURRENT);
for (int i = 0; i < 1000000 ; i++) {
    dispatch_async(queue, ^{
        self.target = [NSString stringWithFormat:@"ksddkjalkjd%d",i];
    });
}
```

这是一个**EXC_BAD_ACCESS**的bug。

* 在OC中，操作各种对象基本上就是在操作各种指针。指针，存储了内存地址。当向着一个对象发送消息的时候，就会调用响应的指针，获取内存地址。
* 当这个内存地址无法访问的时候，内核会抛出异常（EXC），告诉你应用程序不能访问存储器区域（BAD_ACCESS）。
* 这里的原因可能是因为内存地址出错，但是只有访问到出错内存地址的时候才会报错；也有可能是因为指针出错，但是同样是使用出错指针的时候才会报错；
 
 这里使用僵尸对象来查看， 接着会打印如下：
 ```C++
2018-10-10 17:06:31.321649+0800 TaggedPointer[29305:49278901] *** -[CFString release]: message sent to deallocated instance 0x60000041d100
2018-10-10 17:06:31.322036+0800 TaggedPointer[29305:49278907] *** -[CFString release]: message sent to deallocated instance 0x60000045ab20
 ```

 这里我们可以看出来，是 self.target 被 release 的时候出的错。
 我们知道，ARC 自动实现了对象的 retain 和 release 方法。如果将它们复原出来，是这样的
 ```C++
 - (void)setTarget:(NSString *)target {
    ···
    [target retain];//1.先保留新值
    _target = target;//2.再进行赋值
    [pre release];//3.释放旧值
    ···
}

 ```

这里我们就想到思路了，考虑到 DISPATCH_QUEUE_CONCURRENT 方法是个 **并发队列**。

并发队列里调度的线程 A 执行到 retain，线程 B 执行到 release，那么当线程 A 再执行 release 时，旧值就会被过度释放，导致向已释放内存对象发送消息而崩溃。
 
# 那么该怎么解决呢
## 方法一
改成串行队列
```C++
dispatch_queue_t queue = dispatch_queue_create("parallel",DISPATCH_QUEUE_SERIAL);
```

## 方法二
```C++
@property (nonatomic, weak) NSString *target;
```
weak 的 setter 没有保留新值或者保留旧值的操作，所以不会引发重复释放。当然这个时候要看具体情况能否使用 weak，可能值并不是所需要的值。

## 方法三
使用 Tagged Pointer 方法。
```
self.target = [NSString stringWithFormat:@"aa%d",i];
```


## 方法四
```C++
@property (atomic, strong) NSString *target;
```
atomic 关键字相当于在 setter 方法加锁，这样每次执行 setter 都是线程安全的，但这只是单独针对 setter 方法而言的狭义的线程安全，或者说是读写安全。

这里我们可以查看 MrPeak 的文章[iOS 多线程到底不安全在哪里？](https://zhuanlan.zhihu.com/p/23998703)
> 简而言之，atomic 的作用只是给 getter 和 setter 加了个锁，atomic 只能保证代码进入 getter 或者 setter 函数内部时是安全的，一旦出了 getter 和 setter，多线程安全只能靠程序员自己保障了。所以 atomic 属性和使用 property 的多线程安全并没什么直接的联系。另外，atomic 由于加锁也会带来一些性能损耗，所以我们在编写 iOS 代码的时候，一般声明 property 为 nonatomic，在需要做多线程安全的场景，自己去额外加锁做同步。

## 方法五：危险
```C++
@property (atomic, assign) NSString *target;
```
这里使用 assign，也不会产生 retain 和 release，所以也能成立。

代价是有可能发生野指针。