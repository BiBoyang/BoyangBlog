# 夜半无事--探究KVO的实现

![](https://github.com/BiBoyang/Study/blob/master/Image/B_Rex_00.png?raw=true)


KVO 全称是**Key-Value Observing**,即键值观察者。是苹果官方提供的一种事件通知机制。
键值观察提供了一种机制，该机制允许将其他对象的特定属性的更改通知对象。对于应用程序中模型层和控制器层之间的通信特别有用。控制器对象通常观察模型对象的属性，而视图对象通过控制器观察模型对象的属性。但是，此外，模型对象可以观察其他模型对象（通常用于确定从属值何时更改），甚至可以观察自身（再次确定从属值何时更改）。		
您可以观察属性，包括简单属性，一对一关系和**一对多**关系。一对多关系的观察者被告知所做更改的类型，以及更改涉及哪些对象。		
KVO最大的优势在于不需要修改其内部代码即可实现监听，但是有利有弊，最大的问题也是出自这里。

## 基础使用
> * 本文只说在自动观察的情况下的原理，KVO实际上有手动观察的状态，但是原理和自动观察一样，就不再多说了。

一般情况下，我们使用KVO有以下三种步骤：
> * 1.通过 `-(void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;` 方法注册观察者，观察者可以接收keyPath属性的变化事件,并且使用context加入信息；
> * 2.实现 `-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context` 方法，当keypath对应的元素发生变化时，会发生回调；
> * 3.如果不再需要监听，则需要使用 `-(void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context;` 方法来释放掉。

这里稍微提一下NSKeyValueObservingOptions的种类：
```C++
NSKeyValueObservingOptionNew = 0x01, 提供更改前的值
NSKeyValueObservingOptionOld = 0x02, 提供更改后的值
NSKeyValueObservingOptionInitial = 0x04, 观察最初的值（在注册观察服务时会调用一次触发方法）
NSKeyValueObservingOptionPrior = 0x08 分别在值修改前后触发方法（即一次修改有两次触发）
```

比如说，我创建了一个Fish类
```C++
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface Fish : NSObject
@property (nonatomic,strong)NSString *color;
@property (nonatomic,strong)NSString *price;
@end
NS_ASSUME_NONNULL_END
```
然后在viewController.m文件中，这样添加观察者
```C++
    self.saury = [[Fish alloc]init];
    [self.saury setValue:@"blue" forKey:@"color"];
    [self.saury addObserver:self forKeyPath:@"color" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)([NSString stringWithFormat:@"yellow"])];
```
这里我在context中加入了一个字符串，这也是KVO的一种传值方式。
接着我们实现监听：
```C++
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"color"]) {
        NSString *str = (__bridge NSString *)(context);
        NSLog(@"___%@",str);
    }
}
```
最后把它移除
```C++
-(void)dealloc {
    //移除监听
    [self.saury removeObserver:self forKeyPath:@"price" context:(__bridge void * _Nullable)([NSString stringWithFormat:@"yellow"])];
}
```
看起来一般都是这么使用的。

好了，到这里，就该吐槽一下KVO的很多坑爹的地方了。
> * 1. 每次都必须在可靠准确的时间点**手动**移除观察者；
> * 2. 传递上下文使用context时非常别扭，因为这个是个void指针，需要神奇的桥接；
    比如说我要传递一个字符串，添加观察者的时候使用 **(__bridge void * _Nullable)([NSString stringWithFormat:@"yellow"])** ，然后在接收的时候，需要使用**(__bridge NSString *)**来转换过来。
> * 3. 如果有多个观察者，在手动移除的时候需要鉴别context来分别移除；
> * 4. addObserver和removeObserver需要是成对的，如果remove多了就会发生crash，如果少remove了，就会在再次接收到回调的时候发生crash；
> * 5. 一旦被观察的对象和属性很多时，就要分门别类的用if方法来分辨，代码写的奇丑无比。
> * 6. KVO的实现是通过setter方法，使用KVO必须调用setter，直接访问属性对象是没有用的。
> * 7. KVO在多线程的情况下并不安全。KVO是在setter的线程上获得通知，我们使用的时候一定要注意线程的问题。这里是[官方的解读](https://developer.apple.com/library/archive/documentation/General/Conceptual/CocoaEncyclopedia/ReceptionistPattern/ReceptionistPattern.html)，还有其他的[文章](https://inessential.com/2013/12/20/observers_and_thread_safety)来阐述这个事实。

当然，这个问题实际上非常普遍而且持续时间非常久，久到GUN的时代就有了，吐槽的文章也是很多，比如[这个](https://www.mikeash.com/pyblog/friday-qa-2009-01-23.html)。这么多的缺点，也是KVOController诞生的主要原因。


## KVO实现原理 

在[官方文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html#//apple_ref/doc/uid/10000177-BCICJDHA)中有这样一句话。
>  Automatic key-value observing is implemented using a technique called isa-swizzling.
The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.		
When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.		
You should never rely on the isa pointer to determine class membership. Instead, you should use the class method to determine the class of an object instance.		
自动键值观察是使用isa-swizzling实现的。		
isa指针，顾名思义，指向对象的类，它保持一个调度表。该调度表实质上包含指向该类实现的方法的指针以及其他数据。		
在为对象的属性注册观察者时，将修改观察对象的isa指针，指向中间类而不是真实类。结果，isa指针的值不一定反映实例的实际类。		
**您永远不要依靠isa指针来确定类成员。相反，您应该使用该class方法来确定对象实例的类。**


配合demo代码，阐明了KVO的实现原理：
> * 当某个类的属性对象被观察的时候，系统就会在运行期动态的创建一个派生类**NSKVONotifying_xx**。在这个派生类中重写被观察属性的setter方法和Class方法，dealloc，_isKVO方法，然后这个isa指针指向了这个新建的类（注意！Class方法指向的还是原有的类名）。派生类在被重写的setter方法中实现了真正的通知机制，而和原有的对象隔离开来。
> * KVO的实现在上层也依赖于 NSObject 的两个方法：**willChangeValueForKey:**、**didChangeValueForKey:** 。在一个被观察属性改变之前，调用 willChangeValueForKey: 记录旧的值。在属性值改变之后调用 didChangeValueForKey:，从而 observeValueForKey:ofObject:change:context: 也会被调用。


![](https://user-gold-cdn.xitu.io/2019/1/31/168a2f3d09d33a5a?imageView2/0/w/1280/h/960/ignore-error/1)

当然，到底是不是，看一下源码不就知道了。

### 查看源码

尴尬的是，在runtime的源码当中，我们是找不到有关kvo的东西的。那么该怎么办呢？
这里要先讲一点历史了。

早在1985 年，Steve Jobs 离开苹果电脑(Apple) 后成立了NeXT 公司，并于1988 年推出了NeXT 电脑，使用NeXTStep 为操作系统。这也是现在Cocoa里面很多NS开头的类名的源头。在当时，NeXTStep 是相当先进的系统。 以Unix (BSD) 为基础，使用PostScript 提供高品质的图形界面，并以Objective-C 语言提供完整的面向对象环境。		
尽管NeXT 在软件上的优异，其硬体销售成绩不佳，不久之后，NeXT 便转型为软件公司。1994 年，NeXT 与Sun(Sun Microsystem) 合作推出OpenStep 界面，目标为跨平台的面向对象程式开发环境。NeXT 接着推出使用OpenStep 界面的OPENSTEP 系统，可在Mach, Microsoft Windows NT, Sun Solaris 及HP/UX 上执行。1996 年，苹果电脑买下NeXT，做为苹果电脑下一代操作系统的基础。 OPENSTEP 系统便演进成为MacOS X 的Cocoa 环境。		
在1995 年，自由软体基金会(Free Software Fundation) 开始了GNUstep 计划，目的在使用OpenStep 界面，以提供Linux/BSD 系统一个完整的程式发展环境，而GNUstep最初是GNU开发人员努力复制技术上雄心勃勃的NeXTSTEP的程序员友好功能。GNUstep是要早于Cocoa的实现的。我们可以从GNUstep的实现代码中，来参考KVO的设计思路。		
你可以[点击这里](http://www.gnustep.org/resources/downloads.php)来找到GNUstep的源码，或者也可以直接查看我下载下来的[文件](https://github.com/BiBoyang/Study/tree/master/KVO/NSKeyValueObserving)，我们可以很惊奇的发现，至少在NSKeyValueObserving.h文件中，很多函数名是一样的。

> * 当然还有很多不同，比如说对于context的支持就少很多，remove方法就没有支持context的函数。



### 1. - addObserver: forKeyPath: options: context: 的实现过程
这个方法在**NSObject (NSKeyValueObserverRegistration)**中。
```C++
- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    GSKVOInfo             *info;
    GSKVOReplacement      *r;
    NSKeyValueObservationForwarder *forwarder;
    NSRange               dot;

    //初始化
    setup();
    //使用递归锁保证线程安全--kvoLock是一个NSRecursiveLock
    [kvoLock lock];
    // Use the original class
    //从全局NSMapTable中获取某个类的KVO子类Class
    r = replacementForClass([self class]);
    /*
     * Get the existing observation information, creating it (and changing
     * the receiver to start key-value-observing by switching its class)
     * if necessary.
     */
    //从全局NSMapTable中获取某个类的观察者信息对象,并通过改变它的类来改变接收器以开始观察关键值
    info = (GSKVOInfo*)[self observationInfo];
    //如果没有信息(不存在)就创建一个观察者信息对象实例。
 
    if (info == nil) {
        info = [[GSKVOInfo alloc] initWithInstance: self];
        //保存到全局NSMapTable中。
        [self setObservationInfo: info];
        //将被观察的对象的isa修改为新的KVO子类Class
        object_setClass(self, [r replacement]);
    }
    /*
     * Now add the observer.
     * 开始处理观察者
     */
    dot = [aPath rangeOfString:@"."];
    //string里有没有.
    if (dot.location != NSNotFound) {
        //有.说明可能是成员变量
        forwarder = [[NSKeyValueObservationForwarder alloc]initWithKeyPath: aPath
                                                                  ofObject: self
                                                                withTarget: anObserver
                                                                   context: aContext];
        [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: forwarder];
    } else {
        //根据key 找到对应的setter方法，然后根据类型去获取GSKVOSetter类中相对应数据类型的setter方法
        [r overrideSetterFor: aPath];
        /* 这个是GSKVOInfo里的方法
         * 将keyPath 信息保存到GSKVOInfo中的paths中，方便以后直接从内存中取。
         */
         [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: aContext];
    }
    //递归锁解锁
    [kvoLock unlock];
}
``` 
我们接着来分段看。

#### setup();

```C++
NSString *const NSKeyValueChangeIndexesKey = @"indexes";
NSString *const NSKeyValueChangeKindKey = @"kind";
NSString *const NSKeyValueChangeNewKey = @"new";
NSString *const NSKeyValueChangeOldKey = @"old";
NSString *const NSKeyValueChangeNotificationIsPriorKey = @"notificationIsPrior";

static NSRecursiveLock    *kvoLock = nil;
static NSMapTable    *classTable = 0;//NSMapTable如果对key 和 value是弱引用，当key 和 value被释放销毁后，NSMapTable中对应的数据也会被清除。
static NSMapTable    *infoTable = 0;
static NSMapTable       *dependentKeyTable;
static Class        baseClass;
static id               null;

#pragma mark----- setup
static inline void
setup() {
    if (nil == kvoLock) {
        //这是一个全局的递归锁NSRecursiveLock
        [gnustep_global_lock lock];
        if (nil == kvoLock) {
            kvoLock = [NSRecursiveLock new];
            /*
             * NSCreateMapTable创建的是一个NSMapTable，一个弱引用key-value容器，
             */
            null = [[NSNull null] retain];
            classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                          NSNonOwnedPointerMapValueCallBacks, 128);
            infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 1024);
            dependentKeyTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                                 NSOwnedPointerMapValueCallBacks, 128);
            baseClass = NSClassFromString(@"GSKVOBase");
        }
        [gnustep_global_lock unlock];
    }
}
```
创建了classTable、infoTable、dependentKeyTable来存储类名、观察者的信息、依赖者对应的key。

#### [kvoLock lock];
为了保证线程安全，这里使用了递归锁。
递归锁的特点是：可以允许同一线程多次加锁，而不会造成死锁。**递归锁会跟踪它被lock的次数。每次成功的lock都必须平衡调用unlock操作。**只有所有达到这种平衡，锁最后才能被释放，以供其它线程使用。
这个很符合我们对于KVO的理解。

####   r = replacementForClass([self class]);
```C++
static GSKVOReplacement *replacementForClass(Class c) {
    GSKVOReplacement *r;
    //创建
    setup();
    //递归锁
    [kvoLock lock];
    //从全局classTable中获取GSKVOReplacement实例
    r = (GSKVOReplacement*)NSMapGet(classTable, (void*)c);
    //如果没有信息(不存在)，就创建一个保存到全局classTable中
    if (r == nil) {
        r = [[GSKVOReplacement alloc] initWithClass: c];
        NSMapInsert(classTable, (void*)c, (void*)r);
    }
    //递归锁解锁
    [kvoLock unlock];
    return r;
}
```
这里我们发现了 **r = [[GSKVOReplacement alloc] initWithClass: c];** 方法，它是GSKVOReplacement里的方法。它有三个成员变量。
```C++
{
    Class         original;       /* The original class 原有类*/
    Class         replacement;    /* The replacement class 替换类*/
    NSMutableSet  *keys;          /* The observed setter keys 被观察者的key*/
}
```
接着往下看。
```C++
- (id) initWithClass: (Class)aClass {
    NSValue        *template;
    NSString        *superName;
    NSString        *name;
    ...
    original = aClass;
    /*
     * Create subclass of the original, and override some methods
     * with implementations from our abstract base class.
     *  创建原始类的子类，并使用抽象基类中的实现重写某些方法。
     */
    superName = NSStringFromClass(original);
    name = [@"GSKVO" stringByAppendingString: superName];
    template = GSObjCMakeClass(name, superName, nil);
    GSObjCAddClasses([NSArray arrayWithObject: template]);
    replacement = NSClassFromString(name);
    //这个baseClass是GSKVOBase
    GSObjCAddClassBehavior(replacement, baseClass);
    /*
     * Create the set of setter methods overridden.
     * 创建重写的setter方法集。
     */
    keys = [NSMutableSet new];
    return self;
}
```
在 **-(id)initWithClass:(Class)aClass** 函数中，传入的原始class即是original，而原有的类名，会在前面拼接一个 **"GSKVO"** 字符串之后变成替代类的类名。
而通过 **GSObjCAddClassBehavior** 方法，则会在将GSKVOBase的方法拷贝到replacement中去。
而GSKVOBase中有什么方法呢？
```C++
- (void) dealloc;
- (Class) class;
- (Class) superclass;
- (void) setValue: (id)anObject forKey: (NSString*)aKey;
- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey;
- (void) takeValue: (id)anObject forKey: (NSString*)aKey;
- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey;
```
最关键的dealloc、class、superclass、setter方法都被重写。
class、superclass方法都被加了一层**class_getSuperclass**，以避免干扰，还是能直接获取到正确的class名。

这里结束不谈，回 **- addObserver: forKeyPath: options: context:** 。
接着我们创建观察者信息，并插入到infoTable中去。
然后通过object_setClass方法将修改class名称，将被观察的对象的isa修改为新的KVO子类Class。

#### if (dot.location != NSNotFound)
这里就很有意思了，我们需要查看，keyPath里是不是有`.`。
如果有`.`,说明可能是成员变量，我们需要递归的向下筛选。
举个🌰，
比如说，我们要查看`Computer`中的成员变量`NoteBook`的属性`brand`。
你需要观察的keyPath实际上是NoteBook.brand。
那我们要先观察NoteBook的属性变化，在往下观察brand的变化。
```C++
keyForUpdate = [[keyPath substringToIndex: dot.location] copy];
remainingKeyPath = [keyPath substringFromIndex: dot.location + 1];
```
而如果没有.的问题，我们就可以根据key，直接找到对应的setter方法，**-(void)overrideSetterFor**函数。然后根据类型去获取GSKVOSetter类中相对应数据类型的setter方法。
比如如下代码：
```C++
- (void) setter: (void *)val {
    NSString    *key;
    Class        c = [self class];//GSKVOSetter继承的事NSObject，所以这里获取的还是原有的父类，并未被改写
    void        (*imp)(id,SEL,void*);
    //获取真正的函数地址--原始的setter方法
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: _cmd];

    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    } else {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}
```


#### GSKVOInfo 的- addObserver: forKeyPath: options: context: 
然后，我们会发现，诶？怎么又是一个添加观察者？
这个实际上是一个GSKVOInfo里的函数。
在这里创建、存储KVO的信息，并处理一些细节问题:
> 在上面，我特地提过NSKeyValueObservingOptions的种类。
里面有个NSKeyValueObservingOptionInitial属性，当使用它的时候，需要在注册观察服务时会调用一次触发方法。这个时候就可以直接在判断完之后调用 **-observeValueForKeyPath：ofObject：change：context** 方法。






### 2. -observeValueForKeyPath: ofObject: change: context:
这是一段很长的代码
```C++
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context {
  if (anObject == observedObjectForUpdate) {
      [self keyPathChanged: nil];
    } else {
      [target observeValueForKeyPath: keyPathToForward
                            ofObject: observedObjectForUpdate
                              change: change
                             context: contextToForward];
    }
}

- (void) keyPathChanged: (id)objectToObserve {
    if (objectToObserve != nil) {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
        observedObjectForUpdate = objectToObserve;
        [objectToObserve addObserver: self
                          forKeyPath: keyForUpdate
                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             context: target];
    }
    if (child != nil) {
        [child keyPathChanged:
        [observedObjectForUpdate valueForKey: keyForUpdate]];
    } else {
        NSMutableDictionary *change;
        change = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt: 1]forKey:  NSKeyValueChangeKindKey];
        if (observedObjectForForwarding != nil) {
            id oldValue;
            oldValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            [observedObjectForForwarding removeObserver: self
                                             forKeyPath:keyForForwarding];
            if (oldValue) {
                [change setObject: oldValue
                           forKey: NSKeyValueChangeOldKey];
            }
        }
        observedObjectForForwarding = [observedObjectForUpdate valueForKey:keyForUpdate];
        if (observedObjectForForwarding != nil) {
            id newValue;
            [observedObjectForForwarding addObserver: self
                                          forKeyPath: keyForForwarding
                                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                             context: target];
            //prepare change notification
            newValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            if (newValue) {
                [change setObject: newValue forKey: NSKeyValueChangeNewKey];
            }
        }
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
        }
}
@end
```
我们发现，不管怎样都是要调用 **- (void) keyPathChanged:** ，所以可以越过observeValueForKeyPath直接来看 **- (void) keyPathChanged:** 函数。
```C++
- (void) keyPathChanged: (id)objectToObserve {
    if (objectToObserve != nil) {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
        observedObjectForUpdate = objectToObserve;
        [objectToObserve addObserver: self
                          forKeyPath: keyForUpdate
                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             context: target];
    }
    if (child != nil) {
        [child keyPathChanged:[observedObjectForUpdate valueForKey: keyForUpdate]];
    } else {
        NSMutableDictionary *change;
        change = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt: 1]
                                                    forKey:NSKeyValueChangeKindKey];
        if (observedObjectForForwarding != nil) {
            id oldValue;
            oldValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            [observedObjectForForwarding removeObserver: self
                                             forKeyPath:keyForForwarding];
            if (oldValue) {
                [change setObject: oldValue
                           forKey: NSKeyValueChangeOldKey];
            }
        }
        observedObjectForForwarding = [observedObjectForUpdate valueForKey:keyForUpdate];
        if (observedObjectForForwarding != nil) {
            id newValue;
            [observedObjectForForwarding addObserver: self
                                          forKeyPath: keyForForwarding
                                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                             context: target];
            //prepare change notification
            newValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            if (newValue) {
                [change setObject: newValue
                           forKey: NSKeyValueChangeNewKey];
            }
        }
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
        }
}

```
这段是个很长的代码，作用的将需要的数据不断的填充进应该的位置：
里面四个主要的参数，实际上就是方法 **-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context** 里的数据。


### 3. - removeObserver: forKeyPath: context:;
这个方法则实现的简单了一些，只有基础方法，而没有根据context删除指定observer的方法，算是一个缺陷。
```C++
- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath {
    GSKVOInfo    *info;
    id            forwarder;
    /*
     * Get the observation information and remove this observation.
     */
    info = (GSKVOInfo*)[self observationInfo];
    forwarder = [info contextForObserver: anObserver ofKeyPath: aPath];
    [info removeObserver: anObserver forKeyPath: aPath];
    if ([info isUnobserved] == YES) {
        /*
         * The instance is no longer being observed ... so we can
         * turn off key-value-observing for it.
         * 实例不再被观察。。。所以我们可以关闭它的键值观测。
         */
        //修改对象所属的类 为新创建的类
        object_setClass(self, [self class]);
        IF_NO_GC(AUTORELEASE(info);)
        [self setObservationInfo: nil];
    }
    if ([aPath rangeOfString:@"."].location != NSNotFound)
        [forwarder finalize];
}
```
这里实际上就是添加观察者的反过程，不过多的说明。

另外，因为并没有 **- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context** 方法的实现，我猜测了一下可能的实现。
> * 对于infoTable可能设计的更加复杂，可以使用context作为key来添加和删除相同的被观察者的实例，即使是同一个被观察者对象，也可以通过context来创建不同的被观察实例。



#### 题外话

有个老哥自己根据反汇编写了一个KVC、KVO的实现，[代码地址在这里](https://github.com/renjinkui2719/DIS_KVC_KVO),在表现形式上已经和原生的KVO差不多了。不过作者使用的依然是Dictionary而非NSMapTable；锁使用的是pthread_mutex_t互斥锁以及OSSpinLockLock自旋锁，而非NSRecursiveLock递归锁。不过写到这个已经很不错了。


## 关于KVOController
KVO在使用上有各种各样的问题，有一种比较好的解决办法就是使用Facebook的[KVOController](https://github.com/facebook/KVOController)。
我们就可以写成这样。
```C++
[self.KVOController observe:clock keyPath:@"date" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew action:@selector(updateClockWithDateChange:)];
```
并且带来了很多好处：
> 1. 不再关心释放的问题，实际上是非常有效并且安全。
> 2. 直接使用keypath来对应属性，就不再需要多次的if判断，即使是多个观察者；
> 3. 使用 block 来提升使用 KVO 的体验；

它的实现其实蛮简单的。刨除头文件，主要有4个文件。
-  NSObject+FBKVOController.h
-  NSObject+FBKVOController.m
-  FBKVOController.h
-  FBKVOController.m

分别来看，NSObject+FBKVOController里的 `KVOControllerNonRetaining` 这个元素并不会持有被观察的对象，有效的防止循环引用；而`KVOController`还是会造成循环引用。
而它们的区别在于初始化传入的retianObserved的不同。
```C++
- (instancetype)initWithObserver:(nullable id)observer retainObserved:(BOOL)retainObserved
{
  self = [super init];
  if (nil != self) {
    _observer = observer;
    NSPointerFunctionsOptions keyOptions = retainObserved ? NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality : NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality;
    _objectInfosMap = [[NSMapTable alloc] initWithKeyOptions:keyOptions valueOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPersonality capacity:0];
    pthread_mutex_init(&_lock, NULL);
  }
  return self;
}
```
在这里，生成持有者信息的时候会有个判断，持有对象传入的是 NSPointerFunctionsStrongMemory ，不止有对象的是 NSPointerFunctionsWeakMemory 。

主要的代码都在FBKVOController.m中。

### FBKVOController
这里，我们可以发现，这里有一个NSMapTable类型的_objectInfosMap，和上面的类似的map起到了类似的作用--用来存储当前对象持有者的相关信息。
而为了线程安全，这里使用了`pthread_mutex_t`，一个互斥锁。
> * _objectInfosMap
> * _lock 


还是从观察开始看
```C++
- (void)observe:(nullable id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(FBKVONotificationBlock)block {
    ......
  _FBKVOInfo *info = [[_FBKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:block];
    ......
  [self _observe:object info:info];
}
```
这里有个数据结构：_FBKVOInfo在上面也有类似的实现，用于存储所有有关的信息。这里就不多说了。
接着看关键的一个私有方法。
```C++
- (void)_observe:(id)object info:(_FBKVOInfo *)info {
  // lock
  pthread_mutex_lock(&_lock);
  NSMutableSet *infos = [_objectInfosMap objectForKey:object];
  // check for info existence
  _FBKVOInfo *existingInfo = [infos member:info];
  if (nil != existingInfo) {
    // observation info already exists; do not observe it again
    // unlock and return
    pthread_mutex_unlock(&_lock);
    return;
  }
  // lazilly create set of infos
  if (nil == infos) {
    infos = [NSMutableSet set];
    [_objectInfosMap setObject:infos forKey:object];
  }
  // add info and oberve
  [infos addObject:info];
  // unlock prior to callout
  pthread_mutex_unlock(&_lock);
  [[_FBKVOSharedController sharedController] observe:object info:info];
}
```
这里通过_objectInfosMap来判断当年的对象信息是否已经注册过。
然后处理一次InfosMap之后，会接着调用_FBKVOSharedController的单例方法。
```C++
- (void)observe:(id)object info:(nullable _FBKVOInfo *)info {
  if (nil == info) {
    return;
  }

  pthread_mutex_lock(&_mutex);
  [_infos addObject:info];
  pthread_mutex_unlock(&_mutex);

  [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(void *)info];
  if (info->_state == _FBKVOInfoStateInitial) {
    info->_state = _FBKVOInfoStateObserving;
  } else if (info->_state == _FBKVOInfoStateNotObserving) {
    [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
  }
}
```
而在整个流程中，只会有一个_FBKVOSharedController单例。
而这个方法才会调用原生的KVO方法。
```C++
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *, id> *)change
                       context:(nullable void *)context {
    _FBKVOInfo *info;
    pthread_mutex_lock(&_mutex);
    info = [_infos member:(__bridge id)context];
    pthread_mutex_unlock(&_mutex);

    FBKVOController *controller = info->_controller;
    id observer = controller.observer;

    if (info->_block) {
        NSDictionary<NSString *, id> *changeWithKeyPath = change;
        if (keyPath) {
            NSMutableDictionary<NSString *, id> *mChange = [NSMutableDictionary dictionaryWithObject:keyPath forKey:FBKVONotificationKeyPathKey];
            [mChange addEntriesFromDictionary:change];
            changeWithKeyPath = [mChange copy];
        }
        info->_block(observer, object, changeWithKeyPath);
    } else if (info->_action) {
        [observer performSelector:info->_action withObject:change withObject:object];
    } else {
        [observer observeValueForKeyPath:keyPath ofObject:object change:change context:info->_context];
    }
}
```
这里我们可以发现，最后实际上是通过_KVOInfo里的context来判断不同的KVO方法。


#### removeObserver
移除观察者的策略比较简单明了。
```C++
- (void)unobserve:(id)object infos:(nullable NSSet<_FBKVOInfo *> *)infos {
  pthread_mutex_lock(&_mutex);
  for (_FBKVOInfo *info in infos) {
    [_infos removeObject:info];
  }
  pthread_mutex_unlock(&_mutex);

  for (_FBKVOInfo *info in infos) {
    if (info->_state == _FBKVOInfoStateObserving) {
      [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
    }
    info->_state = _FBKVOInfoStateNotObserving;
  }
}
```
遍历这里的_FBKVOInfo，从其中取出 keyPath 并将 _KVOSharedController 移除观察者。

### KVOController总结
KVOController其实是用自己的方法，在原生KVO上又包了一层，用于自动处理，并不需要我们来处理移除观察者，大大降低了出错的情况。


# 结论

> 1. 能别用KVO就别用了，notification难道不好吗？同样是一对多，而且notification并不局限于属性的变化，各种各样状态的变化也都可以监听。
> 2. 实在要用直接用KVOController吧。

ps:看完KVO其实比较无趣，因为你会发现KVO其实有不少优秀的替代者，研究得出了不要用的婕拉确实有点沮丧，也显得研究并没有啥意义。但是确实有趣啊，哈哈。



## 引用
[Key-Value Observing Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html#//apple_ref/doc/uid/10000177-BCICJDHA)
[Observers and Thread Safety](https://inessential.com/2013/12/20/observers_and_thread_safety)
