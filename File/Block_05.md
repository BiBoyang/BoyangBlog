

> * 原作于：2018-01-02        
> * GitHub Repo：[BoyangBlog](https://github.com/BiBoyang/BoyangBlog)

这里将通过几道面试题来扩展知识。
这几道题有几个取自[sunnyxx](http://blog.sunnyxx.com/)。

# Question1 下面代码运行结果是什么？?
```C++
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int d = 1000; // 全局变量
static int e = 10000; // 静态全局变量

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
        
        int a = 10; // 局部变量
        static int b = 100; // 静态局部变量
        __block int c = 1000;
        void (^block)(void) = ^{
            NSLog(@"Block中--\n a = %d \n b = %d\n c = %d \n d = %d \n e = %d",a,b,c,d,e);
         };
         a = 20;
         b = 200;
         c = 2000;
         d = 20000;
         e = 200000;
         NSLog(@"Block上--\n a = %d \n b = %d\n c = %d \n d = %d \n e = %d",a,b,c,d,e);
         block();
         NSLog(@"Block下--\n a = %d \n b = %d\n c = %d \n d = %d \n e = %d",a,b,c,d,e);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
```
答案是
```C++
2019-04-04 04:50:58.508341+0800 Block_Test[19213:1138920] Block上--
 a = 20 
 b = 200
 c = 2000 
 d = 20000 
 e = 200000
2019-04-04 04:50:58.509229+0800 Block_Test[19213:1138920] Block中--
 a = 10 
 b = 200
 c = 2000 
 d = 20000 
 e = 200000
2019-04-04 04:50:58.509395+0800 Block_Test[19213:1138920] Block下--
 a = 20 
 b = 200
 c = 2000 
 d = 20000 
 e = 200000
```
解答：
* block在捕获普通的局部变量时是捕获的a的值，后面无论怎么修改a的值都不会影响block之前捕获到的值，所以a的值不变。
* block在捕获静态局部变量时是捕获的b的地址，block里面是通过地址找到b并获取它的值。所以b的值发生了改变。
* __block是将外部变量包装成了一个对象并将c存在这个对象中，实际上block外面的c的地址也是指向这个对象中存储的c的，而block底层是有一个指针指向这个对象的，所以当外部更改c时，block里面通过指针找到这个对象进而找到c，然后获取到c的值，所以c发生了变化。
* 全局变量在哪里都可以访问，block并不会捕获全局变量，所以无论哪里更改d和e，block里面获取到的都是最新的值。

# Question2 下面代码的运行结果是什么？
```C++
- (void)test{
  
    __block Foo *foo = [[Foo alloc] init];
    foo.fooNum = 20;
    __weak Foo *weakFoo = foo;
    self.block = ^{
        NSLog(@"block中-上 fooNum = %d",weakFoo.fooNum);
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@"block中-下 fooNum = %d",weakFoo.fooNum);
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        self.block();
    });
    
    [NSThread sleepForTimeInterval:0.2f];
    NSLog(@"end");
}
```
结果是
```C++
block中-上 fooNum = 20
end
block中-下 fooNum = 0
```
weakFoo是一个弱指针，所以self.block对person是弱引用。
然后在并发队列中通过异步函数添加一个任务来执行self.block();，所以是开启了一个子线程来执行这个任务，此时打印fooNum值是20，然后子线程开始睡眠1秒钟；与此同时主线程也睡眠0.2秒。
而由于foo是一个局部变量，而且self.block对它也是弱引用，所以在test函数执行完后foo对象就被释放了。再过0.8秒钟，子线程结束睡眠，此时weakFoo所指向的对象已经变成了nil，所以打印的fooNum是0。

* 接着问：如果下面的`[NSThread sleepForTimeInterval:0.2f];`改为`[NSThread sleepForTimeInterval:2.0f];`呢？
 
 结果是
```C++
block中-上 fooNum = 20
end
block中-下 fooNum = 20
```
因为子线程睡眠结束时主线程还在睡眠睡眠，也就是test方法还没执行完，那person对象就还存在，所以子线程睡眠前后打印的fooNum都是20。

* 换个方式问：如果在block内部加上`__strong Foo *strongFoo = weakFoo;`,并改为打印strong.fooNum呢？

结果还是：
```C++
block中-上 fooNum = 20
end
block中-下 fooNum = 20
```
__strong的作用就是保证在block中的代码块在执行的过程中，它所修饰的对象不会被释放，即便block外面已经没有任何强指针指向这个对象了，这个对象也不会立马释放，而是等到block执行结束后再释放。所以在实际开发过程中__weak和__strong最好是一起使用，避免出现block运行过程中其弱引用的对象被释放。

# Questime3 下面的代码会发生什么？
```C++
- (void)test{
    self.age = 20;
    self.block = ^{
      NSLog(@"%d",self.age);
    };
    
    self.block();
}
```
答：会发生循环引用。
因为self通过一个强指针指向了block，而block内部又捕获了self而且用强指针指向self，所以self和block互相强引用对方而造成循环引用。
如果要解决的话很简单，加一个`__weak typeof(self) weakSelf = self;`就好。

* 那如果去掉`self.block();`呢？
    
答： 一样会引用，一样会发生循环引用。

* 那如果把`NSLog(@"%d",self.age);`改为`NSLog(@"%d",_age);`呢？
 
 答：还是会发生循环引用。因为_age，实际上就是self->age。

# Question4 下面会发生循环引用吗？
```C++
[UIView animateWithDuration:1.0f animations:^{
       NSLog(@"%d",self.age);
}];
dispatch_sync(dispatch_get_global_queue(0, 0), ^{
       NSLog(@"%d",self.age);
});
```
答：不会。这里的block实际上是这个函数的一部分，是参数。虽然block强引用了self，但是self并没有强引用block，所以没事。


# Question5 如何在禁止直接调用block的情况下继续使用block?
```C++
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
## 1.别的方法直接调用
```C++
- (void)blockProblemAnswer0:(void(^)(void))block {
    //动画方法 
    [UIView animateWithDuration:0 animations:block];   
    //主线程
    dispatch_async(dispatch_get_main_queue(), block);
}
```
这里两个都是直接调用了原装block的方法。


## 2.NSOperation
```C++
- (void)blockProblemAnswer1:(void(^)(void))block {
    [[NSBlockOperation blockOperationWithBlock:block]start];
}
```
直接使用NSOperation的方法去调用。注意，这个方法是在主线程上执行的。

## 3.NSInvocation
```C++
- (void)blockProblemAnswer2:(void(^)(void))block {
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@?"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation invokeWithTarget:block];
}
```
NSMethodSignature是方法签名，封装了一个方法的返回类型和参数类型，只有返回类型和参数类型。

> * **@?** 代表了这个是一个block。

NSInvocation对象包含Objective-C消息的所有元素：目标、选择器、参数和返回值。这些元素都可以直接设置，当NSncOcObjt对象被调度时，返回值自动设置。

NSInvocation对象可以重复地分配到不同的目标；它的参数可以在分派之间进行修改，以获得不同的结果；甚至它的选择器也可以改变为具有相同方法签名（参数和返回类型）的另一个。这种灵活性使得NSInvocation对于使用许多参数和变体重复消息非常有用；您不必为每个消息重新键入稍微不同的表达式，而是每次在将NSInvocation对象分派到新目标之前根据需要修改NSInvocation对象。

## 4.invoke方法
```C++
- (void)blockProblemAnswer3:(void(^)(void))block {
    [block invoke];
}
```
我们通过打印，可以获取到block的继承线。

```C++
 -> __NSMallocBlock__ -> __NSMallocBlock -> NSBlock -> NSObject
```
然后我们查找 **NSBlock**的方法
```C++
(lldb) po [NSBlock instanceMethods]
<__NSArrayI 0x600003265b00>(
- (id)copy,
- (id)copyWithZone:({_NSZone=} *)arg0 ,
- (void)invoke,
- (void)performAfterDelay:(double)arg0 
)
```
我们发现了一个invoke方法，这个方法实际上也是来自 **NSInvocation**。该方法是将接收方的消息（带参数）发送到目标并设置返回值。

注意：**这个方法是NSInvocation的方法，不是Block结构体中的invoke方法。**

## 5.block的struct方法
```C++
    void *pBlock = (__bridge void*)block;
    void (*invoke)(void *,...) = *((void **)pBlock + 2);
    invoke(pBlock);
```
开始 `(__bridge void*)block`将block转成指向block结构体第一位的指针。然后去计算偏移量。

然后观察block的内存布局
```C++
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

## 6.__attribute__((cleanup))方法
```C++
static void blockCleanUp(__strong void(^*block)(void)){
    (*block)();
}
- (void)blockProblemAnswer5:(void(^)(void))block {
    __strong void(^cleaner)(void) __attribute ((cleanup(blockCleanUp),unused)) = block;
}
```
这里可以查看[黑魔法__attribute__((cleanup))](http://blog.sunnyxx.com/2014/09/15/objc-attribute-cleanup/)

## 7.汇编方法
```C++
- (void)blockProblemAnswer6:(void(^)(void))block {
    asm("movq -0x18(%rbp), %rdi");
    asm("callq *0x10(%rax)");
}
```
我们给一个block打断点，并在lldb中输入dis查看汇编代码。
```C++
->  0x1088c8d1e <+62>:  movq   -0x18(%rbp), %rax
    0x1088c8d22 <+66>:  movq   %rax, %rsi
    0x1088c8d25 <+69>:  movq   %rsi, %rdi
    0x1088c8d28 <+72>:  callq  *0x10(%rax)
```
注意，一定要写第一行。

不写第一行的话，如果没有拦截外部变量的话还是没问题的，但是一旦拦截到了外部变量，就会无法确定偏移位置而崩溃。

# Question6 看下列代码结果
```C++
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

typedef void (^ByBlock)(void);
@interface TestObj : NSObject
@property (nonatomic, copy) ByBlock block;
@end
@implementation TestObj
- (void)testMethod {
    if (self.block) {
        self.block();
    }
    NSLog(@"%@", self);
}
@end

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        __block TestObj *testObj = [TestObj new];
        testObj.block = ^{
            testObj = nil;
            
        };
        [testObj testMethod];
        
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

```
答：
会发生崩溃。野指针会出现问题



# Question7 HookBlock
![](https://wx3.sinaimg.cn/mw690/51530583ly1fsatleo2zmj213u10caiu.jpg)
我才疏学浅，只对第一第二个有实现，第三个问题有思路但是确实没写出来（😌）。

## 第一题
我最开始的思路是这样的，将block的结构替换实现出来，作为中间体用来暂存方法指针。然后同样实现替换block的结构体，用来装载。
```C++
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
警告我们这两个方法并不兼容。实际上，这两个结构体里的方法名并不相同，甚至个数不同都可以，但是一定要保证前四个成员的类型是对应了;前四个成员是存储block内部数据的关键。
在四个成员下边接着又其他成员也是无所谓的。
```C++
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
```C++
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
```C++
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
```C++
2018-11-19 17:12:16.599362+0800 BlockBlogTest[64408:32771276] 白日依山尽 
2018-11-19 17:12:16.599603+0800 BlockBlogTest[64408:32771276] 黄河入海流
```
## 第二题
这里我参考了网上的一些讨论，并结合原有的思路，回答如下
```C++
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

```C++
2018-11-19 17:12:16.599730+0800 BlockBlogTest[64408:32771276] 1,biboyang
2018-11-19 17:12:16.599841+0800 BlockBlogTest[64408:32771276] bby
```

## 第三题
第三题说实话我还没有实现出来，但是在北京参加swift大会的时候，和冬瓜讨论过这个问题。
我当时的思路是在把block提出一个父类，然后在去统一修改。但是后来冬瓜介绍了fishhook框架，我的思路就变了。
在ARC中我们使用的都是堆block，但是创建的时候是栈block，它会经过一个copy的过程，将栈block转换成堆block，中间会有**objc_retainBlock->_Block_copy->_Block_copy_internal**方法链。我们可以hook这几个方法，去修改。


[demo地址](https://github.com/BiBoyang/BlogDemo/tree/master/BlockBlogTest)