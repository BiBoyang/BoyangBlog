##### @property 原理（二）：关键字探究 及 nonatomic & atomic
# 1. 关键字

默认状况下，OC 对象关键字是  **atomic**、**readwrite**、**strong**；而基本数据类型是： **atomic**、**readwrite**、**assign**。

用 @property 的时候会自动创建创建实例变量和 setter、getter 方法。

我们写一个属性:

```C++
@property (nonatomic, copy) NSString *Balaeniceps_rex;
```

然后利用 **class_copyPropertyList** 和 **class_copyMethodList**方法查看属性和方法

```C++
unsigned int propertyCount;
objc_property_t *propertyList = class_copyPropertyList([self class], &propertyCount);
for (unsigned int i = 0; i< propertyCount; i++) {
    const char *name = property_getName(propertyList[i]);
    NSLog(@"__%@",[NSString stringWithUTF8String:name]);            
    objc_property_t property = propertyList[i];
    const char *a = property_getAttributes(property);        
    NSLog(@"属性信息__%@",[NSString stringWithUTF8String:a]);
    }

u_int methodCount;
NSMutableArray *methodList = [NSMutableArray array];
Method *methods = class_copyMethodList([self class], &methodCount);
for (int i = 0; i < methodCount; i++) {
    SEL name = method_getName(methods[i]);
    NSString *strName = [NSString stringWithCString:sel_getName(name) encoding:NSUTF8StringEncoding];
    [methodList addObject:strName];
}
free(methods);
    
NSLog(@"方法列表:%@",methodList);
```

打印出来结果

```
属性信息__T@"NSString",C,N,V_Balaeniceps_rex
方法列表:(
    "Balaeniceps_rex",
    "setBalaeniceps_rex:",
    ".cxx_destruct",
    viewDidLoad
    )
```

然后通过[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html)，查阅到 T 表示类型，C 表示 copy，N 表示nonatomic，V 表示实例变量————这个实际上就是方法签名。


## .cxx_destruct

在上一节，我们会发现打印的时候多出来一个 **.cxx_destruct** ，可以查看sunnyxx的[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)来理解。
这个方法简单来讲作用如下：

* 1.只有在ARC下这个方法才会出现（试验代码的情况下）
* 2.只有当前类拥有实例变量时（不论是不是用property）这个方法才会出现，且父类的实例变量不会导致子类拥有这个方法
* 3.出现这个方法和变量是否被赋值，赋值成什么没有关系


# 2. atomic

atomic 一般会被翻译成原子性。它表示一个”不可再分割“的单元，也就是**单指令操作**。

话说回来，现在原子已经并非是不可分割的，但是提出这个概念的时候，并非如此，所以就直接简单的等价于**不可分割**，就可以了，和物理学没什么关系。所以在下面的内容里，不会直接使用原子性，而是直接用 atomic 来说明。

从某种意义上来讲，线程安全的元素是，它本身就是 atomic 的。

## iOS 中的 atomic
在我们日常的使用过程中，我们经常是使用 nonatomic 的，很少使用 atomic，这个主要是因为 atomic 本身就一些缺陷，但是并非不能使用，在某些情况下，使用 atomic 反而是某种较优解。

在上一篇文章中，我们知道在 set 后会调用 **reallySetProperty** 方法，get 后会调用 **objc_getProperty** 方法，我们找到它们的关键代码。慢慢看下去。

```C++
objc_getProperty
······
    // M:如果是非原子性操作，直接返回属性的对象指针
    if (!atomic) return *slot;
        
    // Atomic retain release world
    spinlock_t& slotlock = PropertyLocks[slot];
    slotlock.lock();
    id value = objc_retain(*slot);
    slotlock.unlock();
    return objc_autoreleaseReturnValue(value);
······
reallySetProperty
······
if (!atomic) {
        //M:非原子操作，将slot指针指向的对象引用赋值给oldValue
        oldValue = *slot;
        //M:slot指针指向newValue，完成赋值操作
        *slot = newValue;
    } else {
        //M:原子操作，则获取锁
        spinlock_t& slotlock = PropertyLocks[slot];
        slotlock.lock();//加锁
        oldValue = *slot;//将slot指针指向的对象引用赋值给oldValue
        *slot = newValue;//将slot指针指向newValue，完成赋值操作
        slotlock.unlock();//解锁
    }
```

这里，我们会发现，atomic 和 nonatomic 在实现上的区别，在于 set 和 get 操作的时候，是否添加了锁；以及在 get 过程中，atomic 修饰的属性，会将对象注册到自动释放池中，自动管理。

继续探究锁的实现。

**PropertyLocks** 是一个 **StripedMap<spinlock_t>** 类型的全局变量,而**StripedMap** 是一个 **hashMap**，key 是指针，value 是 spinlock_t 对象。

```C++
StripedMap<spinlock_t> PropertyLocks;
```
StripedMap 是一个 hashMap，如下所示：
```C++
enum { CacheLineSize = 64 };

// StripedMap<T> is a map of void* -> T, sized appropriately 
// for cache-friendly lock striping. 
// For example, this may be used as StripedMap<spinlock_t>
// or as StripedMap<SomeStruct> where SomeStruct stores a spin lock.
template<typename T>
class StripedMap {
#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    enum { StripeCount = 8 };
#else
    enum { StripeCount = 64 };
#endif

    struct PaddedT {
        //M:alignas是字节对齐的意思，表示让数组中每一个元素的起始位置对齐到64的倍数
        T value alignas(CacheLineSize);
    };

    PaddedT array[StripeCount];

    // hash 函数
    static unsigned int indexForPointer(const void *p) {
        uintptr_t addr = reinterpret_cast<uintptr_t>(p);
        return ((addr >> 4) ^ (addr >> 9)) % StripeCount;
    }

 public:
    T& operator[] (const void *p) { 
        return array[indexForPointer(p)].value; 
    }
    const T& operator[] (const void *p) const { 
        return const_cast<StripedMap<T>>(this)[p]; 
    }

    // Shortcuts for StripedMaps of locks.
    void lockAll() {
        for (unsigned int i = 0; i < StripeCount; i++) {
            array[i].value.lock();
        }
    }

    void unlockAll() {
        for (unsigned int i = 0; i < StripeCount; i++) {
            array[i].value.unlock();
        }
    }

    void forceResetAll() {
        for (unsigned int i = 0; i < StripeCount; i++) {
            array[i].value.forceReset();
        }
    }

    void defineLockOrder() {
        for (unsigned int i = 1; i < StripeCount; i++) {
            lockdebug_lock_precedes_lock(&array[i-1].value, &array[i].value);
        }
    }

    void precedeLock(const void *newlock) {
        // assumes defineLockOrder is also called
        lockdebug_lock_precedes_lock(&array[StripeCount-1].value, newlock);
    }

    void succeedLock(const void *oldlock) {
        // assumes defineLockOrder is also called
        lockdebug_lock_precedes_lock(oldlock, &array[0].value);
    }

    const void *getLock(int i) {
        if (i < StripeCount) return &array[i].value;
        else return nil;
    }
    
#if DEBUG
    StripedMap() {
        // Verify alignment expectations.
        uintptr_t base = (uintptr_t)&array[0].value;
        uintptr_t delta = (uintptr_t)&array[1].value - base;
        assert(delta % CacheLineSize == 0);
        assert(base % CacheLineSize == 0);
    }
#else
    constexpr StripedMap() {}
#endif
};
```
StripedMap<T> 是一个模板类，根据传递的实际参数决定其中 array 成员存储的元素类型。 能通过对象的地址，运算出 Hash 值，通过该 hash 值找到对应的 value 。

这里的 CacheLineSize 显然代表的时候用于缓存的 value 大小，使用 alignas 让字节对齐；而 StripeCount 则表示在 iPhone 中，创建的 array 大小是 8 。




