#   Threading Programming Guide(四)：线程安全和有关词汇
## Cocoa
从多个线程使用可可的准则包括：

* 不可变对象通常是线程安全的。创建它们之后，就可以安全地在线程之间传递这些对象。另一方面，可变对象通常不是线程安全的。要在线程应用程序中使用可变对象，应用程序必须适当地同步。有关更多信息，请参见可变与不可变。
* 许多被认为“线程不安全”的对象仅在多个线程中使用是不安全的。只要一次仅一个线程，就可以从任何线程使用许多这些对象。专门调出应用程序主线程的对象就这样被调出。
* 应用程序的主线程负责处理事件。尽管如果事件路径中包含其他线程，Application Kit仍可以继续工作，但是操作可能会不按顺序进行。
* 如果要使用线程绘制视图，请在的lockFocusIfCanDraw和unlockFocus方法之间将所有绘制代码​​括在括号中NSView。
* 要将POSIX线程与Cocoa一起使用，必须首先将Cocoa置于多线程模式。有关更多信息，请参见在Cocoa应用程序中使用POSIX线程。

### 基础框架线程安全
有一个误解，认为Foundation框架是线程安全的，而Application Kit框架不是。不幸的是，这是一个粗略的概括并且有些误导。每个框架都有线程安全的区域和不是线程安全的区域。以下各节描述了Foundation框架的一般线程安全性。

#### 线程安全的类和函数
以下类和函数通常被认为是线程安全的。您可以从多个线程使用同一实例，而无需先获取锁。
> NSArray
NSAssertionHandler
NSAttributedString
NSBundle
NSCalendar
NSCalendarDate
NSCharacterSet
NSConditionLock
NSConnection
NSData
NSDate
NSDateFormatter
NSDecimal 功能
NSDecimalNumber
NSDecimalNumberHandler
NSDeserializer
NSDictionary
NSDistantObject
NSDistributedLock
NSDistributedNotificationCenter
NSException
NSFileManager
NSFormatter
NSHost
NSJSONSerialization
NSLock
NSLog/NSLogv
NSMethodSignature
NSNotification
NSNotificationCenter
NSNumber
NSNumberFormatter
NSObject
NSOrderedSet
NSPortCoder
NSPortMessage
NSPortNameServer
NSProgress
NSProtocolChecker
NSProxy
NSRecursiveLock
NSSet
NSString
NSThread
NSTimer
NSTimeZone
NSUserDefaults
NSValue
NSXMLParser
ARC/MRC
内存函数

#### 线程不安全类
以下类和函数通常不是线程安全的。在大多数情况下，您可以从任何线程使用这些类，只要一次仅从一个线程使用它们即可。检查类文档以获取更多详细信息。
> NSArchiver
NSAutoreleasePool
NSCoder
NSCountedSet
NSEnumerator
NSFileHandle
NSHashTable 功能
NSInvocation
NSMapTable 功能
NSMutableArray
NSMutableAttributedString
NSMutableCharacterSet
NSMutableData
NSMutableDictionary
NSMutableOrderedSet
NSMutableSet
NSMutableString
NSNotificationQueue
NSPipe
NSPort
NSProcessInfo
NSRunLoop
NSScanner
NSSerializer
NSTask
NSUnarchiver
NSUndoManager
用户名和主目录功能

请注意，尽管NSArchiver，NSCoder和NSEnumerator对象本身都是线程安全的，但在此处列出它们是因为在使用它们时更改由它们包装的数据对象并不安全。例如，对于归档器，更改要归档的对象图是不安全的。对于枚举，任何线程更改枚举集合都是不安全的。

#### 仅主线程类
只能在应用程序的主线程中使用以下类。

> NSAppleScript

#### 可变与不可变
不变的对象通常是线程安全的；创建它们之后，就可以安全地在线程之间传递这些对象。当然，当使用不可变对象时，您仍然需要记住正确使用引用计数。如果不当释放了一个未保留的对象，则稍后可能会导致异常。

可变对象通常不是线程安全的。要在线程应用程序中使用可变对象，应用程序必须使用锁同步对它们的访问。（有关更多信息，请参阅原子操作）。通常，当涉及到突变时，收集类（例如NSMutableArray，NSMutableDictionary）不是线程安全的。也就是说，如果一个或多个线程正在更改同一阵列，则可能会出现问题。您必须锁定发生读写的地方，以确保线程安全。

即使某个方法声称要返回一个不可变的对象，您也绝不能简单地假设返回的对象是不可变的。根据方法的实现，返回的对象可能是可变的或不可变的。例如，返回类型为的方法NSString可能会NSMutableString由于其实现而实际上返回a 。如果要保证所拥有的对象是不可变的，则应制作不可变的副本。

#### 再入
只有在操作“调出”同一对象或不同对象上的其他操作的情况下，才可以重入。保留和释放物体是一种有时被忽略的“召唤”。

下表列出了Foundation框架中明确可重入的部分。所有其他类别可能会也可能不会重入，或者将来可能会重入。尚未对折返进行完整的分析，此列表可能并不详尽。

> 分布式对象
NSConditionLock
NSDistributedLock
NSLock
NSLog/NSLogv
NSNotificationCenter
NSRecursiveLock
NSRunLoop
NSUserDefaults

#### 类初始化
Objective-C运行时系统发送一个 initialize在类收到任何其他消息之前，向每个类对象发送消息。这使该类有机会设置其运行时环境在使用之前。在多线程应用程序中，运行时保证只有一个线程（恰好将第一条消息发送给类的线程）执行该initialize方法。如果在第一个线程仍在该initialize方法中时第二个线程尝试向该类发送消息，则第二个线程将阻塞直到该initialize方法完成执行。同时，第一个线程可以继续调用该类上的其他方法。该initialize方法不应依赖于该类的第二个线程调用方法。如果是这样，则两个线程将陷入僵局。

由于OS X版本10.1.x和更早版本中的错误，一个线程可以在另一个线程完成执行该类的initialize方法之前将消息发送给该类。然后，线程可以访问尚未完全初始化的值，这可能会使应用程序崩溃。如果遇到此问题，则需要引入锁以防止在初始化值之前访问值，或者强制类在成为多线程之前对其进行初始化。

#### 自动释放池
每个线程维护自己的NSAutoreleasePool对象堆栈。Cocoa希望在当前线程的堆栈上始终有一个自动释放池。如果池不可用，则不会释放对象，并且会泄漏内存。一个NSAutoreleasePool对象会自动创建并在基于应用程序套件应用的主线程摧毁，但辅助线程（和函数应用）必须在使用前，Cocoa创建自己的。如果您的线程是长期存在的，并可能生成许多自动释放的对象，您应该定期销毁并创建自动释放池（就像Application Kit在主线程上一样）；否则，自动释放的对象会堆积，并且您的内存占用也会增加。如果分离的线程不使用Cocoa，则无需创建自动释放池。

#### RunLoop
每个线程只有一个RunLoop。但是，每个运行循环以及每个线程都有自己的一组输入模式，这些输入模式确定运行RunLoop时侦听哪些输入源。一个RunLoop中定义的输入模式不会影响另一个RunLoop中定义的输入模式，即使它们的名称相同。

如果您的应用程序基于Application Kit，则主线程的RunLoop将自动运行，但是辅助线程（和仅基金会的应用程序）必须自己运行RunLoop。如果分离的线程未进入RunLoop，则该线程将在分离的方法完成执行后立即退出。

尽管有一些外表，但NSRunLoop该类不是线程安全的。您只能从拥有它的线程中调用此类的实例方法。

### 应用套件框架线程安全
以下各节描述了Application Kit框架的一般线程安全性。

#### 线程不安全类

以下类和函数通常不是线程安全的。在大多数情况下，您可以从任何线程使用这些类，只要一次仅从一个线程使用它们即可。检查类文档以获取更多详细信息。

NSGraphicsContext。
NSImage
NSResponder
NSWindow及其所有后代。

#### 仅主线程类
只能在应用程序的主线程中使用以下类。
* NSCell 及其所有后代
* NSView及其所有后代。

#### 窗口限制
您可以在辅助线程上创建一个窗口。应用程序包确保与窗口关联的数据结构在主线程上被重新分配，以避免出现竞争情况。窗口对象可能会在同时处理大量窗口的应用程序中泄漏。

您可以在辅助线程上创建模式窗口。当主线程运行模式循环时，应用程序工具包将阻止正在调用的辅助线程。


#### 事件处理限制
应用程序的主线程负责处理事件。主线程是的run方法中被阻塞的线程NSApplication，通常在应用程序的main函数中调用。如果事件路径中涉及其他线程，则Application Kit继续工作时，操作可能会不按顺序进行。例如，如果两个不同的线程正在响应按键事件，则可能会乱序接收按键。通过让主线程处理事件，您可以获得更一致的用户体验。接收到事件后，如果需要，可以将事件调度到辅助线程进行进一步处理。

您可以从辅助线程调用postEvent:atStart:方法，NSApplication以将事件发布到主线程的事件队列中。但是，不能保证有关用户输入事件的顺序。应用程序的主线程仍负责处理事件队列中的事件。


#### 绘图限制
使用其图形功能和类（包括NSBezierPath和NSString类）进行绘制时，Application Kit通常是线程安全的。以下各节介绍了使用特定类的详细信息。
##### NSView限制
该NSView班通常不是线程安全的。您NSView仅应从应用程序的主线程创建，销毁，调整大小，移动对象并执行其他操作。从辅助线程进行绘图是线程安全的，只要将绘图调用与lockFocusIfCanDraw 和 unlockFocus。

如果一个应用程序的一个次级线程想要使视图的部分是主要的线程上重新绘制，它必须这样做使用的方法，如display，setNeedsDisplay:，setNeedsDisplayInRect:，或setViewsNeedDisplay:。相反，它应该向主线程发送一条消息，或使用performSelectorOnMainThread:withObject:waitUntilDone: 方法代替。

视图系统的图形状态（gstates）是每个线程的。使用图形状态曾经是在单线程应用程序上获得更好绘图性能的一种方式，但是现在不再如此。错误使用图形状态实际上会导致绘制代码的效率低于在主线程中绘制的效率。
##### NSGraphicsContext限制
该NSGraphicsContext班表示基础图形系统提供的绘图上下文。每个NSGraphicsContext实例都拥有自己独立的图形状态：坐标系，剪辑，当前字体等。在每个NSWindow实例的主线程上自动创建该类的实例。如果您从辅助线程进行任何绘图，NSGraphicsContext则会专门为该线程创建一个新的实例。

如果从辅助线程进行任何绘图，则必须手动刷新绘图调用。Cocoa不会自动使用从辅助线程绘制的内容来更新视图，因此您需要在完成绘制时调用flushGraphics方法NSGraphicsContext。如果您的应用程序仅从主线程绘制内容，则无需刷新绘制调用。
##### NSImage限制
一个线程可以创建一个NSImage对象，绘制到图像缓冲区，然后将其传递给主线程进行绘制。基础图像缓存在所有线程之间共享。





### Core Data Framework
尽管有一些使用注意事项，但Core Data框架通常支持线程化。有关这些警告信息，请参阅并发与核心数据的[CoreDate编程指南](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/index.html#//apple_ref/doc/uid/TP40001075)。


## Core Foundation
Core Foundation具有足够的线程安全性，因此，如果谨慎编程，就不会遇到与竞争线程有关的任何问题。在常见情况下，例如查询，保留，释放和传递不可变对象时，它是线程安全的。即使是可能从多个线程中查询的中央共享对象，也是可靠的线程安全的。

像Cocoa一样，当涉及对象或其内容的突变时，Core Foundation也不是线程安全的。例如，正如您可能期望的那样，修改可变数据或可变数组对象不是线程安全的，但修改不可变数组内部的对象也不是线程安全的。原因之一就是性能，这在这些情况下至关重要。此外，通常无法在此级别上实现绝对线程安全。例如，您不能排除由于保留从集合中获取的对象而导致的不确定行为。在进行调用以保留包含的对象之前，可能会释放集合本身。

在要从多个线程访问和变异的Core Foundation对象的情况下，您的代码应通过在访问点使用锁来防止同时访问。例如，枚举Core Foundation数组对象的代码应在枚举块周围使用适当的锁定调用，以防止其他人更改该数组。

## 词汇表
> * **application-应用**  
    一种特定的程序样式，向用户显示图形界面。

> * **condition-条件**  
    用于同步对资源的访问的构造。在其他条件明确指示条件之前，不允许等待条件的线程继续进行。

> * **critical section**  
    一次只能由一个线程执行的一部分代码。

> * **input source-输入源**  
    线程的异步事件的源。输入源可以基于端口或手动触发，并且必须附加到线程的运行循环中。

> * **joinable thread-可连接线程**
    终止后不会立即回收其资源的线程。必须先显式地分离可连接线程，否则必须由另一个线程将其连接，才能回收资源。可连接线程为与它们连接的线程提供返回值。

> * **main thread-主线程** 
    创建其拥有进程时创建的一种特殊类型的线程。当程序的主线程退出时，该过程结束。

> * **mutex-互斥**
    提供互斥访问共享资源的锁。互斥锁一次只能由一个线程持有。尝试获取由其他线程持有的互斥锁会使当前线程进入休眠状态，直到最终获取该锁为止。

> * **operation object -操作对象**  
    NSOperation类的实例。操作对象将与任务关联的代码和数据包装到可执行单元中。

> * **operation queue-操作队列**  
    NSOperationQueue类的实例。操作队列管理操作对象的执行。

> * **process-处理**  
    应用程序或程序的运行时实例。进程具有自己的虚拟内存空间和系统资源（包括端口权限），与分配给其他程序的资源无关。一个进程始终至少包含一个线程（主线程），并且可以包含任意数量的附加线程。

> * **program-程序**  
    可以运行代码和资源以执行某些任务的组合。程序无需具有图形用户界面，尽管图形应用程序也被视为程序。

> * **recursive lock-递归锁**  
    可以由同一线程多次锁定的锁。

> * **run loop**  
    事件处理循环，在此循环中，事件被接收并调度到适当的处理程序。

> * **RunLoopMode**  
    与特定名称关联的输入源，计时器源和运行循环观察器的集合。当以特定的“模式”运行时，运行循环仅监视与该模式关联的源和观察者。

> * **RunLoop对象** 
    NSRunLoop类或CFRunLoopRef不透明类型的实例。这些对象提供了用于在线程中实现事件处理循环的接口。

> * **RunLoop观察者**  
    运行循环执行的不同阶段中的通知的接收者。

> * **semaphore-信号**  
    受保护的变量，用于限制对共享资源的访问。互斥量和条件都是信号灯的不同类型。

> * **task-任务**  
    要执行的工作量。

> * **thread-线程**  
    流程中的执行流程。每个线程都有自己的堆栈空间，但在同一进程中与其他线程共享内存。

> * **timer source-计时器源**  
    线程的同步事件的源。计时器在预定的将来时间生成一次或重复事件。


