
![](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_1.png)

## 简单概述

> block是C语言的扩充功能，我们可以认为它是 **带有自动变量的匿名函数**。

block是一个匿名的inline代码集合：
> * 参数列表，就像一个函数。
> * 是一个对象！
> * 有声明的返回类型
> * 可获得义词法范围的状态，。
> * 可选择性修改词法范围的状态。
> * 可以用相同的词法范围内定义的其它block共享进行修改的可能性
> * 在词法范围（堆栈框架）被破坏后，可以继续共享和修改词法范围（堆栈框架）中定义的状态




## block的实现

在LLVM的文件中，我找到了一份文档，[Block_private.h](https://llvm.org/svn/llvm-project/compiler-rt/tags/Apple/Libcompiler_rt-16/BlocksRuntime/Block_private.h)，这里可以查看到block的实现情况

```C++
struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor *descriptor;
    /* Imported variables. */
};

struct Block_descriptor {
    unsigned long int reserved;
    unsigned long int size;
    void (*copy)(void *dst, void *src);
    void (*dispose)(void *);
};

```
里面的invoke就是指向具体实现的函数指针，当block被调用的时候，程序最终会跳转到这个函数指针指向的代码区。
而 **Block_descriptor**里面最重要的就是 **copy**函数和 **dispose**函数，从命名上可以推断出，copy函数是用来捕获变量并持有引用，而dispose函数是用来释放捕获的变量。函数捕获的变量会存储在结构体 **Block_layout**的后面，在invoke函数执行前全部读出。

按照惯例，使用 **clang -rewrite-objc** 将一个代码进行编译转换，将得到一份C++代码。刨除其他无用的代码：
```C++
struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        (void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA);
    }
    return 0;
}
```
先看最直接的 **__block_impl**代码，

```C++
struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};
```
这里是一个结构体，里面的元素分别是

> * isa，指向所属类的指针，也就是block的类型
> * flags，标志变量，在实现block的内部操作时会用到
> * Reserved，保留变量
> * FuncPtr，block执行时调用的函数指针


接着, **__main_block_impl_0**因为包含了__block_impl，我们可以将它打开,直接看成
```C++
__main_block_impl_0{
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
    struct __main_block_desc_0 *Desc;
}
```
这么一来，我们可以将block理解为，一个OC对象、一个函数。

## 崩溃

如果我们把block设置为nil，然后去调用，会发生什么？
```C++
void (^block)(void) = nil;
block();
```
当我们运行的时候，它会崩溃，报错信息为 **Thread 1: EXC_BAD_ACCESS (code=1, address=0x10)**。

![置为nil的block](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_5.png)
我们可以发现，当把block置为nil的时候，第四行的函数指针，被置为NULL，注意，这里是NULL而不是nil。

我们给一个对象发送nil消息是没有问题的，但是给如果是NULL就会发生崩溃。

* nil：指向oc中对象的空指针
* Nil：指向oc中类的空指针
* NULL：指向其他类型的空指针，如一个c类型的内存指针
* NSNull：在集合对象中，表示空值的对象
* 若obj为nil:[obj message]将返回NO,而不是NSException
* 若obj为NSNull:[obj message]将抛出异常NSException

它直接访问到了函数指针，因为前三位分别是void、int、int，大小分别是8、4、4，加一块就为16，所以在十六位中，就表示出0x10地址的崩溃。
如果是在32位的系统中，void的大小是4，崩溃的地址应该就是0x0c。

## block的类型
我们可以知道，我们常见的block是有三种：
> * __NSGlobalBlock
> * __NSStackBlock
> * __NSMallocBlock

```C++
    void (^block)(void) = ^{
        NSLog(@"biboyang");
    };
    block();
    或
    static int age = 10;
        void(^block)(void) = ^{
            NSLog(@"Hello, World! %d",age);
        };
    block();
```
像是这种，没有对外捕获变量的，就是GlobaBlock。

```C++
    int b = 10;
    void(^block2)(void) = ^{
        NSLog(@"Hello, World! %d",b);
    };
    block2();
```
这种block，在MRC中，即是StackBlock。在ARC中，因为编译器做了优化，自动进行了copy，这种就是MallocBlock了。

之所以做这种优化的原因很好理解：

如果StackBlock访问了一个auto变量，因为自己是存在Stack上的，所以变量也就会被保存在栈上。但是因为栈上的数据是由系统自动进行管理的，随时都有可能被回收。非常容易造成野指针的问题。

怎么解决呢？复制到堆上就好了！

ARC也是如此做的。它会自动将栈上的block复制到堆上，所以，ARC下的block的属性关键词其实使用strong和copy都不会有问题，不过为了习惯，还是使用copy为好。


| Blcok的类 | 副本源的配置存储域 | 复制效果 |
| --- | --- | --- |
| __NSStackBlock | 栈 | 堆 |
| __NSGlobalBlock | 程序的数据区域 | 无用 |
| __NSMallocBlock | 堆 | 引用计数增加 |

> 系统默认调用copy方法把Block赋复制的四种情况
> 1. 手动调用copy
> 2. Block是函数的返回值
> 3. Block被强引用，Block被赋值给__strong或者id类型
> 4. 调用系统API入参中含有usingBlcok的Cocoa方法或者GCD的相关API

ARC环境下，一旦Block赋值就会触发copy，__block就会copy到堆上，Block也是__NSMallocBlock。ARC环境下也是存在__NSStackBlock的时候，这种情况下，__block就在栈上。

## 如何截获变量
这里直接拿冰霜的[文章](https://www.jianshu.com/p/ee9756f3d5f6)来用
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
转换的结果为
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
首先全局变量global_i和静态全局变量static_global_j的值增加，以及它们被Block捕获进去，这一点很好理解，因为是全局的，作用域很广，所以Block捕获了它们进去之后，在Block里面进行++操作，Block结束之后，它们的值依旧可以得以保存下来。

在__main_block_impl_0中，可以看到静态变量static_k和自动变量val，被Block从外面捕获进来，成为__main_block_impl_0这个结构体的成员变量了。
在执行Block语法的时候，Block语法表达式所使用的自动变量的值是被保存进了Block的结构体实例中，也就是Block自身中。

这么来就清晰了很多，自动变量是以值传递方式传递到Block的构造函数里面去的。Block只捕获Block中会用到的变量。由于只捕获了自动变量的值，并非内存地址，所以Block内部不能改变自动变量的值。


## 修改自动变量
截获变量有两种方法__block和指针法（不过__block法归根结底，其实也是操作指针）。
这里描述一下指针法：
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
直接操作指针去进行截获，不过一般来讲，这种方法多用于C语言数组的时候。使用OC的时候多数是使用__block。


这里写一个__block的捕获代码，使用刚才的方法再来一次：
#### 1.普通非对象的变量
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
我们可以发现这里多了两个结构体
```C++
struct __Block_byref_i_0 {
  void *__isa;
__Block_byref_i_0 *__forwarding;
 int __flags;
 int __size;
 int i;
};
```
这个实例内，包含了 **__isa** 指针、一个标志位 **__flags** 、一个记录大小的 **__size** 。最最重要的，多了一个 **__forwarding** 指针和 val 变量.
这里长话短说，出来了一个新的 **__forwarding**指针,指向了结构体实例本身在内存的地址。

block通过指针的持续传递，将使用的自动变量值保存到了block的结构体实例中。在block体内修改 **__block0**变量，通过一系列指针指向关系，最终指向了__Block_byref_age_0结构体内与局部变量同名同类型的那个成员，并成功修改变量值。

在栈中， **__forwarding**指向了自己本身，但是如果复制到了堆上，**__forwarding**就指向复制到堆上的block，而堆上的block中的 **__forwarding**这时候指向了自己。
![](https://ws3.sinaimg.cn/large/006tNbRwly1fx781cvpm4j31g20hq41e.jpg)

#### 2.对象的变量

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
在转换出来的源码中，我们也可以看到，Block捕获了__block，并且强引用了，因为在__Block_byref_block_obj_0结构体中，有一个变量是id block_obj，这个默认也是带__strong所有权修饰符的。

根据打印出来的结果来看，ARC环境下，Block捕获外部对象变量，是都会copy一份的，地址都不同。只不过带有__block修饰符的变量会被捕获到Block内部持有。

在ARC中，对于声明为__block的外部对象，在block内部会进行retain，以至于在block环境内能安全的引用外部对象。

## 实例变量的问题
之前一直没有想到过一个问题：

我们知道不应该在block中使用实例变量，是因为会发生循环引用；那为什么会发生循环引用呢？
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
下面是block的layout中的第四排的函数调用方法。
```C++
//block的函数方法（也就是方法layout中第四行的那个）
static void __MyObject__inits_block_func_0(struct __MyObject__inits_block_impl_0 *__cself) {
    MyObject *const __strong self = __cself->self; // bound by copy
    //这里是通过self的地址，那倒全局变量的偏移去获取实例变量的地址
    (*(NSUInteger *)((char *)self + OBJC_IVAR_$_MyObject$_BRInteger)) = 5;
    (*(NSString *__strong *)((char *)self + OBJC_IVAR_$_MyObject$_BRString)) = (NSString *)&__NSConstantStringImpl__var_folders_m1_05zb_zbd1g1f8k27nc6yn_th0000gn_T_main_e9db32_mi_0;
}
```
通过这里，我们其实也能发现，这里是通过self的偏移去获取实例变量的地址，也是和self息息相关的。

如果这个还不会证明实例变量中的self的作用的话，我们接着往下看；
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
在这个方法里，我们可以发现，在block当中，其实也引用到MyObject，是一个强引用的self！而block的构造函数中也多次引用了self。

我们如果了解过property的话，也会知道实例变量是在编译期就确定地址了。内部实现的全局变量就代表了地址的offset。



## 简单结论
我们可以把block看做一个对象，一个带参的函数，带有自动变量值的匿名函数。


[Blocks Programming Topics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Blocks/Articles/00_Introduction.html#//apple_ref/doc/uid/TP40007502-CH1-SW1)     
[Working with Blocks](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/WorkingwithBlocks/WorkingwithBlocks.html)        
[fuckingblocksyntax.com](http://fuckingblocksyntax.com/)
