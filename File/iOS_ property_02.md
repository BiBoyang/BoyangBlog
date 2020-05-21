# @property 原理（二）：nonatomic & atomic

atomic 一般会被翻译成原子性。它表示一个”不可再分割“的单元，也就是**单指令操作**。

话说回来，现在原子已经并非是不可分割的，但是提出这个概念的时候，并非如此，所以就直接简单的等价于**不可分割**，就可以了，和物理学没什么关系。所以在下面的内容里，不会直接使用原子性，而是直接用 atomic 来说明。

从某种意义上来讲，线程安全的元素是，它本身就是 atomic 的。

# iOS 中的 atomic

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

## StripedMap

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

## spinlock_t

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

> 低等级的锁，允许等待者在竞争中高效的阻挡。
> 一般来说，应该首选更高级别的同步原语，如pthread或dispatch子系统提供的同步原语。 
> 存储在锁中的值应该被视为不透明的，并且应该定义实现，它们包含系统可能用来解决优先级反转的线程所有权信息。 
> 此锁解锁，必须从锁定它的同一线程，尝试从其他线程解除锁定将导致断言中止进程。 
> 不能通过共享或多重映射内存从多个进程或线程访问此锁，锁的实现依赖于锁值和所属进程的地址。
> 必须使用 OS_UNFAIR_LOCK_INIT 初始化
> 替换已弃用的OSSpinLock。不会在争用时旋转，而是在内核中等待解锁唤醒。
> 与OSSpinLock一样，不存在公平性或锁排序的尝试，例如，在被叫醒的等待者有机会尝试获取锁之前，解锁器可能会立即重新获取锁。这可能有利于性能的原因，但也增加等待者饥饿的一点可能。

看到这段话，我立刻想起了[不再安全的 OSSpinLock](https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/) 这篇文章。里面写明了，因为自旋锁的优先级反转问题，使自旋锁被弃用，这样一来一切都说的通了。目前 atomic 使用的是**互斥锁**。


# 自旋锁和互斥锁的区别
自旋锁是一种 busy-waiting 类型的锁，如果别的线程一直持有这个锁，在本线程上，就会一直处于 busy 状态，一直在循环的请求锁，当然这时候也是在消耗 CPU。

有时候，我们没有必要一直去尝试加锁，可以在抢锁失败之后，只要锁的状态没有改变，那么就不去管它；其他线程的锁的状态一旦改变，操作系统会进行通知，这样就叫做互斥锁。这里涉及到了线程的上下文切换，所以操作花销相对的多一些。

自旋锁因为在未获得锁的时候不断的进行请求。而互斥锁则算的上一劳永逸，等到锁好了再开始。
所以，如果当前的操作比较小，持有锁的时间短，就可以使用自旋锁；而如果一旦持有锁的时间长，耗费的 CPU 时间已经比线程调度要多的时候，就可以使用互斥锁。


# 并不安全的 atomic
认真的说，atmoic 的所谓的线程安全，其实只是针对修饰的对象的**读/写**操作，如果一个线程在对它进行 setter/getter 操作，其他的线程就需要等待。

但是如果将它添加到另外一个线程，或者在另外的线程调用了 release 方法，那么就会出问题，因为 release 方法本身就不受 getter/setter 操作的限制。

# 实际场景

看起来，atomic 好像完全没什么用了，但是其实 atomic 单纯的作为锁来使用，性能还算不错，但是只能**对读写操作**进行使用，我们依然可以在某些情况下使用它。

我曾经接收过一个老项目，项目里有一个集中展示其他人头像的页面，在这个页面，检测平台会上报几个 crash，而且版本分部很均匀，使用的版本库还是手动引入的 SDWebImage，版本推测是 3.8。

具体的堆栈我没有记录，崩溃的点是在 SDWebImageDownloaderOperation 方法上，是一个 EXC_BAD_ACCESS 错误。

当时想了很久，还是百思不得其解，然后询问了几个朋友，才发现这个 crash 的原因。

```C++
objc_getProperty
······
    // M:如果是非原子性操作，直接返回属性的对象指针
    if (!atomic) return *slot;
······
reallySetProperty
······
if (!atomic) {
        //M:非原子操作，将slot指针指向的对象引用赋值给oldValue
        oldValue = *slot;
        //M:slot指针指向newValue，完成赋值操作
        *slot = newValue;
    } 
objc_release(oldValue);
```

直接看这段代码，会发现，nonatomic 修饰的对象，它如果先进行 getter 操作，但是没有完成，这个时候进行 setter，会将 oldValue 进行 release 操作；然后 getter 操作继续进行，使用到的是已经执行完 release 操作的 oldValue，就会发生 EXC_BAD_ACCESS。

这里有个最简单的修改方法，是直接使用 atomic 进行修饰，替换掉 nonatomic 。在新的版本里，就再也没有报这个错误了。

当然，实际上最安全的方式是将 SDWebImage 的版本进行更新，这个问题已经在 4.2 版本进行了修复。

另外还有一个曾经遇到的[面试题](https://github.com/BiBoyang/BoyangBlog/blob/master/File/InterviewQue_01%20.md)，里面就有 atomic 的比较简单的用法，可以用来借鉴学习。







# 引用

[不再安全的 OSSpinLock](https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/)





