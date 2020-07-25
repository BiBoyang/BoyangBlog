##### @property 原理（四）：内存管理相关（下）- iOS 中 weak 的原理

## weak的实现

可以在此处查看[objc4-723.tar.gz](https://opensource.apple.com/tarballs/objc4/)源码，也可以查看已经[注释过的源码](https://github.com/BiBoyang/iOS_runtime_note/blob/master/objc4-781.2/runtime/NSObject.mm)

流程可以简单地分为以下三步：

1. 初始化时：runtime会调用**objc_initWeak**函数，初始化一个新的weak指针指向对象的地址。
2. 添加引用时：**objc_initWeak**函数会调用 **objc_storeWeak()** 函数， **objc_storeWeak()** 的作用是更新指针指向，创建对应的弱引用表。
3. 释放时，调用**clearDeallocating**函数。**clearDeallocating**函数首先根据对象地址获取所有weak指针地址的数组，然后遍历这个数组把其中的数据设为nil，最后把这个entry从weak表中删除，最后清理对象的记录。

## 实现过程
当有一个weak的属性时。编译器会自动创建一下方法
```C++
objc_initWeak(&obj1,obj);//初始化
objc_destroyWeak(&obj1);//释放
```
在 **[NSObject.mm](https://github.com/BiBoyang/iOS_runtime_note/blob/master/objc4-781.2/runtime/NSObject.mm)** 文件中，找到方法的实现

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
```
**注：这里的实现代码是最新版的，但是即使是倒数第二版和这里稍有不同，不过并不影响读取，新版做了性能的优化。**

这里方法比较简单明了，但是我们要知道这里有一个潜在的前提条件：
> * location是一个没有被注册为__weak对象的有效指针。如果newObj是空指针或它指向的对象已经释放，则location也就是weak的指针将初始化为0（nil）。 否则，将object注册为指向location的__weak对象。 

这里是表层的判断，我们继续往下看相关实现

```C++
// 更新weak变量.
// 当设置HaveOld是true，即DoHaveOld，表示这个weak变量已经有值，需要被清理，这个值也有可能是nil
// 当设置HaveNew是true， 即DoHaveNew，表示有一个新值被赋值给weak变量，这个值也有可能是nil
// 当设置参数CrashIfDeallocating是true，即DoCrashIfDeallocating，如果newObj已经被释放或者newObj是一个不支持弱引用的类，则暂停进程
// deallocating或newObj的类不支持弱引用
// 当设置参数CrashIfDeallocating是false，即DontCrashIfDeallocating，则存储nil

enum CrashIfDeallocating {
    DontCrashIfDeallocating = false, DoCrashIfDeallocating = true
};
template <HaveOld haveOld, HaveNew haveNew,
          CrashIfDeallocating crashIfDeallocating>
static id 
storeWeak(id *location, objc_object *newObj)
{
    assert(haveOld  ||  haveNew);
    
    // 初始化当前正在 +initialize 的类对象为nil
    if (!haveNew) assert(newObj == nil);

    Class previouslyInitializedClass = nil;
    id oldObj;
    
    // 声明新旧SideTable，
    SideTable *oldTable;
    SideTable *newTable;

    // Acquire locks for old and new values.
    // Order by lock address to prevent lock ordering problems. 
    // Retry if the old value changes underneath us.
 retry:   
    // 如果weak ptr之前弱引用过一个obj，则将这个obj所对应的SideTable取出，赋值给oldTable
    if (haveOld) {
        oldObj = *location;
        oldTable = &SideTables()[oldObj];
    } else {
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
//// -1-
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
storeWeak函数的作用是在添加引用的时候，添加新的指针和创建对应的弱引用表。
* -1- 这里有关initialize方法的问题.
    在使用 **+initialized**方法的时候，因为这个方法是在alloc之前调用的。不这么做，可能会出现**+initialize**中调用了**storeWeak**方法，而在**storeWeak**方法中**weak_register_no_lock**方法中用到对象的 isa 还没有初始化完成的情况。

## 这里有几个关键方法，需要说明一下。

#### SideTable
这个是一个结构体。
```C++
enum HaveOld { DontHaveOld = false, DoHaveOld = true };
enum HaveNew { DontHaveNew = false, DoHaveNew = true };

struct SideTable {
    //原子操作自旋锁
    spinlock_t slock;
    // 引用计数的 hash 表
    RefcountMap refcnts;
    // weak 引用全局 hash 表
    weak_table_t weak_table;

    SideTable() {
        memset(&weak_table, 0, sizeof(weak_table));
    }

    ~SideTable() {
        _objc_fatal("Do not delete SideTable.");
    }

    void lock() { slock.lock(); }
    void unlock() { slock.unlock(); }
    void forceReset() { slock.forceReset(); }

    // Address-ordered lock discipline for a pair of side tables.

    template<HaveOld, HaveNew>
    static void lockTwo(SideTable *lock1, SideTable *lock2);
    template<HaveOld, HaveNew>
    static void unlockTwo(SideTable *lock1, SideTable *lock2);
};
```
这里面**slock**是为了防止竞争选择的自旋锁，第二个**refcnts**是协助对象的 isa 指针的extra_rc引用计数的变量，第三个**weak_table**就是我们要了解的关键，一个weak引用的哈希表。

```C++
struct weak_table_t {
    // 保存了所有指向指定对象的 weak 指针
    weak_entry_t *weak_entries;
    // 存储空间
    size_t    num_entries;
    // 参与判断引用计数辅助量
    uintptr_t mask;
    // hash key 最大偏移值
    uintptr_t max_hash_displacement;
};
```
这里的最大偏移量**max_hash_displacement**，是因为苹果创建的hash表使用的是开放寻址法中的线性探测法，元素默认会有偏移，用**max_hash_displacement**来记录写入元素时候所经过的最大偏移量和读取元素的时候所经历的最大偏移量,当读取的**hash_displacement**大于写入时候的**max_hash_displacement**的时候就会抛出错误.


我们继续往下看。
```C++
/**
 * The internal structure stored in the weak references table.
 //存储在弱引用表中的内部结构
 * It maintains and stores
 用来维护和存储
 * a hash set of weak references pointing to an object.
 指向对象的弱引用的哈希集
 * If out_of_line_ness != REFERRERS_OUT_OF_LINE then the set
 * is instead a small inline array.
  如果out_of_line_ness 不等于REFERRERS_OUT_OF_LINE，然后这个集合会被一个小的内联数组替代。
 */
#define WEAK_INLINE_COUNT 4

// out_of_line_ness field overlaps with the low two bits of inline_referrers[1].
//out_of_line_ness 的字段与低两位的inline_referrers[1]部分重叠
// inline_referrers[1] is a DisguisedPtr of a pointer-aligned address.
// inline_referrers[1]是一个指针对齐地址的DisguisedPtr
// The low two bits of a pointer-aligned DisguisedPtr will always be 0b00
// (disguised nil or 0x80..00) or 0b11 (any other address).
// 一个指针对齐地址的DisguisedPtr的低两位将地址将会变成 0b00（伪装的nil）或者0b11.
// Therefore out_of_line_ness == 0b10 is used to mark the out-of-line state.
// 因此out_of_line_ness == 0b10 被用于标记离线状态。
#define REFERRERS_OUT_OF_LINE 2

struct weak_entry_t {
    DisguisedPtr<objc_object> referent;
    union {
        struct {
            weak_referrer_t *referrers;
            uintptr_t        out_of_line_ness : 2;
            uintptr_t        num_refs : PTR_MINUS_2;
            uintptr_t        mask;
            uintptr_t        max_hash_displacement;
        };
        struct {
            // out_of_line_ness field is low bits of inline_referrers[1]
            weak_referrer_t  inline_referrers[WEAK_INLINE_COUNT];
        };
    };

    bool out_of_line() {
        return (out_of_line_ness == REFERRERS_OUT_OF_LINE);
    }

    weak_entry_t& operator=(const weak_entry_t& other) {
        memcpy(this, &other, sizeof(other));
        return *this;
    }

    weak_entry_t(objc_object *newReferent, objc_object **newReferrer)
        : referent(newReferent)
    {
        inline_referrers[0] = newReferrer;
        for (int i = 1; i < WEAK_INLINE_COUNT; i++) {
            inline_referrers[i] = nil;
        }
    }
};
```

<!-- 弱表是由单个自旋锁控制的哈希表。一个被分配的内存块，大多数是一个对象，但是在GC之下，任何这样的分配，可以是它的地址存储一个弱引用存储单元中，通过使用编译器生成的写屏障或手工编码的寄存器弱原语的使用。-->

与注册相关联是一个回调块，应对这种情况：其中一个被分配的内存块被回收。该表在分配内存的地址上被哈希。当弱引用标记内存改变它的引用，我们可以查看之前的引用。

因此，在哈希表中，由弱引用项索引的是当前存储该地址的所有位置的列表。

对于ARC，我们还跟踪是否存在一个任意被解除分配的对象，在调用dealloc之前将其简单地放置在表中，以及在内存回收之前释放**objc_clear_deallocating**。
 
我们在上边的代码中可以发现有两个 **weak_referrer_t**，第一个应该是我们正常情况下的weak表，第二个我有点没看明白，但是根据上下文，猜测可能是一个补充，在当前弱引用对象少于2个的时候，不在采用hash了，直接用数组去实现的。

这里确实有点难懂，上面的内容很多也是我的猜测。

这里直接借用朋友的一张图来表示SideTable。
 ![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/sidetable.png?raw=true)
 
在继续往下看，里面还有旧对象解除注册操作**weak_unregister_no_lock**和新对象添加注册操作**weak_register_no_lock**。
 ```C++
 id weak_register_no_lock(weak_table_t *weak_table, id referent_id, 
                      id *referrer_id, bool crashIfDeallocating)
{
    objc_object *referent = (objc_object *)referent_id;
    objc_object **referrer = (objc_object **)referrer_id;

    if (!referent  ||  referent->isTaggedPointer()) return referent_id;

    // ensure that the referenced object is viable
    bool deallocating;
    if (!referent->ISA()->hasCustomRR()) {
        deallocating = referent->rootIsDeallocating();
    }
    else {
        BOOL (*allowsWeakReference)(objc_object *, SEL) = 
            (BOOL(*)(objc_object *, SEL))
            object_getMethodImplementation((id)referent, 
                                           SEL_allowsWeakReference);
        if ((IMP)allowsWeakReference == _objc_msgForward) {
            return nil;
        }
        deallocating =
            ! (*allowsWeakReference)(referent, SEL_allowsWeakReference);
    }

    if (deallocating) {
        if (crashIfDeallocating) {
            _objc_fatal("Cannot form weak reference to instance (%p) of "
                        "class %s. It is possible that this object was "
                        "over-released, or is in the process of deallocation.",
                        (void*)referent, object_getClassName((id)referent));
        } else {
            return nil;
        }
    }

    // now remember it and where it is being stored
    weak_entry_t *entry;
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        append_referrer(entry, referrer);
    } 
    else {
        weak_entry_t new_entry(referent, referrer);
        weak_grow_maybe(weak_table);
        weak_entry_insert(weak_table, &new_entry);
    }

    // Do not set *referrer. objc_storeWeak() requires that the 
    // value not change.

    return referent_id;
}
------------
id weak_register_no_lock(weak_table_t *weak_table, id referent_id, 
                      id *referrer_id, bool crashIfDeallocating)
{
    objc_object *referent = (objc_object *)referent_id;
    objc_object **referrer = (objc_object **)referrer_id;

    if (!referent  ||  referent->isTaggedPointer()) return referent_id;

    // ensure that the referenced object is viable
    bool deallocating;
    if (!referent->ISA()->hasCustomRR()) {
        deallocating = referent->rootIsDeallocating();
    }
    else {
        BOOL (*allowsWeakReference)(objc_object *, SEL) = 
            (BOOL(*)(objc_object *, SEL))
            object_getMethodImplementation((id)referent, 
                                           SEL_allowsWeakReference);
        if ((IMP)allowsWeakReference == _objc_msgForward) {
            return nil;
        }
        deallocating =
            ! (*allowsWeakReference)(referent, SEL_allowsWeakReference);
    }

    if (deallocating) {
        if (crashIfDeallocating) {
            _objc_fatal("Cannot form weak reference to instance (%p) of "
                        "class %s. It is possible that this object was "
                        "over-released, or is in the process of deallocation.",
                        (void*)referent, object_getClassName((id)referent));
        } else {
            return nil;
        }
    }

    // now remember it and where it is being stored
    weak_entry_t *entry;
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        append_referrer(entry, referrer);
    } 
    else {
        weak_entry_t new_entry(referent, referrer);
        weak_grow_maybe(weak_table);
        weak_entry_insert(weak_table, &new_entry);
    }

    // Do not set *referrer. objc_storeWeak() requires that the 
    // value not change.

    return referent_id;
}
 ```

 
## hash表的动态调整 
我们知道，理想状态下的哈希表的查找性能是有所有集合中查找性能最高的，但是理想毕竟是理想。在哈希表中元素过多的时候，我们需要及时的扩容来提升性能。（尤其是使用开发地址法的时候！）
 
 这里有一个 **append_referrer**函数
 ```C++
 static void append_referrer(weak_entry_t *entry, objc_object **new_referrer) {
    if (! entry->out_of_line()) {
        // Try to insert inline.
        for (size_t i = 0; i < WEAK_INLINE_COUNT; i++) {
            if (entry->inline_referrers[i] == nil) {
                entry->inline_referrers[i] = new_referrer;
                return;
            }
        }
        // Couldn't insert inline. Allocate out of line.
        weak_referrer_t *new_referrers = (weak_referrer_t *)
            calloc(WEAK_INLINE_COUNT, sizeof(weak_referrer_t));
        // This constructed table is invalid, but grow_refs_and_insert
        // will fix it and rehash it.
        for (size_t i = 0; i < WEAK_INLINE_COUNT; i++) {
            new_referrers[i] = entry->inline_referrers[i];
        }
        entry->referrers = new_referrers;
        entry->num_refs = WEAK_INLINE_COUNT;
        entry->out_of_line_ness = REFERRERS_OUT_OF_LINE;
        entry->mask = WEAK_INLINE_COUNT-1;
        entry->max_hash_displacement = 0;
    }
  
  
    assert(entry->out_of_line());
    if (entry->num_refs >= TABLE_SIZE(entry) * 3/4) {
        return grow_refs_and_insert(entry, new_referrer);
    }
    size_t begin = w_hash_pointer(new_referrer) & (entry->mask);
    size_t index = begin;
    size_t hash_displacement = 0;
    while (entry->referrers[index] != nil) {
        hash_displacement++;
        index = (index+1) & entry->mask;
        if (index == begin) bad_weak_table(entry);
    }
    if (hash_displacement > entry->max_hash_displacement) {
        entry->max_hash_displacement = hash_displacement;
    }
    weak_referrer_t &ref = entry->referrers[index];
    ref = new_referrer;
    entry->num_refs++;
}
 ```
这里的关键代码在于，标明了，存储weak的哈希表，会在使用率在75%的时候进行扩充。扩充的方法是很简单的copy法。
 ```C++
 __attribute__((noinline, used))
static void grow_refs_and_insert(weak_entry_t *entry, 
                                 objc_object **new_referrer)
{
    assert(entry->out_of_line());
    size_t old_size = TABLE_SIZE(entry);
    size_t new_size = old_size ? old_size * 2 : 8;
    size_t num_refs = entry->num_refs;
    weak_referrer_t *old_refs = entry->referrers;
    entry->mask = new_size - 1;
    
    entry->referrers = (weak_referrer_t *)
        calloc(TABLE_SIZE(entry), sizeof(weak_referrer_t));
    entry->num_refs = 0;
    entry->max_hash_displacement = 0;
    
    for (size_t i = 0; i < old_size && num_refs > 0; i++) {
        if (old_refs[i] != nil) {
            append_referrer(entry, old_refs[i]);
            num_refs--;
        }
    }
    // Insert
    append_referrer(entry, new_referrer);
    if (old_refs) free(old_refs);
}
 ```
扩充一个容量是原来两倍的新的哈希表，并将旧哈希表的元素插入到新的哈希表中。
 
那么既然有扩充，也势必会有缩小。如果哈希表中元素过少，我们就应该及时的缩小这个哈希表，以免造成空间的浪费。

 ```C++
 static void weak_compact_maybe(weak_table_t *weak_table)
{
    size_t old_size = TABLE_SIZE(weak_table);
    // Shrink if larger than 1024 buckets and at most 1/16 full.
    if (old_size >= 1024  && old_size / 16 >= weak_table->num_entries) {
        weak_resize(weak_table, old_size / 8);
        // leaves new table no more than 1/2 full
    }
}
 ```
 如果空间使用率小于1/16的时候，就会把空间缩小为原有的1/8。
 
## 销毁过程

释放对象的时候，基本流程如下
1. 调用objc_release
2. 因为对象的引用计数为0，所以执行 dealloc
3. _objc_rootDealloc
4. object_dispose
5. objc_destructInstance
6. objc_clear_deallocating

objc_destructInstance方法
```C++
void *objc_destructInstance(id obj) 
{
    if (obj) {
        Class isa = obj->getIsa();

        if (isa->hasCxxDtor()) {
            object_cxxDestruct(obj);
        }

        if (isa->instancesHaveAssociatedObjects()) {
            _object_remove_assocations(obj);
        }

        if (!UseGC) objc_clear_deallocating(obj);
    }

    return obj;
}
```
这里的object_cxxDestruct方法可以查看[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)，最新版本的代码可能不是和文中所写完全相同，但是原理还是相同的----用来销毁对象的实例变量，并且调用父类的dealloc。

调用objc_clear_deallocating函数。

```C++
void objc_clear_deallocating(id obj) 
{
    assert(obj);

    if (obj->isTaggedPointer()) return;
    obj->clearDeallocating();
}
```
<!--我们顺着`clearDeallocating_slow`->`objc_object::clearDeallocating_slow`->`weak_clear_no_lock`->`weak_entry_remove`->`weak_compact_maybe`->......方法太多，总结起来太费事了（总算知道为什么大家的文章对于weak的释放写的那么语焉不详）。-->

总结objc_clear_deallocating的作用：
1. 从weak表中获取废弃对象的地址为键值的记录;
2. 将包含在记录中的所有附有 weak修饰符变量的地址，赋值为nil;
3. 将weak表中该记录删除;
4. 从引用计数表中删除废弃对象的地址为键值的记录。

接下来接着看

```C++
inline void 
objc_object::clearDeallocating()
{
    if (slowpath(!isa.nonpointer)) {
        // Slow path for raw pointer isa.
        sidetable_clearDeallocating();
    }
    else if (slowpath(isa.weakly_referenced  ||  isa.has_sidetable_rc)) {
        // Slow path for non-pointer isa with weak refs and/or side table data.
        clearDeallocating_slow();
    }

    assert(!sidetable_present());
}
```
我们会发现这是个内联函数，内部有两个方法；这两个方法内部都是用过 **weak_clear_no_lock**来清除弱引用。我们直接来看这个方法:

```C++
void 
weak_clear_no_lock(weak_table_t *weak_table, id referent_id) 
{
    objc_object *referent = (objc_object *)referent_id;

    weak_entry_t *entry = weak_entry_for_referent(weak_table, referent);
    if (entry == nil) {
        /// XXX shouldn't happen, but does with mismatched CF/objc
        //printf("XXX no entry for clear deallocating %p\n", referent);
        return;
    }

    // zero out references
    weak_referrer_t *referrers;
    size_t count;

    if (entry->out_of_line) {
        referrers = entry->referrers;
        count = TABLE_SIZE(entry);
    } 
    else {
        referrers = entry->inline_referrers;
        count = WEAK_INLINE_COUNT;
    }

    for (size_t i = 0; i < count; ++i) {
        objc_object **referrer = referrers[i];
        if (referrer) {
            if (*referrer == referent) {
                *referrer = nil;
            }
            else if (*referrer) {
                _objc_inform("__weak variable at %p holds %p instead of %p. "
                             "This is probably incorrect use of "
                             "objc_storeWeak() and objc_loadWeak(). "
                             "Break on objc_weak_error to debug.\n", 
                             referrer, (void*)*referrer, (void*)referent);
                objc_weak_error();
            }
        }
    }

    weak_entry_remove(weak_table, entry);
}
```
我们可以看到，这里清楚了对象所有的weak指针并设置为nil，同时从weak表中清除了对应的 **weak_entry_t**对象。

# autorelease
在我们使用weak对象的时候，会把weak引用的对象自动加入到自动释放池中。

```C++
{
	id __weak obj1 = obj;
	NSLog(@"%@", obj1);
}
```
可以转换为

```C++
id obj1;
obj_initWeak(&obj1, obj);
id tmp = objc_loadWeakRetained(&obj1);
objc_autorelease(tmp);
NSLog(@"%@", tmp);
objc_destory(&obj1);
```
我们可以发现，比原有的多出了两个方法

```C++
id tmp = objc_loadWeakRetained(&obj1);
objc_autorelease(tmp);
```

**objc_loadWeakRetained**函数会取出__weak修饰的对象并且retain；**objc_autorelease**函数会将对象注册到autoreleasepool当中。

当原对象的引用计数变成0的时候,在一个RunLoop循环内就可以将该对象以及该对象所有的弱引用释放掉了。
这里也印证了一个问题，在使用`weak`修饰的对象的时候，如果不想被立即释放，最好要使用`strong`修饰一下。这也是所谓的 **weak-strong dance**而不是只有的weak的原因。
