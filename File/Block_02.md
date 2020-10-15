


# 0. 截获自动变量值
block 中，block 表达式截获所使用的自动变量的值，是保存该自动变量的瞬间值。在执行完 block 之后，即使改写 block 中使用的自动变量的值，也不会影响 block 执行时自动变量的值————这就是“截获”的意思；。


# 1. 如何截获变量

征得同意，这里直接拿冰霜的[文章](https://www.jianshu.com/p/ee9756f3d5f6)来用

```C++
#import <Foundation/Foundation.h>

int global_i = 1;

static int static_global_j = 2;

int main(int argc, const char * argv[]) {
   
    static int static_k = 3;
    int val = 4;
    
    void (^myBlock)(void) = ^{
        global_i ++;
        static_global_j ++;
        static_k ++;
        NSLog(@"Block中 global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    };
    
    global_i ++;
    static_global_j ++;
    static_k ++;
    val ++;
    NSLog(@"Block外 global_i = %d,static_global_j = %d,static_k = %d,val = %d",global_i,static_global_j,static_k,val);
    
    myBlock();
    
    return 0;
}

```

运行结果
```C++
Block 外  global_i = 2,static_global_j = 3,static_k = 4,val = 5
Block 中  global_i = 3,static_global_j = 4,static_k = 5,val = 4
```
我们使用 **clang -rewrite-objc** 将一份 block 代码进行编译转换，将得到一份C++代码。转换的结果为
```C++
int global_i = 1;

static int static_global_j = 2;

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  int *static_k;
  int val;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_k, int _val, int flags=0) : static_k(_static_k), val(_val) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  int *static_k = __cself->static_k; // bound by copy
  int val = __cself->val; // bound by copy

        global_i ++;
        static_global_j ++;
        (*static_k) ++;
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_6fe658_mi_0,global_i,static_global_j,(*static_k),val);
    }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};


int main(int argc, const char * argv[]) {

    static int static_k = 3;
    int val = 4;

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &static_k, val));

    global_i ++;
    static_global_j ++;
    static_k ++;
    val ++;
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_6fe658_mi_1,global_i,static_global_j,static_k,val);

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}

```

首先全局变量 global_i 和静态全局变量 static_global_j 的值增加，以及它们会被 block 捕获进去，这一点很好理解，因为是全局的，作用域很广，所以 block 捕获了它们进去之后，在 block 内部进行 ++，block 结束之后，它们的值依旧可以得以保存下来。

在 __main_block_impl_0 中，可以看到静态变量 static_k 和自动变量 val ，被 block 从外面捕获进来，成为 __main_block_impl_0 这个结构体的成员变量了。

在执行 block 语法的时候，block 语法表达式所使用的自动变量的值是被保存进了 block 的结构体实例中，也就是 block 自身中。

这么看就清晰了很多，**自动变量是以值传递方式传递到 block 的构造函数里面去的**。 block 只捕获 block 中会用到的变量。**由于只捕获了自动变量的值，并非内存地址**，所以 block 内部不能改变自动变量的值。

即，block 可以直接改写以下几种变量：
* 静态变量
* 静态全局变量
* 全局变量


# 修改自动变量

截获变量并修改有两种方法 **__block** 和 **指针法**（不过 __block 法归根结底，其实也是操作指针）。这里描述一下指针法：

```C++
NSMutableString * str = [[NSMutableString alloc]initWithString:@"Hello,"];
    
void (^myBlock)(void) = ^{
    [str appendString:@"World!"];
    NSLog(@"Block中 str = %@",str);
    };
NSLog(@"Block外 str = %@",str);
myBlock();
    
const char *text = "hello";
void(^block)(void) = ^{
    printf("%caaaaaaaaaaa\n",text[2]);
};
block();
```

直接操作指针去进行截获，不过一般来讲，这种方法多用于 C 语言数组的时候。使用 OC 的时候多数是使用 __block 。

这里写一个 __block 的捕获代码，使用刚才的方法再来一次：

## 1.普通非对象的变量

```C++
struct __Block_byref_i_0 {
  void *__isa;
__Block_byref_i_0 *__forwarding;//指向真正的block
 int __flags;
 int __size;
 int i;//对象
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __Block_byref_i_0 *i; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_i_0 *_i, int flags=0) : i(_i->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_i_0 *i = __cself->i; // bound by ref

        (i->__forwarding->i) ++;
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_3b0837_mi_0,(i->__forwarding->i));
    }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->i, (void*)src->i, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->i, 8/*BLOCK_FIELD_IS_BYREF*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};
int main(int argc, const char * argv[]) {
    __attribute__((__blocks__(byref))) __Block_byref_i_0 i = {(void*)0,(__Block_byref_i_0 *)&i, 0, sizeof(__Block_byref_i_0), 0};

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_i_0 *)&i, 570425344));

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}

```

我们可以发现这里多了个结构体

```C++
struct __Block_byref_i_0 {
  void *__isa;
__Block_byref_i_0 *__forwarding;
 int __flags;
 int __size;
 int i;
};
```

在这个实例内，包含了 **__isa** 指针、一个标志位 **__flags** 、一个记录大小的 **__size** 。最最最重要的，多了一个 **__forwarding** 指针和 val 变量.
这里长话短说，出来了一个新的 **__forwarding**指针,指向了**结构体实例本身在内存的地址**。

block 通过指针的持续传递，将使用的**自动变量值**保存到了 block 的结构体实例中。在 block 内部内修改 **__block0** 变量，通过一系列指针指向关系，最终指向了 __Block_byref_age_0 结构体内与局部变量同名同类型的那个成员，并成功修改变量值。

在栈中， **__forwarding** 指向了自己本身，但是如果复制到了堆上，**__forwarding** 就指向复制到堆上的 block，而堆上的 block 中的 **__forwarding** 这时候指向了自己。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/block_6.jpg?raw=true)

## 2.对象的变量

```C++
//以下代码是在ARC下执行的
#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
     
    __block id block_obj = [[NSObject alloc]init];
    id obj = [[NSObject alloc]init];

    NSLog(@"block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    
    void (^myBlock)(void) = ^{
        NSLog(@"***Block中****block_obj = [%@ , %p] , obj = [%@ , %p]",block_obj , &block_obj , obj , &obj);
    };
    
    myBlock();
   
    return 0;
}
```

转换之后

```C++
struct __Block_byref_block_obj_0 {
  void *__isa;
__Block_byref_block_obj_0 *__forwarding;//指向真正的block
 int __flags;
 int __size;
 void (*__Block_byref_id_object_copy)(void*, void*);
 void (*__Block_byref_id_object_dispose)(void*);
 id block_obj;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  id obj;
  __Block_byref_block_obj_0 *block_obj; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, id _obj, __Block_byref_block_obj_0 *_block_obj, int flags=0) : obj(_obj), block_obj(_block_obj->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_block_obj_0 *block_obj = __cself->block_obj; // bound by ref
  id obj = __cself->obj; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_e64910_mi_1,(block_obj->__forwarding->block_obj) , &(block_obj->__forwarding->block_obj) , obj , &obj);
    }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->block_obj, (void*)src->block_obj, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_assign((void*)&dst->obj, (void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->block_obj, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_dispose((void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};


int main(int argc, const char * argv[]) {

    __attribute__((__blocks__(byref))) __Block_byref_block_obj_0 block_obj = {(void*)0,(__Block_byref_block_obj_0 *)&block_obj, 33554432, sizeof(__Block_byref_block_obj_0), __Block_byref_id_object_copy_131, __Block_byref_id_object_dispose_131, ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"))};

    id obj = ((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"));
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_45_k1d9q7c52vz50wz1683_hk9r0000gn_T_main_e64910_mi_0,(block_obj.__forwarding->block_obj) , &(block_obj.__forwarding->block_obj) , obj , &obj);

    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, obj, (__Block_byref_block_obj_0 *)&block_obj, 570425344));

    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}

```
在转换出来的源码中，我们也可以看到，block 捕获了 __block ，并且强引用了它，因为在 __Block_byref_block_obj_0 结构体中，有一个变量是 id block_obj ，这个默认也是带 __strong 所有权修饰符的。

根据打印出来的结果来看，ARC 环境下，block 捕获外部对象变量，是都会 copy 一份的，地址都不同。只不过带有 __block 修饰符的对象会被捕获到 block 内部持有。

对于声明为__block 的外部对象，在block 内部会**进行持有**，以至于在 block 环境内能安全的引用外部对象。

## 3. 实例变量

之前一直没有想到过一个问题：

我们知道不应该在 block 中使用实例变量，是因为会发生循环引用；那为什么会发生循环引用呢？

一般我们会理解为，一个 _age 的实例变量，实际上是 self->_age 。那么如果往下深究下去呢？

受[谈谈ivar的直接访问](http://satanwoo.github.io/2018/02/04/iOS-iVar/)的启发，我也开始探索一下这里的原因。

写如下的代码：
```C++

#import <Foundation/Foundation.h>
#import "objc/runtime.h"

typedef void(^MyBlock)(void);

@interface MyObject : NSObject
@property (nonatomic) NSUInteger BRInteger;
@property (nonatomic, copy) NSString *BRString;
@property (nonatomic, copy) MyBlock BRBlock;

- (void)inits;

@end

@implementation MyObject
- (void)inits
{
    self.BRBlock = ^{
        _BRInteger = 5;
        _BRString = @"Balaeniceps_rex";
    };
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        MyObject *object = [MyObject new];
        [object inits];
    }
    return 0;
}
```
使用 **clang -rewrite-objc -fobjc-arc -stdlib=libc++ -mmacosx-version-min=10.7 -fobjc-runtime=macosx-10.7 -Wno-deprecated-declarations main.m**命令进行转换。得到以下的代码（为了简便，将代码做了省略）：

```C++
typedef void(*MyBlock)(void);

#ifndef _REWRITER_typedef_MyObject
#define _REWRITER_typedef_MyObject
typedef struct objc_object MyObject;
typedef struct {} _objc_exc_MyObject;
#endif

//对于每个ivar，都有对应的全局变量
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRInteger;
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRString;
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRBlock;
//内部的结构
struct MyObject_IMPL {
    struct NSObject_IMPL NSObject_IVARS;
    NSUInteger _BRInteger;
    NSString *__strong _BRString;
    __strong MyBlock _BRBlock;
};

// @property (nonatomic) NSUInteger BRInteger;
// @property (nonatomic, copy) NSString *BRString;
// @property (nonatomic, copy) MyBlock BRBlock;

// - (void)inits;

/* @end */


// @implementation MyObject

struct __MyObject__inits_block_impl_0 {
    struct __block_impl impl;
    struct __MyObject__inits_block_desc_0* Desc;
    MyObject *const __strong self;
    
    //注意这里捕捉了self
    __MyObject__inits_block_impl_0(void *fp, struct __MyObject__inits_block_desc_0 *desc, MyObject *const __strong _self, int flags=0) : self(_self) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

//block的函数方法（也就是方法layout中第四行的那个）
static void __MyObject__inits_block_func_0(struct __MyObject__inits_block_impl_0 *__cself) {
    MyObject *const __strong self = __cself->self; // bound by copy
    //这里是通过self的地址，那倒全局变量的偏移去获取实例变量的地址
    (*(NSUInteger *)((char *)self + OBJC_IVAR_$_MyObject$_BRInteger)) = 5;
    (*(NSString *__strong *)((char *)self + OBJC_IVAR_$_MyObject$_BRString)) = (NSString *)&__NSConstantStringImpl__var_folders_m1_05zb_zbd1g1f8k27nc6yn_th0000gn_T_main_e9db32_mi_0;
}
static void __MyObject__inits_block_copy_0(struct __MyObject__inits_block_impl_0*dst, struct __MyObject__inits_block_impl_0*src) {_Block_object_assign((void*)&dst->self, (void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __MyObject__inits_block_dispose_0(struct __MyObject__inits_block_impl_0*src) {_Block_object_dispose((void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __MyObject__inits_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(struct __MyObject__inits_block_impl_0*, struct __MyObject__inits_block_impl_0*);
    void (*dispose)(struct __MyObject__inits_block_impl_0*);
} __MyObject__inits_block_desc_0_DATA = { 0, sizeof(struct __MyObject__inits_block_impl_0), __MyObject__inits_block_copy_0, __MyObject__inits_block_dispose_0};

static void _I_MyObject_inits(MyObject * self, SEL _cmd) {
    ((void (*)(id, SEL, MyBlock))(void *)objc_msgSend)((id)self, sel_registerName("setBRBlock:"), ((void (*)())&__MyObject__inits_block_impl_0((void *)__MyObject__inits_block_func_0, &__MyObject__inits_block_desc_0_DATA, self, 570425344)));
}

static NSUInteger _I_MyObject_BRInteger(MyObject * self, SEL _cmd) { return (*(NSUInteger *)((char *)self + OBJC_IVAR_$_MyObject$_BRInteger)); }
static void _I_MyObject_setBRInteger_(MyObject * self, SEL _cmd, NSUInteger BRInteger) { (*(NSUInteger *)((char *)self + OBJC_IVAR_$_MyObject$_BRInteger)) = BRInteger; }

static NSString * _I_MyObject_BRString(MyObject * self, SEL _cmd) { return (*(NSString *__strong *)((char *)self + OBJC_IVAR_$_MyObject$_BRString)); }
extern "C" __declspec(dllimport) void objc_setProperty (id, SEL, long, id, bool, bool);

static void _I_MyObject_setBRString_(MyObject * self, SEL _cmd, NSString *BRString) { objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct MyObject, _BRString), (id)BRString, 0, 1); }

static void(* _I_MyObject_BRBlock(MyObject * self, SEL _cmd) )(){ return (*(__strong MyBlock *)((char *)self + OBJC_IVAR_$_MyObject$_BRBlock)); }
static void _I_MyObject_setBRBlock_(MyObject * self, SEL _cmd, MyBlock BRBlock) { objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct MyObject, _BRBlock), (id)BRBlock, 0, 1); }
// @end

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        
        MyObject *object = ((MyObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("MyObject"), sel_registerName("new"));
        ((void (*)(id, SEL))(void *)objc_msgSend)((id)object, sel_registerName("inits"));
    }
    return 0;
}
```
我们可以发现，每个实例变量都是被创建了对应的全局变量：

```C++
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRInteger;
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRString;
extern "C" unsigned long OBJC_IVAR_$_MyObject$_BRBlock;
```
下面是 block 的 layout 中的第四排的函数调用方法。

```C++
//block的函数方法（也就是方法layout中第四行的那个）
static void __MyObject__inits_block_func_0(struct __MyObject__inits_block_impl_0 *__cself) {
    MyObject *const __strong self = __cself->self; // bound by copy
    //这里是通过self的地址，那倒全局变量的偏移去获取实例变量的地址
    (*(NSUInteger *)((char *)self + OBJC_IVAR_$_MyObject$_BRInteger)) = 5;
    (*(NSString *__strong *)((char *)self + OBJC_IVAR_$_MyObject$_BRString)) = (NSString *)&__NSConstantStringImpl__var_folders_m1_05zb_zbd1g1f8k27nc6yn_th0000gn_T_main_e9db32_mi_0;
}
```
通过这里，我们其实也能发现，这里是通过 self 的偏移去获取实例变量的地址，也是和 self 息息相关的。

如果这个还不会证明实例变量中的 self 的作用的话，我们接着往下看；
```C++
struct __MyObject__inits_block_impl_0 {
    struct __block_impl impl;
    struct __MyObject__inits_block_desc_0* Desc;
    MyObject *const __strong self;
    
    //注意这里捕捉了self
    __MyObject__inits_block_impl_0(void *fp, struct __MyObject__inits_block_desc_0 *desc, MyObject *const __strong _self, int flags=0) : self(_self) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```
在这个方法里，我们可以发现，在 block 当中，其实也引用到 MyObject ，是一个强引用的 self ！而 block 的构造函数中也多次引用了 self 。

我们如果了解过 property 的话，也会知道实例变量是在编译期就确定地址了。内部实现的全局变量就代表了地址的 offset 。


# 引用
[深入研究Block捕获外部变量和__block实现原理](https://www.jianshu.com/p/ee9756f3d5f6)

[Block Implementation Specification](http://clang.llvm.org/docs/Block-ABI-Apple.html)

[谈谈ivar的直接访问](http://satanwoo.github.io/2018/02/04/iOS-iVar/)

《Objective-C 高级编程》