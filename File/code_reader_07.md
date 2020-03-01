#### 1.MLeaksFinder.h
```C++
#import "NSObject+MemoryLeak.h"

//#define MEMORY_LEAKS_FINDER_ENABLED 0

#ifdef MEMORY_LEAKS_FINDER_ENABLED

//_INTERNAL_MLF_ENABLED 宏用来控制 MLLeaksFinder库
//什么时候开启检测，可以自定义这个时机，默认则是在DEBUG模式下会启动，RELEASE模式下不启动
//它是通过预编译来实现的
#define _INTERNAL_MLF_ENABLED MEMORY_LEAKS_FINDER_ENABLED
#else
#define _INTERNAL_MLF_ENABLED DEBUG
#endif

//_INTERNAL_MLF_RC_ENABLED 宏用来控制 是否开启循环引用的检测
#define MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED 0

#ifdef MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED
#define _INTERNAL_MLF_RC_ENABLED MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED
//COCOAPODS 因为MLeaksFinder引用了第三库(FBRetainCycleDetector)用来检查循环引用，所以必须是当前项目中使用了COCOAPODS，才能使用这个功能。
#elif COCOAPODS
#define _INTERNAL_MLF_RC_ENABLED COCOAPODS
#endif
```
_INTERNAL_MLF_ENABLED 作为条件编译的表达式判断条件，用于控制MLeaksFinder的其他文件是否参与编译，在发布环境下，_INTERNAL_MLF_ENABLED为0，那么相当于该库的功能关闭。如果需要无论是调试环境还是发布环境都关闭代码，可以写注释
```C++
#define MEMORY_LEAKS_FINDER_ENABLED 0
```
_INTERNAL_MLF_RC_ENABLED表示是否导入**FBAssociationManager**来监测循环引用。默认不开启

#### 2.MLeaksMessenger
这个文件主要负责展示内存泄露。
MLeaksMessenger.h中有两个方法

```C++
+ (void)alertWithTitle:(NSString *)title message:(NSString *)message;
+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle;
```
我们查看.m文件可以发现，后一个方法实际上是第一个方法的**Designated Initializer**，我们可以称之为**全能初始化方法**
```C++
#import "MLeaksMessenger.h"
static __weak UIAlertView *alertView;
@implementation MLeaksMessenger
+ (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    [self alertWithTitle:title message:message delegate:nil additionalButtonTitle:nil];
}
+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle {
    [alertView dismissWithClickedButtonIndex:0 animated:NO];
    UIAlertView *alertViewTemp = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:delegate
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:additionalButtonTitle, nil];
    [alertViewTemp show];
    alertView = alertViewTemp;
    
    NSLog(@"%@: %@", title, message);
}
@end
```
> 这里运用了一个技巧：使用静态全局变量用__weak修饰变量。
 **static __weak UIAlertView *alertView;**  
     
第一次调用 **[alertView dismissWithClickedButtonIndex:0 animated:NO];** 这个方法的时候，alertView为nil,  **[alertView dismissWithClickedButtonIndex:0 animated:NO]** 不产生任何操作，只是一个弹框。
        
再次调用这个方法(即点击查看retain cycle)，会通过alertView来dimiss现有的弹框，再显示新的弹框。所以alertView是记录当前显示的内存泄漏的弹框。同时设置__weak修饰让这个全局变量弱引用。一旦弹框消失，自动设置为nil.

### 3.MLeakedObjectProxy
这个文件是检测内存泄露的核心文件
对外提供了两个方法：
```C++
+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs;
+ (void)addLeakedObject:(id)object;
```
第一个方法用来判断ptrs（NSSet类型）中是否有泄漏的对象，如果有返回True       
第二个方法是将对象加入泄漏对象的集合，同时调用MLeaksMessenger的弹窗方法
无论是判断还是比较，始终需要一个集合来保存所有泄漏对象。自然而然检查MLeakedObjectProxy。               
全局static变量**static NSMutableSet** * **leakedObjectPtrs;** 就是用来做比较的对象。       
上面两个方法都只在 NSObject的category的 **assertNotDealloc** 中调用。
让我们看一下.m文件中方法的实现：
```C++
//用来检查当前泄漏对象是否已经添加到泄漏对象集合中，如果是，就不再添加也不再提示开发者
+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    /*
     #define NSAssert(condition, desc)
     condition是一个表达式，如果表达式为false，那么就抛出一个异常，并且在日志中输出desc内容。
     desc可以忽略不写。
     表达式为true时，不执行任何操作。
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        leakedObjectPtrs = [[NSMutableSet alloc] init];
    });
    
    if (!ptrs.count) {
        return NO;
    }
    //intersectsSet判断两个集合的交集是否至少存在一个元素
    //防止 addLeakedObject多次被调用
    if ([leakedObjectPtrs intersectsSet:ptrs]) {
        return YES;
    } else {
        return NO;
    }
}
+ (void)addLeakedObject:(id)object {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    //创建用于检查循环引用的objectProxy对象
    MLeakedObjectProxy *proxy = [[MLeakedObjectProxy alloc] init];
    proxy.object = object;
    proxy.objectPtr = @((uintptr_t)object);
    proxy.viewStack = [object viewStack];
    static const void *const kLeakedObjectProxyKey = &kLeakedObjectProxyKey;
    objc_setAssociatedObject(object, kLeakedObjectProxyKey, proxy, OBJC_ASSOCIATION_RETAIN);
    //将自己封装成 MLeakedObjectProxy对象加入leakedObjectPtrs中
    [leakedObjectPtrs addObject:proxy.objectPtr];
    
#if _INTERNAL_MLF_RC_ENABLED
    //带有循环引用检查功能的提示框
    [MLeaksMessenger alertWithTitle:@"Memory Leak"
                            message:[NSString stringWithFormat:@"%@", proxy.viewStack]
                           delegate:proxy
              additionalButtonTitle:@"Retain Cycle"];
#else
    //普通提示框
    [MLeaksMessenger alertWithTitle:@"Memory Leak"
                            message:[NSString stringWithFormat:@"%@", proxy.viewStack]];
#endif

- (void)dealloc {
    NSNumber *objectPtr = _objectPtr;
    NSArray *viewStack = _viewStack;
    dispatch_async(dispatch_get_main_queue(), ^{
        [leakedObjectPtrs removeObject:objectPtr];
        [MLeaksMessenger alertWithTitle:@"Object Deallocated"
                                message:[NSString stringWithFormat:@"%@", viewStack]];
    });
}
}
```
在上述两个方法的实现中，我们发现了几个要点
> *  使用这两个方法必须要在主线程中使用
> *  待检查的对象，必须要检查是否已经被记录，以防止重复添加，造成循环

展示循环引用的核心代码在下面：
```C++
#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (!buttonIndex) {
        return;
    }
    
    id object = self.object;
    if (!object) {
        return;
    }
    
#if _INTERNAL_MLF_RC_ENABLED
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
        [detector addCandidate:self.object];
        NSSet *retainCycles = [detector findRetainCyclesWithMaxCycleLength:20];
        
        BOOL hasFound = NO;
        //retainCycles中是找到的所有循环引用的链,所形成的循环引用树
        for (NSArray *retainCycle in retainCycles) {
            NSInteger index = 0;
            for (FBObjectiveCGraphElement *element in retainCycle) {
                //找到当前内存泄漏对象所在的循环引用的链
                if (element.object == object) {
                    //把当前对象调整到第一个的位置，方便查看
                    NSArray *shiftedRetainCycle = [self shiftArray:retainCycle toIndex:index];
                    //回到主线程展示
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MLeaksMessenger alertWithTitle:@"Retain Cycle"
                                                message:[NSString stringWithFormat:@"%@", shiftedRetainCycle]];
                    });
                    hasFound = YES;
                    break;
                }
                
                ++index;
            }
            if (hasFound) {
                break;
            }
        }
        if (!hasFound) {
            //回到主线程展示
            dispatch_async(dispatch_get_main_queue(), ^{
                [MLeaksMessenger alertWithTitle:@"Retain Cycle"
                                        message:@"Fail to find a retain cycle"];
            });
        }
    });
#endif
}
//把当前对象调整到第一个的位置，方便查看
- (NSArray *)shiftArray:(NSArray *)array toIndex:(NSInteger)index {
    if (index == 0) {
        return array;
    }
    
    NSRange range = NSMakeRange(index, array.count - index);
    NSMutableArray *result = [[array subarrayWithRange:range] mutableCopy];
    [result addObjectsFromArray:[array subarrayWithRange:NSMakeRange(0, index)]];
    return result;
}
```
我们发现，MLeaksFinder在展示循环引用的时候，使用的是**Facebook**开源的 **FBRetainCycleDetector** 工具。               
我们先通过 MLeaksFinder 找到内存泄漏的对象，然后再过 FBRetainCycleDetector 检测该对象有没有循环引用。               
有关FBRetainCycleDetector，我们可以查阅[这篇文章](https://code.facebook.com/posts/583946315094347/automatic-memory-leak-detection-on-ios/?spm=a2c4e.11153940.blogcont68473.11.3d804fa4z2vkPs)（需要科学上网）。              
我们实际上可以了解，FBRetainCycleDetector是将一个对象，一个ViewController,或者一个block当成一个节点，相关的强引用关系则是线。他们实际上会形成有向无环图（DAG 图），我们则需要在其中寻找可能存在的环，这里使用了深度优先搜索算法来遍历它，并找到循环节点。     

### 4.NSObject+MemoryLeak
这个文件主要用来存储对象的父子节点的树形结构，method swizzle逻辑 ，白名单以及实施判断对象是否发生内存泄漏。
```C++
- (BOOL)willDealloc {
    NSString *className = NSStringFromClass([self class]);
    if ([[NSObject classNamesWhitelist] containsObject:className])
        return NO;
    NSNumber *senderPtr = objc_getAssociatedObject([UIApplication sharedApplication], kLatestSenderKey);
    if ([senderPtr isEqualToNumber:@((uintptr_t)self)])
        return NO;
    
    __weak id weakSelf = self;
    //在特定时间检查对象是否已经发生内存泄漏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong id strongSelf = weakSelf;
        [strongSelf assertNotDealloc];
    });
    
    return YES;
}
```
这个方法对外的时候主要是用来提供给各个方法退出的时候调用的。而内部，则是先筛选不会报告的若干情况，以下是三个判断条件：
> * [[NSObject classNamesInWhiteList] containsObject:className]为True.
显而易见，这个方法是判断是否加入白名单
> * [senderPtr isEqualToNumber:@((uintptr_t)self)]为True.
介绍在下方
> * __strong id strongSelf = weakSelf;中的strongify为nil.
这里先设置 __weak id weakSelf = self;，然后在进行__strong id strongSelf = weakSelf，假如对象已经被释放，strongSelf为nil 调用该方法什么也不发生。

这里我说明下第二条：              
正在执行target-Action的target对象不监测内存泄漏。当用户触发执行Target-Action方法的时候，实际上在执行action方法前，是sender对象先执行**sendAction:to:forEvent**方法，然后**UIApplicatoin**执行
**sendAction:to:from:forEvent:**方法，其中from就是sender对象.
这里使用方法交换截获**sendAction:to:from:forEvent:**,然后截获了当前sender对象保存在kLatestSenderKey中。判断两者是否相同。              
这里的原因涉及到了target-action原理，当前实际上会形成一个循环引用，这里推荐[这篇文章](http://southpeak.github.io/2015/12/13/cocoa-uikit-uicontrol/),我们可以得出结论
> * 对于_target成员变量，在UIControlTargetAction的初始化方法中调用了objc_storeWeak，即这个成员变量对外部传进来的target对象是以weak的方式引用的。

而如果发生恩泄露，则会调用以下方法：
```C++
- (void)assertNotDealloc {
    if ([MLeakedObjectProxy isAnyObjectLeakedAtPtrs:[self parentPtrs]]) {
        return;
    }
    [MLeakedObjectProxy addLeakedObject:self];
    
    NSString *className = NSStringFromClass([self class]);
    NSLog(@"Possibly Memory Leak.\nIn case that %@ should not be dealloced, override -willDealloc in %@ by returning NO.\nView-ViewController stack: %@", className, className, [self viewStack]);
}
```
这里面就是直接的判断方法了，作用在之前提过。
**-(void)willReleaseObject:(id)object relationship:(NSString *)relationship;** 这个方法我没有查阅到相关引用，可能是已经废弃。如果有知道的，请不吝赐教。

接下来分析下面三个关键的方法：
```C++ 
- (void)willReleaseChild:(id)child;
- (void)willReleaseChildren:(NSArray *)children;
- (NSArray *)viewStack;
```
**-(void)willReleaseChild:(id)child** 其实只是将child对象添加到一个数组中执行 **-(void)willReleaseChildren:(NSArray *)children**方法

```C++
- (void)willReleaseChild:(id)child {
    if (!child) {
        return;
    }
    
    [self willReleaseChildren:@[ child ]];
}
```
第一个方法只在UIViewController+MemoryLeak中执行，
```C++
- (BOOL)willDealloc {
    if (![super willDealloc]) {
        return NO;
    }
    
    [self willReleaseChildren:self.childViewControllers];
    [self willReleaseChild:self.presentedViewController];
    if (self.isViewLoaded) {
        //判断一个UIViewController的view是否已经被加载
        [self willReleaseChild:self.view];
    }
    
    return YES;
}
```
而后一个方法则在很多地方都有执行，其内部实现如下
```C++
- (void)willReleaseChildren:(NSArray *)children {
    //NSArray *viewStack = [self viewStack];
    //NSSet *parentPtrs = [self parentPtrs];
    for (id child in children) {
        //NSString *className = NSStringFromClass([child class]);
        //[child setViewStack:[viewStack arrayByAddingObject:className]];
       // [child setParentPtrs:[parentPtrs setByAddingObject:@((uintptr_t)child)]];
        [child willDealloc];
    }
}
```

注释掉无关的代码，我们实际上发现，这里循环调用 **willDealloc** 方法。而注释掉的方法则是递归self.view，写入一个栈**viewStack**当中，最后在Alertview中展示出来。

构造堆栈信息的原理就是，递归遍历子对象，然后将父对象 class name 加上子对象 class name，一步步构造出一个 view stack。出现泄漏则直接打印此对象的 view stack 即可。

+(void)addClassNamesToWhitelist:(NSArray *)classNames;方法则一目了然，用于添加白名单。

最后一个方法
```C++
+ (void)swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL {
    //通过预编译控制是否hook方法
#if _INTERNAL_MLF_ENABLED
    //通过预编译控制是否检查循环引用
#if _INTERNAL_MLF_RC_ENABLED
    // Just find a place to set up FBRetainCycleDetector.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [FBAssociationManager hook];
        });
    });
#endif
    
    Class class = [self class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    BOOL didAddMethod =
    /*
    class_addMethod主要是用来给某个类添加一个方法，originalSEL相当于是方法名称,method_getImplementtation是方法实现, 它返回一个BOOL类型的值,在当前class中没有叫originalSEL的方法(具体不是看interface里没有没有声明，而是看implementaion文件里有没有方法实现)，并且有swizzledMethod方法的实现,这个时候该函数会返回true，其他情况均返回false
    */
    class_addMethod(class,
                    originalSEL,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        //didAddMethod为true 说明swizzledMethod之前不存在，通过class_addMethod函数添加了一个名字叫origninalSEL，实现swizzledMoethod函数。
        class_replaceMethod(class,
                            swizzledSEL,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        //didAddMethod为false 说明swizzledMethod方法已经存在，直接交换二者实现

        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
#endif
}
```

> * 中间那一段BOOL类型的使用原因 
    "周全起见，有两种情况要考虑一下。第一种情况是要复写的方法(overridden)并没有在目标类中实现(notimplemented)，而是在其父类中实现了。第二种情况是这个方法已经存在于目标类中(does existin the class itself)。这两种情况要区别对待。 (译注: 这个地方有点要明确一下，它的目的是为了使用一个重写的方法替换掉原来的方法。但重写的方法可能是在父类中重写的，也可能是在子类中重写的。) 对于第一种情况，应当先在目标类增加一个新的实现方法(override)，然后将复写的方法替换为原先(的实现(original one)。 对于第二情况(在目标类重写的方法)。这时可以通过method_exchangeImplementations来完成交换."

这个方法为其他分类统一给出了一个Method Swizzling的方法。

### 其他类
关于其他类，基本上都是实现了交换方法。不细说。

### 总结

MLeaksFinder中使用了AOP的思想，不会插入到业务代码当中，即插即用。检测流程可以简化为：
> 1. 给分类统一提供一个交换方法的方法（此方法保证一定可以交换方法）
> 2.  然后在运行中统一遍历view，viewController，将名字加入栈中
> 3. 规避掉一些方法（白名单，Target-Action方法）
> 4.  检测是否有循环引用
