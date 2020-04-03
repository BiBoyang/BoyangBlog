
![](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_3.png)

> 在不特殊说明是MRC的情况下，默认是ARC。
[Objective-C Automatic Reference Counting (ARC)](http://clang.llvm.org/docs/AutomaticReferenceCounting.html)

# 怎么泄漏的
我们知道，在ARC中，除了全局block，block都是在栈上进行创建的。使用的时候，会自动将它复制到堆中。中间会经历`objc_retainBlock` -> `_Block_copy` -> `_Block_copy_internal`方法链。换过来说，我们使用的每个拦截了自动变量的block，都会经历这写方法（注意这一点很重要）。

通过之前的研究，了解到在 **__main_block_impl_0**中会保存着引用到的变量。在转换过的block代码中，block会强行持有拦截的外部对象，不管有没有改变过，都是会造成强引用。

# __string和__weak
## __strong
__strong实际上是一个默认的方法。
```C++
{
    id __strong obj = [[NSObject alloc] init];
}
```
代码会被转换成这个样子
```C++
id __attribute__((objc_ownership(strong))) obj = 
((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), 
sel_registerName("alloc")), 
sel_registerName("init"));
//代码实际上只有一行，为了方便观看打了换行
```
抽离出来，实际上主要是这三个方法
```C++
id obj = objc_msgSend(NSObject, @selector(alloc));
objc_msgSend(obj,selector(init));
objc_release(obj);
```
也就是说，ARC下的对象，正常情况下都是__strong修饰的。

## __weak

> 这里我们要使用 **clang -rewrite-objc -fobjc-arc -stdlib=libc++ -mmacosx-version-min=10.7 -fobjc-runtime=macosx-10.7 -Wno-deprecated-declarations main.m**方法去转换为C++代码，原因是因为，__weak其实只在ARC的状态下才能使用，之前使用 **clang -rewrite-objc main.m**是直接将代码转换为C++，并不有限制。

声明一个__weak对象
```C++
{
    id __weak obj = strongObj;
}
```
转换之后
```C++
id __attribute__((objc_ownership(none))) obj1 = strongObj;
```
相应的会调用
```C++
id obj ;
objc_initWeak(&obj,strongObj);
objc_destoryWeak(&obj);
```
从名字上可以看出来，一个是创建一个是销毁。

这里LLVM文档和objc_723文档有些许不同。我这里采用最新的objc_723代码，比之前的有优化：
```C++
id objc_initWeak(id *location, id newObj)
{
    // 查看对象实例是否有效
    // 无效对象直接导致指针释放
    if (!newObj)
    {
        *location = nil;
        return nil;
    }
    
    // 这里传递了三个 bool 数值
    // 使用 template 进行常量参数传递是为了优化性能
    // DontHaveOld--没有旧对象，
    // DoHaveNew--有新对象，
    // DoCrashIfDeallocating-- 如果newObj已经被释放了就Crash提示
    return storeWeak<DontHaveOld, DoHaveNew, DoCrashIfDeallocating>
        (location, (objc_object*)newObj);
}
~~~~~~~~~~~~~~~~
void objc_destroyWeak(id *location)
{
    (void)storeWeak<DoHaveOld, DontHaveNew, DontCrashIfDeallocating>
        (location, nil);
}
```
这两个方法，最后都指向了 **storeWeak**方法，这是一个很长的方法:

```C++
// Update a weak variable.
// If HaveOld is true, the variable has an existing value 
//   that needs to be cleaned up. This value might be nil.
// If HaveNew is true, there is a new value that needs to be 
//   assigned into the variable. This value might be nil.
// If CrashIfDeallocating is true, the process is halted if newObj is 
//   deallocating or newObj's class does not support weak references. 
//   If CrashIfDeallocating is false, nil is stored instead.
// 更新weak变量.
// 当设置HaveOld是true，即DoHaveOld，表示这个weak变量已经有值，需要被清理，这个值也有能是nil
// 当设置HaveNew是true， 即DoHaveNew，表示有一个新值被赋值给weak变量，这个值也有能是nil
//当设置参数CrashIfDeallocating是true，即DoCrashIfDeallocating，如果newObj已经被释放或者newObj是一个不支持弱引用的类，则暂停进程
// deallocating或newObj的类不支持弱引用
// 当设置参数CrashIfDeallocating是false，即DontCrashIfDeallocating，则存储nil

enum CrashIfDeallocating {
    DontCrashIfDeallocating = false, DoCrashIfDeallocating = true
};
template <HaveOld haveOld, HaveNew haveNew,
          CrashIfDeallocating crashIfDeallocating>
static id storeWeak(id *location, objc_object *newObj)
{
    assert(haveOld  ||  haveNew);
    
    // 初始化当前正在 +initialize 的类对象为nil
    if (!haveNew) assert(newObj == nil);

    Class previouslyInitializedClass = nil;
    id oldObj;
    
    // 声明新旧SideTable，
    SideTable *oldTable;
    SideTable *newTable;

    // 获得新值和旧值的锁存位置（用地址作为唯一标示）
    // 通过地址来建立索引标志，防止桶重复
    // 下面指向的操作会改变旧值
 retry:
    
    // 如果weak ptr之前弱引用过一个obj，则将这个obj所对应的SideTable取出，赋值给oldTable
    if (haveOld)
    {
        oldObj = *location;
        oldTable = &SideTables()[oldObj];
    }
    else
    {
        oldTable = nil;
    }
    
    
    if (haveNew) {
        newTable = &SideTables()[newObj];
    } else {
        newTable = nil;
    }

    
    SideTable::lockTwo<haveOld, haveNew>(oldTable, newTable);

    if (haveOld  &&  *location != oldObj) {
        SideTable::unlockTwo<haveOld, haveNew>(oldTable, newTable);
        goto retry;
    }

    // Prevent a deadlock between the weak reference machinery
    // and the +initialize machinery by ensuring that no 
    // weakly-referenced object has an un-+initialized isa.
    //通过确保没有弱引用的对象具有未初始化的 isa，防止弱引用机制和 +initialize 机制之间的死锁。
    //在使用 **+initialized**方法的时候，因为这个方法是在alloc之前调用的。不这么做，可能会出现+initialize 中调用了 storeWeak 方法，而在 storeWeak 方法中 weak_register_no_lock 方法中用到对象的 isa 还没有初始化完成的情况。

    if (haveNew  &&  newObj) {
        // 获得新对象的 isa 指针
        Class cls = newObj->getIsa();
        // 判断 isa 非空且已经初始化
        if (cls != previouslyInitializedClass  &&  
            !((objc_class *)cls)->isInitialized()) 
        {
            // 解锁新旧SideTable
            SideTable::unlockTwo<haveOld, haveNew>(oldTable, newTable);
            _class_initialize(_class_getNonMetaClass(cls, (id)newObj));

            // If this class is finished with +initialize then we're good.
            // If this class is still running +initialize on this thread 
            // (i.e. +initialize called storeWeak on an instance of itself)
            // then we may proceed but it will appear initializing and 
            // not yet initialized to the check above.
            // Instead set previouslyInitializedClass to recognize it on retry.
            // 如果 newObj 已经完成执行完 +initialize 是最理想情况
            // 如果 newObj的 +initialize 仍然在线程中执行
            // (也就是说newObj的 +initialize 正在调用 storeWeak 方法)
            // 通过设置previousInitializedClass以在重试时识别它。
            

            previouslyInitializedClass = cls;

            goto retry;
        }
    }

    // Clean up old value, if any.
    // 清除旧值，实际上是清除旧对象weak_table中的location

    if (haveOld) {
        weak_unregister_no_lock(&oldTable->weak_table, oldObj, location);
    }

    // Assign new value, if any.
    // 分配新值，实际上是保存location到新对象的weak_table种

    if (haveNew) {
        newObj = (objc_object *)
            weak_register_no_lock(&newTable->weak_table, (id)newObj, location, 
                                  crashIfDeallocating);
        // weak_register_no_lock returns nil if weak store should be rejected

        // Set is-weakly-referenced bit in refcount table.
        // 如果弱引用被释放 weak_register_no_lock 方法返回 nil
        
        // 如果新对象存在，并且没有使用TaggedPointer技术，在引用计数表中设置若引用标记位
        if (newObj  &&  !newObj->isTaggedPointer()) {
            // 标记新对象有weak引用，isa.weakly_referenced = true;
            newObj->setWeaklyReferenced_nolock();
        }

        // Do not set *location anywhere else. That would introduce a race.
        // 设置location指针指向newObj
        // 不要在其他地方设置 *location。 那会引起竞争
        *location = (id)newObj;
    }
    else {
        // No new value. The storage is not changed.
    }
    
    SideTable::unlockTwo<haveOld, haveNew>(oldTable, newTable);

    return (id)newObj;
}
```
这里不再重复一遍weak的实现。

简单点说，由于weak也是用哈希表实现的，所以`objc_storeWeak`函数就把第一个入参的变量地址注册到weak表中，然后根据第二个入参来决定是否移除。如果第二个参数为0，那么就把**__weak**变量从`weak`表中删除记录，并从引用计数表中删除对应的键值记录。

所以如果**__weak**引用的原对象如果被释放了，那么对应的**__weak**对象就会被指为nil。原来就是通过`objc_storeWeak`函数这些函数来实现的。

## weakSelf和strongSelf

```C++
__weak __typeof(self)weakSelf = self;
__strong __typeof(weakSelf)strongSelf = weakSelf;      
```
weakSelf是为了让block不去持有self，避免了循环引用，如果在Block内需要访问使用self的方法、变量，建议使用weakSelf。

但是，这里会出现一个问题。使用weakSelf修饰的 **self.**变量，是有可能在执行的过程中就被释放的。

以下代码为例
```C++
- (void)blockRetainCycle_1 {
    __weak __typeof(self)weakSelf = self;
    self.block = ^{
        NSLog(@"%@",@[weakSelf]);
    };
}
```
我们如果直接使用这个函数，是有可能在打印之前，weakSelf就被释放了，打印出来就是会出问题。
为了解决这个问题，我们就要用到strongSelf。
```
- (void)blockRetainCycle_2 {
    __weak __typeof(self)weakSelf = self;
    self.block = ^{
        __strong typeof (weakSelf)strongSelf = weakSelf;
        NSLog(@"%@",@[strongSelf]);
    };
}
```
在这里，我们使用了strongSelf，它可以保证在strongSelf下面，直到出了作用域之前，都是存在这个strongSelf的。
但是，这里依然存在一个微小的问题：
我们知道使用weakSelf的时候是无法保证在作用域中一直持有的。虽然使用了strongSelf，但是还是会存在微小的概率，让weakSelf在strongSelf创建之前被释放。如果是单纯的给self对象发送信息的话，这么其实问题不大，*OC的消息转发机制保证了我们即使给nil的对象发送消息也不会出现问题*。
但是如果我们有其他的操作，比如说将self对象添加进数组中，如上面代码所示，这里就会发生crash了。

那么我们要需要进一步的保护
```
- (void)blockRetainCycle_3 {
    __weak __typeof(self)weakSelf = self;
    self.block = ^{
        __strong typeof (weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            NSLog(@"%@",@[strongSelf]);
        }
    };
}
```

#### __weak和__block的区别
我们使用__block其实也是可能达到防止block循环引用的。
我们可以通过在block内部把__block修饰的对象置为nil来变相地实现内存释放。
从内存上来讲，__block会持有该对象，即使超出了该对象的作用域，该对象还是会存在的，知道block对象从堆上销毁；而__weak是把该对象赋值给weak对象，如果对象被销毁，weak对象将变成nil。
另外，__block对象可以让block修改局部变量。



#### 关键字
我们通过之前的文章知道，在ARC当中，一般的block会从栈被copy到堆中。
但是如果使用weak呢？（assign就不讨论了）
系统会告知我们 **Assigning block literal to a weak property; object will be released after assignment**。
而在ARC下要使用什么关键字呢？
strong和copy都是可以的。
之前我们知道，在ARC中，block会自动从栈被复制到堆中，这个copy是自动了，即使使用strong还是依然会有copy操作。

# 总结

* 如果block内部使用到了某个变量，而且这个变量是局部变量，那么block会捕获这个变量并存储到block底层的结构体中。
* 如果捕获的这个变量是用__weak修饰的，那么block内部就是用弱指针指向这个变量(也就是block不持有这个对象)，否则block内部就是用强指针指向这个对象(也就是block持有这个对象)。
* self在某种意义上也是一个局部变量。
* 如果self并不持有这个block，block内部怎么引用self都不会造成循环引用。


下一篇文章[block(四)：修改block的实现](https://github.com/BiBoyang/BoyangBlog/blob/master/File/iOS_block_04.md)