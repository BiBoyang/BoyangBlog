# @property属性相关（一）：原理、
###### 如果没有特殊标明，下面的所有代码都是在ARC环境下。
[官方文档](https://developer.apple.com/library/archive/releasenotes/ObjectiveC/ModernizationObjC/AdoptingModernObjective-C/AdoptingModernObjective-C.html#//apple_ref/doc/uid/TP40014150-CH1-SW13)
# @property的创造原因
在不使用属性的时候，我们往往会如下创建对象
```C++
@implementation ViewController
{
    NSString *aaa;   
}
```
但是这里有个问题，在于对象布局在编译期已经被固定了。当你访问这个变量的时候，编译器就会将其替换为指针偏移量。这个偏移量是硬编码的，表示变量距离存放对象的内存区域的起始地址有多远。但是假如又加了一个变量，就要重新编译。
这种问题有两种解决方案:
> 1. 把实例变量当做一种存储偏移量的特殊变量交给类对象保管，然后偏移量会被在运行期中查找，如果类定义变了，那么偏移量也就变了；
> 2. 就是属性的方法。不直接访问实例变量，通过存取方法来处理。

# 原理
编译器在编译期为实例变量添加的setter、getter方法。
在 **runtime.h**文件中，定义如下

```C++
typedef struct objc_property *objc_property_t;
```
而objc_property是一个结构体，包括name和attributes，定义如下：

```
struct property_t {
    const char *name;
    const char *attributes;
};
```
这里attributes本质是**objc_property_attribute_t**，定义了property的一些属性，定义如下：

```C++
/// Defines a property attribute
typedef struct {
    const char *name;           /**< The name of the attribute */
    const char *value;          /**< The value of the attribute (usually empty) */
} objc_property_attribute_t;
```
我们使用**property_getAttributes**方法，可以知道包括类型、原子性、内存语义和实例变量等。在下面我们可以看到相关代码。

# 关键字
默认状况下，OC对象关键字是 **strong**, **atomic**, **readwrite**；而基本数据类型是： **atomic**, **readwrite**, **assign**。

用@property的时候会自动创建创建实例变量和setter、getter方法。

我们写一个属性:

```C++
@property (nonatomic, copy) NSString *Balaeniceps_rex;
```
然后利用 **class_copyPropertyList** 和 **class_copyMethodList**方法查看属性和方法

```C++
    unsigned int propertyCount;
    objc_property_t *propertyList = class_copyPropertyList([self class], &propertyCount);
    for (unsigned int i = 0; i< propertyCount; i++)
    {
        const char *name = property_getName(propertyList[i]);
        NSLog(@"__%@",[NSString stringWithUTF8String:name]);
        objc_property_t property = propertyList[i];
        const char *a = property_getAttributes(property);
        NSLog(@"属性信息__%@",[NSString stringWithUTF8String:a]);
    }

    u_int methodCount;
    NSMutableArray *methodList = [NSMutableArray array];
    Method *methods = class_copyMethodList([self class], &methodCount);
    for (int i = 0; i < methodCount; i++)
    {
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
然后通过[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html)，查阅到T表示类型，C表示copy，N表示nonatomic，V表示实例变量----这个实际上就是方法签名。

这里多出来一个 **.cxx_destruct** ，可以查看sunnyxx的[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)来理解。
这个方法简单来讲作用如下：
* 1.只有在ARC下这个方法才会出现（试验代码的情况下）
* 2.只有当前类拥有实例变量时（不论是不是用property）这个方法才会出现，且父类的实例变量不会导致子类拥有这个方法
* 3.出现这个方法和变量是否被赋值，赋值成什么没有关系

## nonatomic&atomic
atomic的意思是 `单指令`的操作。对象的生成操作是不会被打断的。

atomic和nonatomic的主要区别是系统自动生成的getter/setter方法不同。atomic会自动为getter/setter方法加锁；而nonatomic则相反。

系统生成的 getter/setter 会保证 get、set 操作的完整性，不受其他线程影响。比如，线程 A 的 getter 方法运行到一半，线程 B 调用了 setter：那么线程 A 的 getter 还是能得到一个完好无损的对象。当然，也要付出性能的代价。

但是atomic并不是实际场景中的“安全”。它只保证本身的setter和getter方法安全，但是不保证它会不会被销毁，以及使用过程中添加到其他对象中的修改。

这里我们可以查看源码。

```C++
id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic) {
    if (offset == 0) {
        return object_getClass(self);
    }

    // Retain release world
    id *slot = (id*) ((char*)self + offset);
    if (!atomic) return *slot;
        
    // Atomic retain release world
    spinlock_t& slotlock = PropertyLocks[slot];
    slotlock.lock();
    id value = objc_retain(*slot);
    slotlock.unlock();
    
    // for performance, we (safely) issue the autorelease OUTSIDE of the spinlock.
    return objc_autoreleaseReturnValue(value);
}
```
在执行getter方法的时候，如果不是atomic的话，是不会加锁并进行额外的retain的。

```C++
void objc_setProperty_atomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, true, false, false);
}

void objc_setProperty_nonatomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, false, false, false);
}
static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy)
{
    if (offset == 0) {
        object_setClass(self, newValue);
        return;
    }

    id oldValue;
    id *slot = (id*) ((char*)self + offset);

    if (copy) {
        newValue = [newValue copyWithZone:nil];
    } else if (mutableCopy) {
        newValue = [newValue mutableCopyWithZone:nil];
    } else {
        if (*slot == newValue) return;
        newValue = objc_retain(newValue);
    }
//判断是否atomic
    if (!atomic) {
        oldValue = *slot;
        *slot = newValue;
    } else {
    //使用自旋锁
        spinlock_t& slotlock = PropertyLocks[slot];
        slotlock.lock();
        oldValue = *slot;
        *slot = newValue;        
        slotlock.unlock();
    }

    objc_release(oldValue);
}

```

这里的setter实际上是一个内联函数。我们可以发现如果是atomic的话，在内部会实现一个自旋锁，并同样会reatin，只有当方法完成之后才会被释放。

而如果是使用的nonatomic的话，可能会因为线程的频繁切换而造成 **EXC_BAD_ACCESS**。

## readwrite&readonly
没啥好说的，系统给打的一个标识。

## 内存管理相关

### assign
使用在对基本数据类型的简单赋值操作的时候。但是虽然它也可以用来修饰对象，但是应该坚决避免在这种情况。
原因在于：**它释放之后，指针不会自动置空。基本数据类型是会被放入栈中，由系统来同一处理。**

很多“古老”的代码里，或者从MRC转换过来的代码中，经常会发现这个的滥用。比如说delegate使用assign修饰，是有可能发生崩溃的。

### strong
用来修饰强引用的属性，会使对象引用计数+1.
当你需要长时间使用某个属性，并且不希望被自动释放的时候，就应该使用这个。修饰可变数据类型用此。

### unsafe_unretained
语义和assign类似，是weak在iOS4.0之前版本的补充。但是问题在于，对象释放之后还是会继续指向对象存在的内存，太危险了。
现在没什么意义了，别用。

### copy
一般来讲，对于不可变的对象使用这个修饰。在setter的时候相当于自动调用一次copy（也就是说，在没有执行setter方法的时候，是起不到作用的）。
如果想要令自己的类具备拷贝功能，是需要遵循 **NSCopying**协议，并实现 **copyWithZone**方法。而自己的immutable和mutable的类，实现拷贝的时候，是需要实现NSCopying和NSMutableCopying协议的。
* 深拷贝指的是，在拷贝对象自身的时候，将其底层数据一并复制过去。浅拷贝指的是只拷贝对象本身。

我们查看runtime源码，可以知道，是存在两个copy方法的。

```C++
+ (id)copyWithZone:(struct _NSZone *)zone {
    return (id)self;
}
+ (id)mutableCopyWithZone:(struct _NSZone *)zone {
    return (id)self;
}
```

在使用的时候，就分别是 **copy** 和 **mutableCopy** 两种方法，也就是**NSCopying**和**NSMutableCopying** 协议。
我们可以认为，在自动实现的setter方法中，实际上是执行了一个 [obj copy];的方法。

### weak
weak方法是用来在某些情况下替代strong的属性。它的特点是，不会使对象的引用计数加1，可以避免循环引用问题；并且不会保留传入的对象。如果对象被释放，那么对应的实例变量会被自动设置为nil，不会变成野指针。
有关weak更多的可以查看[下一篇文章](https://github.com/BiBoyang/BoyangBlog/blob/master/File/runtime_03.md)。

### 方法名
比如属性中的getter=isOn。
这种方法一般在使用BOOL值的时候用来指定方法名。了解的并不是很多。

### nullable&nonnull

nullable表示对象可以是NULL或nil，而nonnull表示对象不应该为空。
比如说
```C++
@property (nonatomic, weak, nullable) id object;
@property (nonatomic, strong, nonnull) NSString *str;
```


# 参考资料
<!-[iOS @property探究(二): 深入理解](https://www.jianshu.com/p/44d12884e24e)->
[Runtime源码 —— property和ivar](https://www.jianshu.com/p/89ac27684693)
[iOS中Weak的底层实现](https://www.jianshu.com/p/fa7210773e8f)
[atomic性能真的很差，并发queue+barrier性能真的很好吗？](https://www.jianshu.com/p/15df680d510e)

[atomic 和 nonatomic 有什么区别？](https://www.jianshu.com/p/7288eacbb1a2)

[谈nonatomic非线程安全问题](https://www.jianshu.com/p/b075bfd67899)

[iOS 底层解析weak的实现原理（包含weak对象的初始化，引用，释放的分析）](https://www.jianshu.com/p/13c4fb1cedea)

[weak 弱引用的实现方式](https://www.desgard.com/weak/)

[从经典问题来看 Copy 方法](https://www.desgard.com/copy/)
->
