# Runtime扯扯扯

前段日子，我又看了一遍[sunnyxx](http://blog.sunnyxx.com/)的一段有关runtime的[分享会视频](http://v.youku.com/v_show/id_XODIzMzI3NjAw.html)(不要吐槽AV画质)，结合这几年在印象笔记里的各种碎片以及看的书，为自己进行一个知识的整合和梳理。
## 简述
Runtime 又叫运行时，是一套底层的，由C语言和汇编实现的API，是 iOS 系统的核心之一。可以说，Objective-C = C + runtime。C语言使用的是静态绑定（static binding），也就是说，在编译期的时候就能觉醒运行时的应该调用的函数。而因为runtime的关系，Objective-C会在运行的死后才会决定调用那个函数。

我这里准备把它分为四部分：
* Runtime的类和对象
* Runtime的消息机制
* Runtime的关联对象
* Runtime的方法替换

## Runtime的类和对象

#### Class 和 id
Objective-C（为了方便，下面用OC代替）的类是由`Class`来表示的，实际上是一个objc_class的指针,而对象，则是`objc_object`:

```
struct objc_class {
    struct objc_class *isa;
};
struct objc_object {
    struct objc_class *isa;
};
 
typedef struct objc_class *Class; //类  (class object)
typedef struct objc_object *id;   //对象 (instance of class)
```
没个结构体的收个成员是Class类变量，定义了所属的类。
接下来是`objc_class`的定义：

```
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;

#if !__OBJC2__
    Class _Nullable super_class                              OBJC2_UNAVAILABLE;
    const char * _Nonnull name                               OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars                  OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache * _Nonnull cache                       OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols          OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
```

这里有几个字段我们要了解的：
* isa：，它指向metaClass(元类)，我们会在后面介绍它。
* super_class：指向该类的父类，如果该类已经是最顶层的根类(如NSObject或NSProxy)，则super_class为NULL，我们也把它称之为`元类`。
* cache：用于缓存最近使用的方法。一个接收者对象接收到一个消息时，它会根据isa指针去查找能够响应这个消息的对象。在实际使用中，这个对象只有一部分方法是常用的，很多方法其实很少用或者根本用不上。这种情况下，如果每次消息来时，我们都是methodLists中遍历一遍，性能势必很差。这时，cache就派上用场了。在我们每次调用过一个方法后，这个方法就会被缓存到cache列表中，下次调用的时候runtime就会优先去cache中查找，如果cache没有，才去methodLists中查找方法。这样，对于那些经常用到的方法的调用，但提高了调用的效率。
* version：我们可以使用这个字段来提供类的版本信息。这对于对象的序列化非常有用，它可是让我们识别出不同类定义版本中实例变量布局的改变。




![图中实线是 super_class指针，虚线是isa指针](http://upload-images.jianshu.io/upload_images/1342490-61c779556dd9fd14?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 1. Root class (class)其实就是NSObject，NSObject是没有超类的，所以Root class(class)的superclass指向nil。
> 2. 每个Class都有一个isa指针指向唯一的Meta class
> 3. Root class(meta)的superclass指向Root class(class)，也就是NSObject，形成一个回路。
> 4. 每个Meta class的isa指针都指向Root class (meta)。
> 5. Root class(class)中保存实例方法（-方法）并在方法列表中查找，Root class(meta)中保存类（+方法）并在方法列表中查找。

关于元类，更多具体可以研究这篇文章[What is a meta-class in Objective-C?](https://link.jianshu.com/?t=http://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html)

至于第三条形成闭环的原因，也就是Root class(meta)的super_class是Root class（class）。我猜测是因为runtime机制需要一个最终的类去存储、查找方法。苹果讲大多数的类的最终指向了NSObject已解决这个问题，元类并不处理实例方法。

这里有个题：
下面代码会怎么样？

```
@interface NSObject (Sark)
+(void)foo;
@implementation NSObject (Sark)
- (void)foo {
 NSLog(@"IMP:-[NSObject (Sark) foo]");
}
@end
测试代码
[NSObject foo];
[[NSObject new]foo];
```
答案是会输出两个相同的结果。在调用 **[NSObject foo]**的时候，会先在NSObject的 `meta-class`中去查找foo方法的IMP，未找到，继续在superClass中去查找，NSObject的`meta-class`的superClass就是本身NSObject，于是又回到NSObject的类方法中查找foo方法，于是乎找到了，执行foo方法。
在调用 **[[NSObject new] foo]**的时候，会先生成一个NSObject的对象，用这个NSObject实例对象再去调用foo方法的时候，会去NSObject的实例方法里面去查找，找到，于是也会执行foo方法。
#### 查询类型信息
在NSObject中，查询类型信息有两个方法：

```
//判断对象是否为某个特定的实例。
- (BOOL)isKindOfClass:(Class)aClass;
//判断对象是否为某类或其派生类的实例。
- (BOOL)isMemberOfClass:(Class)aClass;
```
这里的查询方法使用isa指针获取对象所属的类，然后通过super_class指针在继承体系中上溯。
这里有个题：

```
   @interface Sark : NSObject
   @end
   @implementation Sark
   @end
   BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];
   BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];
   BOOL res3 = [(id)[Sark class] isKindOfClass:[Sark class]];
   BOOL res4 = [(id)[Sark class] isMemberOfClass:[Sark class]];
   NSLog(@"%d %d %d %d", res1, res2, res3, res4);
```
答案是：YES，NO，NO，NO
我简单的说一下这个几个方法的查找流程。

* res1
[NSObject class]执行完之后调用isKindOfClass，第一次判断先判断NSObject 和 NSObject的meta class是否相等，之前讲到meta class的时候放了一张很详细的图，从图上我们也可以看出，NSObject的meta class与本身不等。接着第二次循环判断NSObject与meta class的superclass是否相等。还是从那张图上面我们可以看到：Root class(meta) 的superclass 就是 Root class(class)，也就是NSObject本身。所以第二次循环相等。
* res2
isa 指向 NSObject 的 Meta Class，所以和 NSObject Class不相等。
* res3
Sark class]执行完之后调用isKindOfClass，第一次for循环，Sark的Meta Class与[Sark class]不等，第二次for循环，Sark Meta Class的super class 指向的是 NSObject Meta Class， 和 Sark Class不相等。第三次for循环，NSObject Meta Class的super class指向的是NSObject Class，和 Sark Class 不相等。第四次循环，NSObject Class 的super class 指向 nil， 和 Sark Class不相等。第四次循环之后，退出循环。
* res4
isa指向Sark的Meta Class，和Sark Class也不等。

## Runtime的消息机制

#### 消息发送
在Objective-C上，调用任何方法实际上都是在传递消息。有关消息机制的原理，大家可以看[Objective-C 消息发送与转发机制原理](https://link.jianshu.com/?t=http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)这篇文章。

```
id returnValue = [someObject messageName:parameter];
```
编译器会把它转化为
```
id returnValue = objc_msgSend(someObject, @selector(messageName:),parameter);
```
objc_msgSend会依据接收者与选择子的类型来调用适当的方法。该方法会在接受者所属的类中搜寻方法列表，如果能找到相关方法就去执行相关方法。若是找不到，就沿着体系上溯，直到找到方法。加入最终还是找不到方法，就要去执行消息转发。

> 在每个类里面，会讲成功匹配的方法缓存起来，若是稍后还向该类发送相同的消息，那么就会加速执行了。

在每个类里面，会有一个方法表， `selector`则是查找这个表的 **键**。objc_msgSend正式通过这张表格来寻找应该执行的方法并去实现了。注意，这里使用了[尾调用优化](http://www.ruanyifeng.com/blog/2015/04/tail-call.html)。
如果某函数的最后一项操作是调用另外一个函数，那么就会调用这个方法。编译器会生成调转至另一函数所需的指令码，而且不会向调用堆栈中推入新的“栈帧”。这么做法非常关键，如果不这么做的话，会过早的发生栈溢出。
消息发送的流程，我简单的归纳了一下：

> 执行objc_msgSend之后，先检查@selector方法时候为nil。若是，则直接返回，若无，下一步；
接着在缓存中查找是否有相关方法，若有，则执行方法；若无，则下一步；
然后在本类中的方法列表中查找是否有相关方法。若有，则执行，并加入缓存中；若无，则沿着父类上溯；
若是最终仍为找到方法，则执行消息转发。

#### 消息转发
在编译期间向类发送了其无法解读的消息并不会报错，因为在运行期可以继续向类中添加方法，所以编译器会在编译时还无法确定类中到底会不会有某个方法实现。当对象收到了无法解读的消息时，就会启动“消息转发”机制。

> 消息转发分为两大阶段。第一阶段先征询接受者，所属的类，看其是否能动态添加方法，以处理这个未知的选择子，这叫做动态方法解析。第二阶段涉及“完整的消息转发机制”。如果运行期系统已经把第一阶段执行完了，那么接受者自己就无法再以动态新增方法的手段来响应包含该选择子的消息了。此时，运行期系统会请求接受者以其他手段来处理与消息相关的方法调用。这里又分两步，首先，请接受者看看有没有其他对象能处理这条消息。若有，则运行期系统会把消息转给那个对象。若没有备用的接受者，则启动完整的消息转发机制，运行期系统会把与消息相关的全部细节都封装到NSInvocation当中，再给接受者最后一次机会，令其设法解决当前还未处理的这条消息。
###### 动态方法解析
对象在收到无法解读的消息后，先调用下述方法：

```
//实例方法
+ (BOOL)resolveInstanceMethod:(SEL)selector;
//类方法
+ (BOOL)resolveClassMethod:(SEL)selector;
```
不过使用该方法的前提是我们已经实现了该”处理方法”，只需要在运行时通过 **class_addMethod**函数动态添加到类里面就可以了。
###### 备用接收者
如果在上一步无法处理消息，则会继续调以下方法：
```
- (id)forwardingTargetForSelector:(SEL)aSelector
```
如果一个对象实现了这个方法，并返回一个非nil的结果，则这个对象会作为消息的新接收者，且消息会被分发到这个对象。当然这个对象不能是self自身，否则就是出现无限循环。当然，如果我们没有指定相应的对象来处理aSelector，则应该调用父类的实现来返回结果。

###### 完整消息转发
如果在上一步还不能处理未知消息，则唯一能做的就是启用完整的消息转发机制了。此时会调用以下方法：
```	
- (void)forwardInvocation:(NSInvocation *)anInvocation
```
运行时系统会在这一步给消息接收者最后一次机会将消息转发给其它对象。对象会创建一个表示消息的NSInvocation对象，把与尚未处理的消息有关的全部细节都封装在anInvocation中，包括selector，目标(target)和参数。我们可以在forwardInvocation方法中选择将消息转发给其它对象，直到NSObject。NSObject的 `forwardInvocation:`方法实现只是简单调用了 `doesNotRecognizeSelector:`方法，它不会转发任何消息,而是直接抛出异常。
## Runtime的关联对象
有时需要在对象中存放相关信息，这是我们通常对从对象所属的类中继承一个子类，然后改用这个子类对象。然而有时候我们无法这么做，这时候就要使用关联对象了。

|关联类型      | 等效的@property属性 |     
| --------   | -----  | 
| OBJC_ASSOCIATION_ASSIGN     | assign |  
| OBJC_ASSOCIATION_RETAIN_NONATOMIC        |  nonatomic,retain   |   
| OBJC_ASSOCIATION_COPY_NONATOMIC        |   nonatomic,copy    |  
| OBJC_ASSOCIATION_RETAIN        |    retain    |  
| OBJC_ASSOCIATION_COPY        |    copy    |  
下列方法可以管理关联对象：

> * void objc_setAssociatedObject(id object,void *key,id value,objc_AssociationPolicy policy)
此方法以给定的键和策略为某对象设置关联对象值
> * id objc_getAssociatedObject(id object,void *key)
此方法根据给定的键和策略为某对象中获取相应的关联对象值
> * void objc_removeAssicuatedObjects(id object)
此方法移除指定对象的全部关联对象

在设置关联对象值时，通常使用**静态全局变量**做键
使用场景
> 1. 为现有的类添加私有变量
> 2. 为现有的类添加公有属性
> 3. 为KVO创建一个关联的观察者。

## Runtime的方法替换

> 关于这个，我们可以看Mattt Thompson发表于的[Method Swizzling](http://nshipster.com/method-swizzling/)一文。

这个方法可能是我们接触到Runtime最多的一个东西了。它可以通过Runtime的API实现更改任意的方法，理论上可以在运行时通过类名/方法名hook到任何 OC 方法，替换任何类的实现以及新增任意类。实现的最多的就是关于AOP埋点的方法了。
我们在给定的选择子名称相对的方法在运行期改变，这种方法叫“方法调配”（method swizzling）。
类的方法列表会把选择子的名称映射到相关的方法实现上，是的“动态消息派发系统”能够据此找到应该调用的方法。这些方法以函数指针的方法表示，这种指针叫做IMP，原型如下：

```
id (*IMP)(id,SEL,...)
```
我们要实现方法互换，需要以下方法

```
//交换方法实现
void method_exchangeImplementations(Method m1,Method m2)
//取出对应方法
Method class_getInstanceMethod(Class aClass,SEL aSelector)
```
看起来没有什么用处，但是结合添加方法和category，就可以达到让人意想不到的效果。
在category中添加一个方法，与原本的方法互换，就会达到调用的效果。
**注意**

> **Swizzling应该总是在+load中执行**
在Objective-C中，运行时会自动调用每个类的两个方法。`+load`会在类初始加载时调用，`+initialize`会在第一次调用类的类方法或实例方法之前被调用。这两个方法是可选的，且只有在实现了它们时才会被调用。由于`method swizzling`会影响到类的全局状态，因此要尽量避免在并发处理中出现竞争的情况。`+load`能保证在类的初始化过程中被加载，并保证这种改变应用级别的行为的一致性。相比之下，`+initialize`在其执行时不提供这种保证–事实上，如果在应用中没为给这个类发送消息，则它可能永远不会被调用。
 **Swizzling应该总是在dispatch_once中执行**
与上面相同，因为`swizzling`会改变全局状态，所以我们需要在运行时采取一些预防措施。原子性就是这样一种措施，它确保代码只被执行一次，不管有多少个线程。GCD的`dispatch_once`可以确保这种行为，我们应该将其作为`method swizzling`的最佳实践。

## 实践
这里的实践太多了，我简单的介绍几个：
#### 1.崩溃阻拦及统计
比如说数组越界，button的点击方法未实现等等，我们可以使用关联对象和消息转发等功能。为了防止数组越界，我们可以在分类中替换掉**objectAtIndex**方法，并做出保护处理；在button的点击方法未实现时，在调用**- (id)forwardingTargetForSelector:(SEL)aSelector**方法做出报警。
#### 2.兼容版本
总所周知，我们经常会遇到用户手机版本过低导致的新方法不兼容，我们往往还要在代码中加上版本判断。
这里我们依然可以使用**- (id)forwardingTargetForSelector:(SEL)aSelector**方法，判断在新方法未实现是，直接调用老版本方法。
#### 3.模拟多继承
![](http://upload-images.jianshu.io/upload_images/1342490-722dfac6a1fd23c3?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
在上图中，一个对象对一个消息做出回应，类似于另一个对象中的方法借过来或是“继承”过来一样。 在图中，warrior实例转发了一个negotiate消息到Diplomat实例中，执行Diplomat中的negotiate方法，结果看起来像是warrior实例执行了一个和Diplomat实例一样的negotiate方法，其实执行者还是Diplomat实例。
消息转发提供了许多类似于多继承的特性，但是他们之间有一个很大的不同：
> 多继承：合并了不同的行为特征在一个单独的对象中，会得到一个重量级多层面的对象。
消息转发：将各个功能分散到不同的对象中，得到的一些轻量级的对象，这些对象通过消息通过消息转发联合起来。

这里值得说明的一点是，即使我们利用转发消息来实现了“假”继承，但是NSObject类还是会将两者区分开。像respondsToSelector:和 isKindOfClass:这类方法只会考虑继承体系，不会考虑转发链。

#### 4.给分类添加属性
这个就不多说了，算的上我们普遍用到的方法了

#### 5.给UIControl添加方法
我们可以利用这个方法给button添加block以实现类似于RAC的效果。
```
#import <UIKit/UIKit.h>
#import <objc/runtime.h>    // 导入头文件
// 声明一个button点击事件的回调block
typedef void(^ButtonClickCallBack)(UIButton *button);
@interface UIButton (Handle)
// 为UIButton增加的回调方法
- (void)handleClickCallBack:(ButtonClickCallBack)callBack;
@end

#import "UIButton+Handle.h"
// 声明一个静态的索引key，用于获取被关联对象的值
static char *buttonClickKey;
@implementation UIButton (Handle)
- (void)handleClickCallBack:(ButtonClickCallBack)callBack {
    // 将button的实例与回调的block通过索引key进行关联：
    objc_setAssociatedObject(self, &buttonClickKey, callBack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 设置button执行的方法
    [self addTarget:self action:@selector(buttonClicked) forControlEvents:UIControlEventTouchUpInside];
}

- (void)buttonClicked {
    // 通过静态的索引key，获取被关联对象（这里就是回调的block）
    ButtonClickCallBack callBack = objc_getAssociatedObject(self, &buttonClickKey);
    
    if (callBack) {
        callBack(self);
    }
}
@end
```
我们利用这个方法给button添加了一个block。有名的[BlockKit](https://github.com/BlocksKit/BlocksKit)就是用相关方法实现的。

#### 6.SDWebImage中设置缓存

```
- (SDOperationsDictionary *)sd_operationDictionary {
    @synchronized(self) {
        SDOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
        if (operations) {
            return operations;
        }
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}
```
#### 7.KVO&KVC

> Automatic key-value observing is implemented using a technique called *isa-swizzling*.
The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
You should never rely on the isa pointer to determine class membership. Instead, you should use the [class](https://link.jianshu.com?t=https://developer.apple.com/reference/objectivec/1418956-nsobject/1571949-class) method to determine the class of an object instance.


这个不多说了，篇幅不够，不过相关资料很多。

#### 8.埋点
这个算的上重中之重了。
我们可以通过添加一个分类，交换掉一些我们想要了解的东西。比如 **didAppear**， button的touch，tableview的点击等等方法。通过交换，我们将数据保存下来，并发送给后台。

#### 9.AOP
有个很有名的第三方库[Aspects](https://github.com/steipete/Aspects),实现了AOP。我们可以利用这个，处理一些散落在app各处，但又必须处理的一些统一方法，比如说身份验证，header。当然，我们也可以用它来埋点。

#### 10.字典模型互换
> 1. 调用 **class_getProperty** 方法获取当前 Model 的所有属性。
> 2. 调用 **property_copyAttributeList** 获取属性列表。
> 3. 根据属性名称生成 **setter**方法。
> 4. 使用 **objc_msgSend** 调用 setter 方法为 Model 的属性赋值（或者 KVC）



----------
首次：170916		 
修改：180106
