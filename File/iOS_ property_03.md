##### @property 原理（三）：内存管理相关（上）- iOS 中 copy 的原理


# strong/retain
retain 是在 MRC 时代使用的属性关键字，而 strong 是在 ARC 时代使用的属性关键字。

表示实例变量对传入的对象要有所有权关系，即强引用。它们会使对象的引用计数 +1，对于可变数据类型，需要使用它们。

# assign
assign 是用来修饰基本数据类型的属性修饰词。

它会直接执行 setter 方法，但是不会经过 retain/release 方法，所以，在某种意义上，和 weak 有些类似。

# copy 

在 objc-accessor.mm 中，有着 property 中 copy 的实现。

这里有两个函数 `objc_copyStruct` 和 `objc_copyCppObjectAtomic`,分别对应结构体的拷贝和对象的拷贝。具体代码如下：
```C++
/**
 * 结构体拷贝
 * src：源指针
 * dest：目标指针
 * size：大小
 * atomic：是否是原子操作
 * hasStrong：可能是表示是否是strong修饰
 */
void objc_copyStruct(void *dest, const void *src, ptrdiff_t size, BOOL atomic, BOOL hasStrong __unused) {
    spinlock_t *srcLock = nil;
    spinlock_t *dstLock = nil;
    // >> 如果是原子操作，则加锁
    if (atomic) {
        srcLock = &StructLocks[src];
        dstLock = &StructLocks[dest];
        spinlock_t::lockTwo(srcLock, dstLock);
    }
    // >> 实际的拷贝操作
    memmove(dest, src, size);

    // >> 解锁
    if (atomic) {
        spinlock_t::unlockTwo(srcLock, dstLock);
    }
}

/**
 * 对象拷贝
 * src：源指针
 * dest：目标指针
 * copyHelper：对对象进行实际拷贝的函数指针，参数是src和dest
*/

void objc_copyCppObjectAtomic(void *dest, const void *src, void (*copyHelper) (void *dest, const void *source)) {
    // >> 获取源指针的对象锁
    spinlock_t *srcLock = &CppObjectLocks[src];
    // >> 获取目标指针的对象锁
    spinlock_t *dstLock = &CppObjectLocks[dest];
    // >> 对源对象和目标对象进行上锁
    spinlock_t::lockTwo(srcLock, dstLock);

    // let C++ code perform the actual copy.
    // >> 调用函数指针对应的函数，让C++进行实际的拷贝操作
    copyHelper(dest, src);
    // >> 解锁
    spinlock_t::unlockTwo(srcLock, dstLock);
}
```

从上述代码中，我们可以得出结论：
1. 对结构体进行 copy，直接对结构体指针所指向的内存进行拷贝即可；
2. 对对象进行 copy，则会传入的源指针和目标对象同时进行加锁，然后在去进行拷贝操作，所以我们可以知道，为什么 copy 操作是线程安全的。

不过这里的 `copyHelper(dest, src); `找不到实现方法，则有些遗憾。

## 深浅拷贝

* 浅拷贝：只创建一个新的指针，指向原指针指向的内存；
* 深拷贝：创建一个新的指针，并开辟新的内存空间，内容拷贝自原指针指向的内存，并指向它。

我们分别使用 copy 和 strong，对 NSString 和 NSMutableString进行两两分配；以及对 NSArray 和 NSMutableArray 进行两两分配，可以得到一个结果。

测试的[源码在这里](https://github.com/BiBoyang/BoyangBlog/blob/master/CopyTest/CopyTest/ViewController.m)，可以查看测试的代码。

通过一系列测试，我得到了一个这样的结论。

非容器对象：

|  可不可变对象 |  copy类型 | 深浅拷贝 | 返回对象是否可变 |
|---|---|---|---|
|不可变对象| copy | 浅拷贝 | 不可变 |
|可变对象| copy | 深拷贝 | 不可变 |
|不可变对象| mutableCopy | 深拷贝 | 可变 |
|可变对象| mutableCopy | 深拷贝 | 可变 |

* 注意：接收 copy 结果的对象，也需要是可变的并且属性关键字是 strong，才可以进行修改，也就是可变，两个条件一个不符合则无法改变。

容器对象：

|  可不可变对象 |  copy类型 | 深浅拷贝 | 返回对象是否可变 |内部元素信息 |
|---|---|---|---|
|不可变对象| copy | 浅拷贝 | 不可变 | 内部元素是浅拷贝|
|可变对象| copy | 浅拷贝 | 不可变 |内部元素是浅拷贝|
|不可变对象| mutableCopy | 深拷贝 | 可变 |内部元素是浅拷贝|
|可变对象| mutableCopy | 深拷贝 | 可变 |内部元素是浅拷贝|


#### 参考源码

对于字符串，我们虽然因为 Foundation.framework 并未开源找不到源码，但是我们依旧可以去查阅开源的 CoreFoundation.framework 源码。因为 CoreFoundation 和 Foundation 的对象是 Toll-free bridge 的，所以，可以从CoreFoundation的源代码进行了解。









