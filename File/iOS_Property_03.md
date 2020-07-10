##### @property 原理（三）：内存管理相关（上）- iOS 中 copy 的原理


<!--# strong/retain
retain 是在 MRC 时代使用的属性关键字，而 strong 是在 ARC 时代使用的属性关键字。

表示实例变量对传入的对象要有所有权关系，即强引用。它们会使对象的引用计数 +1，对于可变数据类型，需要使用它们。

# assign
assign 是用来修饰基本数据类型的属性修饰词。

它会直接执行 setter 方法，但是不会经过 retain/release 方法，所以，在某种意义上，和 weak 有些类似。-->

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

![](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Collections/Art/CopyingCollections_2x.png)


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

* 这里的源字符串如果是 Tagged Pointer 类型，即 NSTaggedPointerString，会有些有趣的情况，不过并不影响结果。可以在文章末尾查看。

* 注意：接收 copy 结果的对象，也需要是可变的并且属性关键字是 strong，才可以进行修改，也就是可变，两个条件一个不符合则无法改变。

容器对象：

|  可不可变对象 |  copy类型 | 深浅拷贝 | 返回对象是否可变 |内部元素信息 | |
|---|---|---|---|---|---|
|不可变对象| copy | 浅拷贝 | 不可变 | 内部元素是浅拷贝|集合地址不变|
|可变对象| copy | 浅拷贝 | 不可变 | 内部元素是浅拷贝|集合地址改变|
|不可变对象| mutableCopy | 浅拷贝 | 可变 |内部元素是浅拷贝|集合地址改变|
|可变对象| mutableCopy | 浅拷贝 | 可变 |内部元素是浅拷贝|集合地址改变|

* 除了不可变对象使用 copy，其他的 copy 和 mutableCopy，都是开辟了一个新的集合空间，但是内部的元素的指针还是指向源地址；
* 有的人将集合地址改变的拷贝称之为深拷贝，但是这个其实是非常错误的理解，深拷贝就是全层次的拷贝。



## 参考源码

上面的测试更多的是我们自己去一个一个的测试，更底层的实现原理，还是要看源码。

对于字符串，我们虽然因为 Foundation.framework 并未开源找不到源码，但是我们依旧可以去查阅开源的 CoreFoundation.framework 源码。因为 CoreFoundation 和 Foundation 的对象是 Toll-free bridge 的，所以，可以从CoreFoundation的源代码进行了解。

我们进入到这里查阅相关代码 [CFString.h](https://opensource.apple.com/source/CF/CF-1151.16/CFString.c.auto.html)，里面给出了 CFStringCreateCopy 和 CFStringCreateMutableCopy 这两个方法，分别对应 copy 和 mutableCopy；以及 [CFArray.c](https://opensource.apple.com/source/CF/CF-1151.16/CFArray.c.auto.html)，里面给出了 CFArrayCreateCopy 和 CFArrayCreateMutableCopy 两个方法，分别对应 copy 和 mutableCopy。

#### CFStringCreateCopy

```C++
/**
 * >> 字符串的 copy 操作
 */
CFStringRef CFStringCreateCopy(CFAllocatorRef alloc, CFStringRef str) {
//  CF_OBJC_FUNCDISPATCHV(__kCFStringTypeID, CFStringRef, (NSString *)str, copy);

    /*
     * 如果该字符串不是可变的，并且与我们使用的分配器具有相同的分配器，
     并且这些字符是内联的，或者由该字符串拥有，或者该字符串是常量。
     然后保留而不是制作真实副本。
     */
    __CFAssertIsString(str);
    // >> 判断源字符串是否是 mutable
    if (!__CFStrIsMutable((CFStringRef)str) && 								// If the string is not mutable
        ((alloc ? alloc : __CFGetDefaultAllocator()) == __CFGetAllocator(str)) &&		//  and it has the same allocator as the one we're using
        (__CFStrIsInline((CFStringRef)str) || __CFStrFreeContentsWhenDone((CFStringRef)str) || __CFStrIsConstant((CFStringRef)str))) {	//  and the characters are inline, or are owned by the string, or the string is constant
        // >> 使用引用计数加一来代替真正的copy,也就是这里是浅拷贝。
        if (!(kCFUseCollectableAllocator && (0))) CFRetain(str);			// Then just retain instead of making a true copy
	return str;
    }
    
    
    if (__CFStrIsEightBit((CFStringRef)str)) {
        const uint8_t *contents = (const uint8_t *)__CFStrContents((CFStringRef)str);
        return __CFStringCreateImmutableFunnel3(alloc, contents + __CFStrSkipAnyLengthByte((CFStringRef)str), __CFStrLength2((CFStringRef)str, contents), __CFStringGetEightBitStringEncoding(), false, false, false, false, false, ALLOCATORSFREEFUNC, 0);
    } else {
        const UniChar *contents = (const UniChar *)__CFStrContents((CFStringRef)str);
        return __CFStringCreateImmutableFunnel3(alloc, contents, __CFStrLength2((CFStringRef)str, contents) * sizeof(UniChar), kCFStringEncodingUnicode, false, true, false, false, false, ALLOCATORSFREEFUNC, 0);
    }
}
```
从上面代码我们可以得到几条信息：
1. CFStringCreateCopy 函数，返回的字符串是否返回新的对象，要看源字符串是 immutable 还是 mutable 的；
2. 如果源字符串是 mutable 的，会开辟一片新的内存，生成一个新的 immutable 对象返回，创建使用 __CFStringCreateImmutableFunnel3 方法，这个是**深拷贝**；
3. 如果源字符串是 immutable 的，且是内联的、string 所持有或者是常量，那么只对源 CFStringRef 对象引用计数加一，这个是**浅拷贝**。



#### CFStringCreateMutableCopy
```C++
/*
 * >>>> 字符串的 copy 操作
 */
CFMutableStringRef  CFStringCreateMutableCopy(CFAllocatorRef alloc, CFIndex maxLength, CFStringRef string) {
    CFMutableStringRef newString;

    //  CF_OBJC_FUNCDISPATCHV(__kCFStringTypeID, CFMutableStringRef, (NSString *)string, mutableCopy);

    __CFAssertIsString(string);

    newString = CFStringCreateMutable(alloc, maxLength);
    // 将源对象的内容，放到新创建的newString中
    __CFStringReplace(newString, CFRangeMake(0, 0), string);

    return newString;
}
```
在这里，我们可以知道，在 CFStringCreateMutableCopy 函数里，我们不再需要判断源对象是否是 mutable，直接创建一个新的对象，然后将源内容拷贝一份放到新的对象里，这里也就是深拷贝。



#### CFArrayCreateCopy
```C++
CFArrayRef CFArrayCreateCopy(CFAllocatorRef allocator, CFArrayRef array) {
    return __CFArrayCreateCopy0(allocator, array);
}

CF_PRIVATE CFArrayRef __CFArrayCreateCopy0(CFAllocatorRef allocator, CFArrayRef array) {
    
    CFArrayRef result;
    // >>>> CFArrayCallBacks变量，用于存放数组元素的回调
    const CFArrayCallBacks *cb;
    
    // >>>> 存放数组元素的结构体指针
    struct __CFArrayBucket *buckets;
    CFAllocatorRef bucketsAllocator;
    void* bucketsBase;
    
    // >>>> 获取源数组元素的总个数
    CFIndex numValues = CFArrayGetCount(array);
    CFIndex idx;
    if (CF_IS_OBJC(CFArrayGetTypeID(), array)) {
	cb = &kCFTypeArrayCallBacks;
    } else {
	cb = __CFArrayGetCallBacks(array);
	    }
    
    // >>>> 初始化以一个不可变数组
    result = __CFArrayInit(allocator, __kCFArrayImmutable, numValues, cb);
    cb = __CFArrayGetCallBacks(result); // GC: use the new array's callbacks so we don't leak.
    buckets = __CFArrayGetBucketsPtr(result);
    bucketsAllocator = isStrongMemory(result) ? allocator : kCFAllocatorNull;
	bucketsBase = CF_IS_COLLECTABLE_ALLOCATOR(bucketsAllocator) ? (void *)auto_zone_base_pointer(objc_collectableZone(), buckets) : NULL;
    for (idx = 0; idx < numValues; idx++) {
	const void *value = CFArrayGetValueAtIndex(array, idx);
	if (NULL != cb->retain) {
	    value = (void *)INVOKE_CALLBACK2(cb->retain, allocator, value);
	}
	__CFAssignWithWriteBarrier((void **)&buckets->_item, (void *)value);
	buckets++;
    }
    
    // >>>> //设定数组的长度count
    __CFArraySetCount(result, numValues);
    return result;
}
```


#### CFArrayCreateMutableCopy
```C++
CFMutableArrayRef CFArrayCreateMutableCopy(CFAllocatorRef allocator, CFIndex capacity, CFArrayRef array) {
    return __CFArrayCreateMutableCopy0(allocator, capacity, array);
}

CF_PRIVATE CFMutableArrayRef __CFArrayCreateMutableCopy0(CFAllocatorRef allocator, CFIndex capacity, CFArrayRef array) {
    CFMutableArrayRef result;
    const CFArrayCallBacks *cb;
    CFIndex idx, numValues = CFArrayGetCount(array);
    UInt32 flags;
    if (CF_IS_OBJC(CFArrayGetTypeID(), array)) {
	cb = &kCFTypeArrayCallBacks;
    }
    else {
	cb = __CFArrayGetCallBacks(array);
    }
    // 将标记设置为双端队列
    flags = __kCFArrayDeque;
    // 创建新的不可变数组
    result = (CFMutableArrayRef)__CFArrayInit(allocator, flags, capacity, cb);
    // 设置数组的容量
    if (0 == capacity) _CFArraySetCapacity(result, numValues);
    
    for (idx = 0; idx < numValues; idx++) {
        const void *value = CFArrayGetValueAtIndex(array, idx);
        // 将元素对象添加到新的数组列表中
        CFArrayAppendValue(result, value);
    }
    return result;
}
```

从上面两份代码，我们可以可以：
1. immutable 和 mutable 数组的拷贝，都是会调用 __CFArrayInit 函数去创建一个新的对象；
2. 内部元素实际上都是指向源数组；
3. 不可变数组的 copy 没有体现在代码中，个人猜测可能是实现过于简单，所以也就没有在这里实现。

其他的容器，类似 CFDictionary、CFSet 等，也是类似的结果。


## 真正的深拷贝

那么该如何实现真正的深拷贝呢？有两个办法。

一. 使用对象的序列化拷贝：

```C++
//数组内对象是指针复制
NSArray *deepCopyArray = [[NSArray alloc] initWithArray:array];
//真正意义上的深复制，数组内对象是对象复制
NSArray *trueDeepCopyArray = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:array]];
```
二. 自己实现 copy 协议 

也就是 **NSCopying,NSMutableCopying**，












# 参考

[代码查阅地址](https://opensource.apple.com/source/CF/CF-1151.16/)

[代码下载地址](https://opensource.apple.com/tarballs/CF/)

[Collections Programming Topics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Collections/Articles/Copying.html#//apple_ref/doc/uid/TP40010162-SW3)

[Wiki:Deep_copy](https://en.wikipedia.org/wiki/Object_copying#Deep_copy)

[What is the difference between a deep copy and a shallow copy?](https://stackoverflow.com/questions/184710/what-is-the-difference-between-a-deep-copy-and-a-shallow-copy)

## 特殊情况
在测试的时候，发现如果这个字符串是 isTaggedPointerString ，则有个特殊情况，不过貌似也没什么用处。

|  可不可变对象 |  copy类型 | 深浅拷贝 | 接收对象关键字| 返回对象是否可变 |
|---|---|---|---|---|
|不可变对象| copy | 浅拷贝 | |不可变 |
|可变对象| copy | 深拷贝 | |不可变 |
|不可变对象| mutableCopy | 深拷贝 | strong| 可变 |
|不可变对象| mutableCopy | 浅拷贝 | copy | 不可变 |
|可变对象| mutableCopy | 深拷贝 | strong | 可变 |
|可变对象| mutableCopy | 深拷贝 | copy | 不可变 |









