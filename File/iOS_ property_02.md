# @property 原理（二）：关键字探究 及 nonatomic & atomic
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

### StripedMap

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
我们查看注释，
* StripedMap<T> is a map of void* -> T, sized appropriately for cache-friendly lock striping. 
* StripedMap<T> 是一个 key 是 void*，value 是 T 的表，对于缓存友好的锁分条大小适中。

StripedMap<T> 是一个模板类，根据传递的实际参数决定其中 array 成员存储的元素类型。 能通过对象的地址，运算出 Hash 值，通过该 hash 值找到对应的 value 。

这里的 CacheLineSize 显然代表的时候用于缓存的 value 大小，使用 alignas 让字节对齐；而 StripeCount 则表示在 iPhone 中，创建的 array 大小是 8 。

### spinlock_t

它被指定了别名
```C++
using spinlock_t = mutex_tt<LOCKDEBUG>;//M:指定别名
```
然后找到 mutex_tt
```C++
template <bool Debug>
class mutex_tt : nocopy_t {
    os_unfair_lock mLock;
 public:
    constexpr mutex_tt() : mLock(OS_UNFAIR_LOCK_INIT) {
        lockdebug_remember_mutex(this);
    }

    constexpr mutex_tt(const fork_unsafe_lock_t unsafe) : mLock(OS_UNFAIR_LOCK_INIT) { }

    void lock() {
        lockdebug_mutex_lock(this);

        os_unfair_lock_lock_with_options_inline
            (&mLock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    }

    void unlock() {
        lockdebug_mutex_unlock(this);

        os_unfair_lock_unlock_inline(&mLock);
    }

    void forceReset() {
        lockdebug_mutex_unlock(this);

        bzero(&mLock, sizeof(mLock));
        mLock = os_unfair_lock OS_UNFAIR_LOCK_INIT;
    }

    void assertLocked() {
        lockdebug_mutex_assert_locked(this);
    }

    void assertUnlocked() {
        lockdebug_mutex_assert_unlocked(this);
    }


    // Address-ordered lock discipline for a pair of locks.

    static void lockTwo(mutex_tt *lock1, mutex_tt *lock2) {
        if (lock1 < lock2) {
            lock1->lock();
            lock2->lock();
        } else {
            lock2->lock();
            if (lock2 != lock1) lock1->lock(); 
        }
    }

    static void unlockTwo(mutex_tt *lock1, mutex_tt *lock2) {
        lock1->unlock();
        if (lock2 != lock1) lock2->unlock();
    }

    // Scoped lock and unlock
    class locker : nocopy_t {
        mutex_tt& lock;
    public:
        locker(mutex_tt& newLock) 
            : lock(newLock) { lock.lock(); }
        ~locker() { lock.unlock(); }
    };

    // Either scoped lock and unlock, or NOP.
    class conditional_locker : nocopy_t {
        mutex_tt& lock;
        bool didLock;
    public:
        conditional_locker(mutex_tt& newLock, bool shouldLock)
            : lock(newLock), didLock(shouldLock)
        {
            if (shouldLock) lock.lock();
        }
        ~conditional_locker() { if (didLock) lock.unlock(); }
    };
};
```
这里就很有意思了！我之前一直看各种博文，一直认为 atomic 是自旋锁，但是点进去一看，居然是 mute 互斥锁了。它实际上使用的是一种叫做 os_unfair_lock 的底层锁。

我们一层一层的翻下去，直到 os/lock.h 文件，里面展示了 os_unfair_lock 的实现。关键的是有一段注释：

>  Low-level lock that allows waiters to block efficiently on contention.

> In general, higher level synchronization primitives such as those provided by the pthread or dispatch subsystems should be preferred.

> The values stored in the lock should be considered opaque and implementation defined, they contain thread ownership information that the system may use to attempt to resolve priority inversions.

> This lock must be unlocked from the same thread that locked it, attempts to unlock from a different thread will cause an assertion aborting the process.

> This lock must not be accessed from multiple processes or threads via shared or multiply-mapped memory, the lock implementation relies on the address of the lock value and owning process.

> Must be initialized with OS_UNFAIR_LOCK_INIT
 
> @discussion

> Replacement for the deprecated OSSpinLock. Does not spin on contention but waits in the kernel to be woken up by an unlock.

> As with OSSpinLock there is no attempt at fairness or lock ordering, e.g. an unlocker can potentially immediately reacquire the lock before a woken up waiter gets an opportunity to attempt to acquire the lock. This may be advantageous for performance reasons, but also makes starvation of waiters a possibility.

* 低等级的锁，允许等待者在竞争中高效的阻挡。
* 一般来说，应该首选更高级别的同步原语，如pthread或dispatch子系统提供的同步原语。 
* 存储在锁中的值应该被视为不透明的，并且应该定义实现，它们包含系统可能用来解决优先级反转的线程所有权信息。 
* 此锁解锁，必须从锁定它的同一线程，尝试从其他线程解除锁定将导致断言中止进程。 
* 不能通过共享或多重映射内存从多个进程或线程访问此锁，锁的实现依赖于锁值和所属进程的地址。
* 必须使用 OS_UNFAIR_LOCK_INIT 初始化
* 替换已弃用的OSSpinLock。不会在争用时旋转，而是在内核中等待解锁唤醒。
* 与OSSpinLock一样，不存在公平性或锁排序的尝试，例如，在被叫醒的等待者有机会尝试获取锁之前，解锁器可能会立即重新获取锁。这可能有利于性能的原因，但也增加等待者饥饿的一点可能。

看到这段话，我立刻想起了[不再安全的 OSSpinLock](https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/) 这篇文章。里面写明了，因为自旋锁的优先级反转问题，是的自旋锁被弃用，这样一来一切都说的通了。

