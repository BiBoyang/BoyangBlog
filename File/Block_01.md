

> * 原作于：2018-01-02        
> * GitHub Repo：[BoyangBlog](https://github.com/BiBoyang/BoyangBlog)



# 1. 简单概述

 block 是 C 语言的扩充功能，我们可以认为它是 **带有自动变量的匿名函数**，同时也是一个**对象**。

block 是一个匿名的 inline 代码集合，有如下特点：
 * 参数列表，就像一个函数（看起来是个函数，执行起来像是一个函数）；
 * 是一个对象；
 * 有声明的返回类型。


# 2. block怎么写
最简单的写法。

```C++
    int (^DefaultBlock1)(int) = ^int (int a) {
        return a + 1;
    };
    DefaultBlock1(1);
```

升级版。

```C++
// 利用 typedef 声明block
typedef return_type (^BlockTypeName)(var_type);

// 作属性
@property (nonatomic, copy ,nullable) BlockTypeName blockName;

// 作方法参数
- (void)requestForSomething:(Model)model handle:(BlockTypeName)handle;
```

# 3. block的实现

在LLVM的文件中，我找到了一份文档，[Block_private.h](https://github.com/llvm/llvm-project/blob/main/compiler-rt/lib/BlocksRuntime/Block_private.h)，这里可以查看到block的实现情况

* 注：实际上真实的代码结构和使用 clang 指令转换过来的代码，是有可能不一样的。

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
结构如图所示：
![](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_1.png)

里面的 invoke 就是指向具体实现的函数指针，当 block 被调用的时候，程序最终会跳转到这个函数指针指向的代码区。

而 **Block_descriptor** 里面最重要的就是 **copy** 函数和 **dispose** 函数，从命名上可以推断出，copy 函数是用来**捕获变量并持有引用**，而 dispose 函数是用来**释放捕获的变量**。函数捕获的变量会存储在结构体 **Block_layout** 的后面，在 invoke 函数执行前全部读出。

不过光看文档并不直观。我们使用 **clang -rewrite-objc** 将一份 block 代码进行编译转换，将得到一份C++代码。刨除其他无用的代码：
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
先看最直接的 **__block_impl** 代码，

```C++
struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};
```
这是一个结构体，里面的元素分别是

> * isa：    
        指向所属类的指针，也就是 block 的类型
> * flags    
        标志变量，在实现 block 的内部操作时会用到
> * Reserved    
        保留变量
> * FuncPtr    
        block 执行时调用的函数指针


接着, **__main_block_impl_0** 因为包含了 __block_impl ，我们可以将它打开,直接看成

```C++
__main_block_impl_0{
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
    struct __main_block_desc_0 *Desc;
}
```
通过观察它，我们可以将 block 理解为，一个对象，内部包含一个函数。

# 4. block的类型

我们常见的block是有三种：

 * __NSGlobalBlock
 * __NSStackBlock
 * __NSMallocBlock

比如说

```C++
void (^block)(void) = ^{
    NSLog(@"biboyang");
};
block();
```

或者

```C++
static int age = 10;
    void(^block)(void) = ^{
        NSLog(@"Hello, World! %d",age);
    };
block();
```

像是这种，没有对外捕获变量的，就是 GlobaBlock 。


而我们在写一个捕获变量的。

```C++
    int b = 10;
    void(^block2)(void) = ^{
        NSLog(@"Hello, World! %d",b);
    };
    block2();
```

这种 block，在 MRC 中，是 StackBlock 。在 ARC 中，因为编译器做了优化，自动进行了 copy ，这种就是 MallocBlock 了。
虽然在 ARC 中 strong 和 copy 均可正确管理 Block 内存，但 Apple 官方推荐使用 copy 以明确语义，同时兼容 MRC 历史代码（但是现在已经很难找到使用 MRC 的项目了）。

做这种优化的原因很好理解：

如果 StackBlock 访问了一个自动变量，因为自己是存在栈上的，所以变量也就会被保存在栈上。但是因为栈上的数据是由系统自动进行管理的，随时都有可能被回收，非常容易造成野指针的问题。

那该如何解决呢？复制到堆上就好了！

ARC 机制也确实这么做的。它会自动将栈上的 block 复制到堆上，所以，ARC 下的 block 的属性关键词其实使用 strong 和 copy 都不会有问题，不过为了习惯，还是使用 copy 为好。


| Blcok 的类 | 副本源的配置存储域 | 复制效果 |
| --- | --- | --- |
| __NSStackBlock | 栈 | 堆 |
| __NSGlobalBlock | 程序的数据区域 | 无用 |
| __NSMallocBlock | 堆 | 引用计数增加 |

系统默认调用 copy 方法把 block 复制的四种情况

1. 手动调用 copy
2. block 是函数的返回值
3. block 被强引用，block 被赋值给 __strong 或者 id 类型
4. 调用系统 API 入参中含有 usingBlcok 的 Cocoa 方法或者 GCD 的相关 API

ARC 环境下，一旦 block 赋值就会触发 copy，block 就会 copy 到堆上，block也就会变成 __NSMallocBlock 。当然，如果刻意的去写（没有实际用处），ARC 环境下也是存在 __NSStackBlock 的，这种情况下，block 就在栈上。


# 从报错看内存

如果我们把 block 设置为 nil ，然后去调用，会发生什么？

```C++
void (^block)(void) = nil;
block();
```

当我们运行的时候，它会崩溃，报错信息为 **Thread 1: EXC_BAD_ACCESS (code=1, address=0x10)**。

![置为nil的block](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_5.png)

我们可以发现，当把 block 置为 nil 的时候，第四行的函数指针，被置为 NULL ，注意，这里是 NULL 而不是 nil 。

我们给一个对象发送 nil 消息是没有问题的，但是给如果是 NULL 就会发生崩溃。

* nil：指向oc中对象的空指针
* Nil：指向oc中类的空指针
* NULL：指向其他类型的空指针，如一个c类型的内存指针
* NSNull：在集合对象中，表示空值的对象
* 若obj为 nil:[obj message] 将返回NO,而不是NSException
* 若obj为 NSNull:[obj message] 将抛出异常NSException

它直接访问到了函数指针，因为前三位分别是 void、int、int，大小分别是 8、4、4，加一块就为 16 ，所以在 64 位中，就表示出 0x10 地址的崩溃。

```C
// Block_layout 内存布局（64位系统）：
// isa (8字节) | flags (4) | reserved (4) | invoke (8) | descriptor (8) | variables...
// 访问 invoke 的地址为 Block_layout 起始地址 + 16 字节（0x10）
```


如果是在 32 位的系统中，void 的大小是 4，崩溃的地址应该就是 0x0c。




## 引用


[Blocks Programming Topics - Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Blocks/Articles/00_Introduction.html#//apple_ref/doc/uid/TP40007502-CH1-SW1)     
[Working with Blocks](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/WorkingwithBlocks/WorkingwithBlocks.html)        
[fuckingblocksyntax.com](http://fuckingblocksyntax.com/)
