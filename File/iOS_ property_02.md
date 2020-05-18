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


# 2. 什么是原子性

atomic 一般会被翻译成原子性。它表示一个”不可再分割“的单元。

话说回来，现在原子已经并非是不可分割的，但是提出这个概念的时候，并非如此，所以就直接简单的等价于**不可分割**，就可以了，和物理学没什么关系。