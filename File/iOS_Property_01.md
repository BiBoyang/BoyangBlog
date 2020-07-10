# @property 原理（一）：概述
* 原作于：2017-10-02          
* GitHub Repo：[BoyangBlog](https://github.com/BiBoyang/BoyangBlog)
* 如果没有特殊标明，下面的所有代码都是在ARC环境下。

# 0. 前言

在不使用属性的时候，我们往往会如下创建对象
```C++
@implementation ViewController
{
    NSString *aaa;   
}
```
但是这里有个问题：**对象的内存布局在编译期已经被固定了**。当你访问这个变量的时候，编译器就会将其替换为指针偏移量。这个偏移量是硬编码的，表示变量距离存放对象的内存区域的起始地址有多远。但是假如又加了一个变量，就要重新编译。

这种问题有两种解决方案:
> 1. 把实例变量当做一种存储偏移量的特殊变量交给类对象保管，然后偏移量会被在运行期中查找，如果类定义变了，那么偏移量也就变了；
> 2. 就是属性的方法。不直接访问实例变量，通过存取方法来处理。

# 1. 原理

本质上：**@property = 实例变量 + get 方法 + set 方法**。

当使用 self.xx 的时候，如果是设置值，那么就是在调用 setter 方法，如果是获取值，那就是在调用 getter 方法。这也是为什么 getter 方法中为何不能用 self.xx 的原因。

```C++
- (NSString *)name {
    return self.name;  // 错误的写法，会造成死循环
}
```

self.name 实际上就是执行了属性 name 的 getter 方法，getter 方法中又调用了self.name，会一直递归调用，直到程序崩溃.

编译器在编译期为实例变量添加的 setter、getter 方法。在 **runtime.h** 文件中，定义如下：

```C++
typedef struct objc_property *objc_property_t;
```

而 objc_property 是一个结构体，包括 name 和 attributes ，定义如下：

```C++
struct property_t {
    const char *name;
    const char *attributes;
};
```

这里 attributes 本质是 **objc_property_attribute_t**，定义了 property 的一些属性，定义如下：

```C++
/// Defines a property attribute
typedef struct {
    const char *name;           /**< The name of the attribute */
    const char *value;          /**< The value of the attribute (usually empty) */
} objc_property_attribute_t;
```

我们使用 **property_getAttributes** 方法，可以知道包括类型、原子性、内存语义和实例变量等。在后面我们可以看到相关代码。


# 2. clang 编译
我们也可以使用 clang 编译，将代码转换为 C++ 代码来查看。

原有代码如下：
```C++
#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, copy) NSString *Boyang;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.Boyang = @"bby_bby";   
}
```
编译之后如下（截取一部分，完整代码可以到[此处查看](https://github.com/BiBoyang/BoyangBlog/tree/master/Code/property)）：

```C++
extern "C" unsigned long OBJC_IVAR_$_ViewController$_Boyang;
struct ViewController_IMPL {
	struct UIViewController_IMPL UIViewController_IVARS;
	NSString *_Boyang;
};
......

......
static void _I_ViewController_viewDidLoad(ViewController * self, SEL _cmd) {
    ((void (*)(__rw_objc_super *, SEL))(void *)objc_msgSendSuper)((__rw_objc_super){(id)self, (id)class_getSuperclass(objc_getClass("ViewController"))}, sel_registerName("viewDidLoad"));

    ((void (*)(id, SEL, NSString *))(void *)objc_msgSend)((id)self, sel_registerName("setBoyang:"), (NSString *)&__NSConstantStringImpl__var_folders_jm_ysj60wg13t550dd6gv6l5d600000gn_T_ViewController_be3765_mi_0);

}



static NSString * _I_ViewController_Boyang(ViewController * self, SEL _cmd) { return (*(NSString **)((char *)self + OBJC_IVAR_$_ViewController$_Boyang)); }
extern "C" __declspec(dllimport) void objc_setProperty (id, SEL, long, id, bool, bool);

static void _I_ViewController_setBoyang_(ViewController * self, SEL _cmd, NSString *Boyang) { 
objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct ViewController, _Boyang), (id)Boyang, 0, 1); }
......

......

extern "C" unsigned long int OBJC_IVAR_$_ViewController$_Boyang __attribute__ ((used, section ("__DATA,__objc_ivar"))) = __OFFSETOFIVAR__(struct ViewController, _Boyang);

static struct /*_ivar_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count;
	struct _ivar_t ivar_list[1];
} _OBJC_$_INSTANCE_VARIABLES_ViewController __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_ivar_t),
	1,
	{{(unsigned long int *)&OBJC_IVAR_$_ViewController$_Boyang, "_Boyang", "@\"NSString\"", 3, 8}}
};

static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[5];
} _OBJC_$_INSTANCE_METHODS_ViewController __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	5,
	{{(struct objc_selector *)"viewDidLoad", "v16@0:8", (void *)_I_ViewController_viewDidLoad},
	{(struct objc_selector *)"Boyang", "@16@0:8", (void *)_I_ViewController_Boyang},
	{(struct objc_selector *)"setBoyang:", "v24@0:8@16", (void *)_I_ViewController_setBoyang_},
	{(struct objc_selector *)"Boyang", "@16@0:8", (void *)_I_ViewController_Boyang},
	{(struct objc_selector *)"setBoyang:", "v24@0:8@16", (void *)_I_ViewController_setBoyang_}}
};
```
我们可以发现， 编译器自动生成了一个 `ViewController_IMPL`结构体，保存了名为 **_Boyang** 的实例变量。

然后会在 viewDidLoad 中自动生成它的 set 方法。

上面代码里多次提到 OFFSET ，我们可以直观的了解到：属性是通过运行时计算出 offset ，然后再以一个锚点（比如说 self），去计算出真正的位置。而如果使用实例变量，则这个 offset 是在编译的时候就直接确定了。

最明显的在这里：
```C++
static NSString * _I_ViewController_Boyang(ViewController * self, SEL _cmd) { return (*(NSString **)((char *)self + OBJC_IVAR_$_ViewController$_Boyang)); }
extern "C" __declspec(dllimport) void objc_setProperty (id, SEL, long, id, bool, bool);

static void _I_ViewController_setBoyang_(ViewController * self, SEL _cmd, NSString *Boyang) { objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct ViewController, _Boyang), (id)Boyang, 0, 1); }
```

使用 __OFFSETOFIVAR__ 来计算偏移量，计算出偏移量后使用 objc_setProperty 来设置实例变量 _Boyang 的值。

再往下看，有三块内容需要了解：

## _ivar_t
```C++
struct _ivar_t {
	unsigned long int *offset;  // pointer to ivar offset location
	const char *name;
	const char *type;
	unsigned int alignment;
	unsigned int  size;
};
......

static struct /*_ivar_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count;
	struct _ivar_t ivar_list[1];
} _OBJC_$_INSTANCE_VARIABLES_ViewController __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_ivar_t),
	1,
	{{(unsigned long int *)&OBJC_IVAR_$_ViewController$_Boyang, "_Boyang", "@\"NSString\"", 3, 8}}
};
```
_ivar_t 结构体表示每一个实例变量，记录了偏移值、名称、类型、对齐方式和大小，用于描述每一个实例变量。

这个 _ivar_list_t 结构体，表示类的实例变量列表，记录了实例变量的大小、个数、以及每一个实例变量描述；每在类中加入一个属性，编译器都会在 _ivar_list_t 变量中加入一个 _ivar_t 的实例变量描述。

## _objc_method 
```C++
struct _objc_method {
	struct objc_selector * _cmd;
	const char *method_type;
	void  *_imp;
};
......

static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[5];
} _OBJC_$_INSTANCE_METHODS_ViewController __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	5,
	{{(struct objc_selector *)"viewDidLoad", "v16@0:8", (void *)_I_ViewController_viewDidLoad},
	{(struct objc_selector *)"Boyang", "@16@0:8", (void *)_I_ViewController_Boyang},
	{(struct objc_selector *)"setBoyang:", "v24@0:8@16", (void *)_I_ViewController_setBoyang_},
	{(struct objc_selector *)"Boyang", "@16@0:8", (void *)_I_ViewController_Boyang},
	{(struct objc_selector *)"setBoyang:", "v24@0:8@16", (void *)_I_ViewController_setBoyang_}}
};
```
_objc_method 结构体描述了每一个实例方法，包括一个 SEL 类型的指针、方法类型和方法实现。
_method_list_t 结构体表示类的实例方法列表，记录了每一个实例方法的大小、实例方法个数以及具体的实例方法描述，每加入一个属性则会在 _method_list_t 中增加 setter 与 getter 方法的描述。

## _prop_t

```C++
struct _prop_t {
	const char *name;
	const char *attributes;
};
```

_prop_t 结构体描述了每一个属性，包括名称和属性值，其实就是 property_t 在 clang 中的表示。

## 小结
以上是使用 clang 转换过的代码得到的一些信息，不过我们要注意，使用 clang 和实际的底层实现，可能表现的并非完全一致， clang 本身会做很多优化，添加很多代码，如果看过 clang 转换 block 代码的话，可能会更加理解。


# 3. get 方法

这里不再需要使用 clang 来转换了，直接来看 runtime 的源码吧。

在 `objc-accessors.mm` 文件中，有详细的 getter 实现的代码。

这里将 **id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic)** 的参数说明一下。

* self   : 隐含参数，对象消息接收者
* _cmd   : 隐含参数，setter对应函数
* offset : 属性所在指针的偏移量
* atomic : 是否是原子操作


```C++
id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic) {
    if (offset == 0) {
        return object_getClass(self);
    }
    id *slot = (id*) ((char*)self + offset); //计算属性所在的指针偏移量
    if (!atomic) return *slot;//如果是非原子性操作，直接返回属性的对象指针
    
    spinlock_t& slotlock = PropertyLocks[slot];
    slotlock.lock();
    id value = objc_retain(*slot);
    slotlock.unlock();
    return objc_autoreleaseReturnValue(value);
}
```
> * 很有趣的一点：在 clang 转换过来的代码中，是找不到这个方法的，但是如果查看汇编，是可以找到 jmp	_objc_getProperty 的。

我们可以很有趣的发现，在 getter 方法中，修饰词里直接有关联的只有 atomic 和 nonatomic；并且实际上只使用到了 self 和 offset，getter 方法确实相对简单。

使用 nonatomic 修饰词，获取到属性值后立马返回；而使用 atomic 修饰的属性，在使用的过程中会有一段加锁解锁的过程，势必会造成性能的损耗，而且在最后会将获取到的对象加入自动释放池中。

这里的锁，是 PropertyLocks 类型的锁，类型是 StripedMap，它是一个模板类，传入类的参数，然后动态修改 array 的成员类型。

而最后，atomic 修饰的对象，会存注册到自动释放池之中。

更加具体的分析可以阅读下一节。


# 4. set 方法

同样在 `objc-accessors.mm` 文件中，有详细的 setter 实现的代码。

```C++
void objc_setProperty(id self, SEL _cmd, ptrdiff_t offset, id newValue, BOOL atomic, signed char shouldCopy) 
{
    bool copy = (shouldCopy && shouldCopy != MUTABLE_COPY);
    bool mutableCopy = (shouldCopy == MUTABLE_COPY);
    reallySetProperty(self, _cmd, newValue, offset, atomic, copy, mutableCopy);
}

void objc_setProperty_atomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, true, false, false);
}

void objc_setProperty_nonatomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, false, false, false);
}


void objc_setProperty_atomic_copy(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, true, true, false);
}

void objc_setProperty_nonatomic_copy(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, false, true, false);
}

```
这里几个方法，除了第一个，其他几个实际上都可以将其看成第一个的翻版。

而看到第一个方法，我们很快就能在上面 clang 转化的代码中找到对应的方法。
```C++
static void _I_ViewController_setBoyang_(ViewController * self, SEL _cmd, NSString *Boyang) { 
objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct ViewController, _Boyang), (id)Boyang, 0, 1); }
```
通过它，我们套入到第一个函数之中，可以发现，它实际上也就是 **objc_setProperty_nonatomic_copy** 的实现。

它们都最终使用 reallySetProperty 方法，我们来查看它。

这里将 **static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy)** 的参数说明一下。

* self : 隐含参数，对象消息接收者
* _cmd : 隐含参数，setter对应函数
* newValue : 需要赋值的传入
* offset : 属性所在指针的偏移量
* atomic : 是否是原子操作
* copy : 是否是浅拷贝
* mutableCopy : 是否是深拷贝


```C++
static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy)
{
    //偏移量是0的时候，指向的其实就是对象自身，对对象自身赋值
    if (offset == 0) {
        object_setClass(self, newValue);
        return;
    }

    id oldValue;
    //获取属性的对象指针
    id *slot = (id*) ((char*)self + offset);

    if (copy) {
        //浅拷贝，将传入的新对象调用copyWithZone方法浅拷贝一份，并且赋值给newValue变量
        newValue = [newValue copyWithZone:nil];
    } else if (mutableCopy) {
        //深拷贝，将传入的新对象调用mutableCopyWithZone方法深拷贝一份，并且赋值给newValue变量
        newValue = [newValue mutableCopyWithZone:nil];
    } else {
        //非拷贝，且传入的对象与旧对象一致，直接返回
        if (*slot == newValue) return;
        //否则，调用objc_retain函数，将newValue变量指向对象引用计数+1，并且将返回值赋值给newValue变量
        newValue = objc_retain(newValue);
    }

    if (!atomic) {
        //非原子操作，将slot指针指向的对象引用赋值给oldValue
        oldValue = *slot;
        *slot = newValue;
    } else {
        //原子操作，则获取锁
        spinlock_t& slotlock = PropertyLocks[slot];
        slotlock.lock();
        oldValue = *slot;
        *slot = newValue;        
        slotlock.unlock();
    }
    //释放oldValue所持有的对象
    objc_release(oldValue);
}
```
可以得知，在 setter 方法中，需要考虑到 copy 关键字、atomic 关键字，进行相关处理，并且在处理之后，释放掉旧的对象。

这里涉及到 atomic、copy 等知识点，请阅读后续的文章。

# 5. 关键字

默认状况下，OC 对象关键字是  **atomic**、**readwrite**、**strong**；而基本数据类型是： **atomic**、**readwrite**、**assign**。

我们写一个属性:

```C++
@property (nonatomic, copy) NSString *Balaeniceps_rex;
```

然后利用 **class_copyPropertyList** 和 **class_copyMethodList**方法查看属性和方法：

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

```C++
属性信息__T@"NSString",C,N,V_Balaeniceps_rex
方法列表:(
    "Balaeniceps_rex",
    "setBalaeniceps_rex:",
    ".cxx_destruct",
    viewDidLoad
    )
```

然后通过[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html)，查阅到 T 表示类型，C 表示 copy，N 表示nonatomic，V 表示实例变量 ——— 这个实际上就是方法签名。


### .cxx_destruct

在上一节，我们会发现打印的时候多出来一个 **.cxx_destruct** ，可以查看sunnyxx的[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)来理解。
这个方法简单来讲作用如下：

* 1. 只有在ARC下这个方法才会出现（试验代码的情况下）
* 2. 只有当前类拥有实例变量时（不论是不是用property）这个方法才会出现，且父类的实例变量不会导致子类拥有这个方法
* 3. 出现这个方法和变量是否被赋值，赋值成什么没有关系