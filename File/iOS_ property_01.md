##### @property 原理（一）：概述

> 如果没有特殊标明，下面的所有代码都是在ARC环境下。


# 前言

在不使用属性的时候，我们往往会如下创建对象
```C++
@implementation ViewController
{
    NSString *aaa;   
}
```
但是这里有个问题：对象的内存布局在编译期已经被固定了。当你访问这个变量的时候，编译器就会将其替换为指针偏移量。这个偏移量是硬编码的，表示变量距离存放对象的内存区域的起始地址有多远。但是假如又加了一个变量，就要重新编译。

这种问题有两种解决方案:
> 1. 把实例变量当做一种存储偏移量的特殊变量交给类对象保管，然后偏移量会被在运行期中查找，如果类定义变了，那么偏移量也就变了；
> 2. 就是属性的方法。不直接访问实例变量，通过存取方法来处理。

# 原理

本质上：@property = 实例变量 + get 方法 + set 方法。

当使用 self.xx 的时候，如果是设置值，那么就是在调用 setter 方法，如果是获取值，那就是在调用 getter 方法。这也是为什么 getter 方法中为何不能用 self.xx 的原因。
```c++
- (NSString *)name {
    return self.name;  // 错误的写法，会造成死循环
}
```
self.name 实际上就是执行了属性 name 的 getter 方法，getter 方法中又调用了self.name，会一直递归调用，直到程序崩溃.

接着往下说。

编译器在编译期为实例变量添加的 setter、getter 方法。在 **runtime.h** 文件中，定义如下：

```C++
typedef struct objc_property *objc_property_t;
```

而 objc_property 是一个结构体，包括 name 和 attributes ，定义如下：

```
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
我们使用 **property_getAttributes** 方法，可以知道包括类型、原子性、内存语义和实例变量等。在下面我们可以看到相关代码。

# 关键字

默认状况下，OC 对象关键字是  **atomic**、**readwrite**、**strong**、；而基本数据类型是： **atomic**、**readwrite**、**assign**。

用 @property 的时候会自动创建创建实例变量和 setter、getter 方法。

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

然后通过[官方文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html)，查阅到T表示类型，C表示copy，N表示nonatomic，V表示实例变量————这个实际上就是方法签名。


## .cxx_destruct

这个方法实际上接触到的时候很少。






这里多出来一个 **.cxx_destruct** ，可以查看sunnyxx的[ARC下dealloc过程及.cxx_destruct的探究](http://blog.sunnyxx.com/2014/04/02/objc_dig_arc_dealloc/)来理解。
这个方法简单来讲作用如下：

* 1.只有在ARC下这个方法才会出现（试验代码的情况下）
* 2.只有当前类拥有实例变量时（不论是不是用property）这个方法才会出现，且父类的实例变量不会导致子类拥有这个方法
* 3.出现这个方法和变量是否被赋值，赋值成什么没有关系