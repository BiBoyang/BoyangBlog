# block（四）：修改block的实现

![](https://raw.githubusercontent.com/BiBoyang/Study/master/Image/block_4.png)

这里将通过几道面试题来扩展知识。
这几道题取自[sunnyxx](http://blog.sunnyxx.com/)。
## Question1 如何在禁止直接调用block的情况下继续使用block?
```
- (void)blockProblem {
    __block int a = 0;
    void (^block)(void) = ^{
        self.string = @"retain";
        NSLog(@"biboyang");
        NSLog(@"biboyang%d",a);
    };
//    block();//禁止
    
}
```
我们可以通过以下几种方式来实现
#### 1.别的方法直接调用
```
- (void)blockProblemAnswer0:(void(^)(void))block {
    //动画方法 
    [UIView animateWithDuration:0 animations:block];   
    //
    dispatch_async(dispatch_get_main_queue(), block);
}
```
这里两个都是直接调用了原装block的方法。


#### 2.NSOperation
```
- (void)blockProblemAnswer1:(void(^)(void))block {
    [[NSBlockOperation blockOperationWithBlock:block]start];
}
```
直接使用NSOperation的方法去调用。注意，这个方法是在主线程上执行的。

#### 3.NSInvocation
```
- (void)blockProblemAnswer2:(void(^)(void))block {
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@?"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation invokeWithTarget:block];
}
```
NSMethodSignature是方法签名，封装了一个方法的返回类型和参数类型，只有返回类型和参数类型。

> **@?**代表了这个是一个block。

NSInvocation对象包含Objective-C消息的所有元素：目标、选择器、参数和返回值。这些元素都可以直接设置，当NSncOcObjt对象被调度时，返回值自动设置。
NSInvocation对象可以重复地分配到不同的目标；它的参数可以在分派之间进行修改，以获得不同的结果；甚至它的选择器也可以改变为具有相同方法签名（参数和返回类型）的另一个。这种灵活性使得NSInvocation对于使用许多参数和变体重复消息非常有用；您不必为每个消息重新键入稍微不同的表达式，而是每次在将NSInvocation对象分派到新目标之前根据需要修改NSInvocation对象。

#### 4.invoke方法
```
- (void)blockProblemAnswer3:(void(^)(void))block {
    [block invoke];
}
```
我们通过打印，可以获取到block的继承线。
```
 -> __NSMallocBlock__ -> __NSMallocBlock -> NSBlock -> NSObject
```
然后我们查找 **NSBlock**的方法
```
(lldb) po [NSBlock instanceMethods]
<__NSArrayI 0x600003265b00>(
- (id)copy,
- (id)copyWithZone:({_NSZone=} *)arg0 ,
- (void)invoke,
- (void)performAfterDelay:(double)arg0 
)
```
我们发现了一个invoke方法，这个方法实际上也是来自 **NSInvocation**。
该方法是将接收方的消息（带参数）发送到目标并设置返回值。
注意：这个方法是NSInvocation的方法，不是Block结构体中的invoke方法。

#### 5.block的struct方法
```
    void *pBlock = (__bridge void*)block;
    void (*invoke)(void *,...) = *((void **)pBlock + 2);
    invoke(pBlock);
```
开始 `(__bridge void*)block`将block转成指向block结构体第一位的指针。然后去计算偏移量。
然后观察block的内存布局
```
struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor *descriptor;
    /* Imported variables. */
};
```
在64位下，一个void指针占了8byte。而int占据4位，则flag和reserved一共占据了8位，加一块是16位。
我们知道，一个 `void*`占据了8位， ``(void **)pBlock``代表了本身的8位地址长度。+2表示添加了两倍的8位长度，也就是16位。到达了 `void (*invoke)`方法。
然后我们再调用 `void (*invoke)(void *,...)`,这里是block的函数指针，直接去调用就好。

#### 6.__attribute__((cleanup))方法
```
static void blockCleanUp(__strong void(^*block)(void)){
    (*block)();
}
- (void)blockProblemAnswer5:(void(^)(void))block {
    
    __strong void(^cleaner)(void) __attribute ((cleanup(blockCleanUp),unused)) = block;
}
```
这里可以查看[黑魔法__attribute__((cleanup))](http://blog.sunnyxx.com/2014/09/15/objc-attribute-cleanup/)

#### 7.汇编方法
```
- (void)blockProblemAnswer6:(void(^)(void))block {
    asm("movq -0x18(%rbp), %rdi");
    asm("callq *0x10(%rax)");
}
```
我们给一个block打断点，并在lldb中输入dis查看汇编代码。
```
->  0x1088c8d1e <+62>:  movq   -0x18(%rbp), %rax
    0x1088c8d22 <+66>:  movq   %rax, %rsi
    0x1088c8d25 <+69>:  movq   %rsi, %rdi
    0x1088c8d28 <+72>:  callq  *0x10(%rax)
```
注意，一定要写第一行。
不写第一行的话，如果没有拦截外部变量的话还是没问题的，但是一旦拦截到了外部变量，就会无法确定偏移位置而崩溃。

## HookBlock
![](https://wx3.sinaimg.cn/mw690/51530583ly1fsatleo2zmj213u10caiu.jpg)
我才疏学浅，只对第一第二个有实现，第三个问题有思路但是确实没写出来（😌）。

#### 第一题
我最开始的思路是这样的，将block的结构替换实现出来，作为中间体用来暂存方法指针。然后同样实现替换block的结构体，用来装载。
```
//中间体
typedef struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
}__block_impl;

//接受体
typedef struct __block_impl_replace {
    void *isa_replace;
    int Flags_replace;
    int Reserved_replace;
    void *FuncPtr_replace;
}__block_impl_replace;


//替换方法
void hookBlockMethod() {
    NSLog(@"黄河入海流");
}

void HookBlockToPrintHelloWorld(id block) {
    __block_impl_replace *ptr = (__bridge __block_impl *)block;
    ptr->FuncPtr_replace = &hookBlockMethod;
}
```
注意，结构体里的方法名不比和系统block中的方法名相同，这里这么写只不过是为了标明。
这里事实上是会触发一个警告 ``Incompatible pointer types initializing '__block_impl_replace *' (aka 'struct __block_impl_replace *') with an expression of type '__block_impl *' (aka 'struct __block_impl *')``
警告我们这两个方法并不兼容。实际上，这两个结构体里的方法名不比相同，甚至个数不同都可以，但是一定要保证前四个成员的类型是对应了;前四个成员是存储block内部数据的关键。
在四个成员下边接着又其他成员也是无所谓的。
```
typedef struct __block_impl_replace {
    void *isa_replace;
    int Flags_replace;
    int Reserved_replace;
    void *FuncPtr_replace;
    void *aaa;
    void *bbb;
    void *ccc;
}__block_impl_replace;
```
比如这种方式，实际上方法依然成立。
当然，这种方式也是可以优化的。比如说我们就可以吧中间结构体和替换block结合。
比如下面的这个就是优化之后的结果。
```
typedef struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
}__block_impl;


void OriginalBlock (id Or_Block) {
    void(^block)(void) = Or_Block;
    block();
}

void HookBlockToPrintHelloWorld(id block) {
    __block_impl *ptr = (__bridge __block_impl *)block;
    ptr->FuncPtr = &hookBlockMethod;
}
------------------
------------------
    void (^block)(void) = ^void() {
        NSLog(@"白日依山尽 ");
    };
    HookBlockToPrintHelloWorld(block);
    block();
```
  
这里我们就可以打印出来 ``黄河入海流``了。
但是，我们如果想要原本的方法也也打印出来该怎么处理呢？
方法很简单
```
void OriginalBlock (id Or_Block) {
    void(^block)(void) = Or_Block;
    block();
}
void HookBlockToPrintHelloWorld(id block) {
    __block_impl *ptr = (__bridge __block_impl *)block;
    OriginalBlock(block);
    ptr->FuncPtr = &hookBlockMethod;
}
```
保留原有block，并在该方法中执行原有的block方法。
我们就可以实现如下了
```
2018-11-19 17:12:16.599362+0800 BlockBlogTest[64408:32771276] 白日依山尽 
2018-11-19 17:12:16.599603+0800 BlockBlogTest[64408:32771276] 黄河入海流
```
#### 第二题
这里我参考了网上的一些讨论，并结合原有的思路，回答如下
```
static void (*orig_func)(void *v ,int i, NSString *str);

void hookFunc_2(void *v ,int i, NSString *str) {
    NSLog(@"%d,%@", i, str);
    orig_func(v,i,str);
}

void HookBlockToPrintArguments(id block) {
    __block_impl *ptr = (__bridge __block_impl *)block;
    orig_func = ptr->FuncPtr;
    ptr->FuncPtr = &hookFunc_2;
}
----------------
----------------
    void (^hookBlock)(int i,NSString *str) = ^void(int i,NSString *str){
        NSLog(@"bby");
    };
    HookBlockToPrintArguments(hookBlock);
    hookBlock(1,@"biboyang");

```
这样就可以打印出来
```
2018-11-19 17:12:16.599730+0800 BlockBlogTest[64408:32771276] 1,biboyang
2018-11-19 17:12:16.599841+0800 BlockBlogTest[64408:32771276] bby
```

#### 第三题
第三题说实话我还没有实现出来，但是在北京参加swift大会的时候，和冬瓜讨论过这个问题。
我当时的思路是在把block提出一个父类，然后在去统一修改。
但是后来冬瓜介绍了fishhook框架，我的思路就变了。
在ARC中我们使用的都是堆block，但是创建的时候是栈block，它会经过一个copy的过程，将栈block转换成堆block，中间会有objc_retainBlock->_Block_copy->_Block_copy_internal方法链。我们可以hook这几个方法，去修改。


[demo地址](https://github.com/BiBoyang/BBY_TESTDEMO/blob/master/BlockBlogTest.zip)