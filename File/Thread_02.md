#   Threading Programming Guide(三)：同步

目录：
* [Threading Programming Guide(一)：线程和线程管理](https://github.com/BiBoyang/Study/blob/master/File/Thread_00.md)
* [Threading Programming Guide(二)：RunLoop](https://github.com/BiBoyang/Study/blob/master/File/Thread_01.md)
* [Threading Programming Guide(三)：同步](https://github.com/BiBoyang/Study/blob/master/File/Thread_02.md)
* [Threading Programming Guide(四)：线程安全和有关词汇](https://github.com/BiBoyang/Study/blob/master/File/Thread_03.md)

应用程序中存在多个线程,带来了与从多个执行线程安全访问资源的潜在问题。修改同一资源的两个线程可能会以意想不到的方式相互干扰。例如，一个线程可能会覆盖另一个线程的更改，或者将应用程序置于未知且可能无效的状态。如果幸运的话，损坏的资源可能会导致明显的性能问题或崩溃，这些问题相对容易跟踪和修复。但是，如果您不走运，损坏可能会导致细微的错误，直到很久以后才会显现出来，或者这些错误可能需要对代码进行重大检查。

在线程安全方面，好的设计是您拥有的最佳保护。避免共享资源并最小化线程之间的交互，使这些线程相互干扰的可能性降低。但是，并非总是可以实现完全无干扰的设计。如果您的线程必须进行交互，则需要使用同步工具来确保它们在交互时安全地进行交互。

OS X和iOS提供了许多同步工具供您使用，从提供互斥访问的工具到在应用程序中正确排序事件的工具。以下各节描述了这些工具以及如何在代码中使用它们以影响对程序资源的安全访问。

## 同步工具
为了防止不同的线程意外更改数据，可以将应用程序设计为不存在同步问题，也可以使用同步工具。
尽管最好方案是完全避免同步问题，但这并不总是可能的。以下各节介绍了可供您使用的同步工具的基本类别。

### 原子操作
原子操作是一种简单的同步形式，适用于简单的数据类型。原子操作的优点是它们不会阻塞竞争线程。对于简单的操作（例如增加计数器变量），这比使用锁可以带来更好的性能。

OS X和iOS包含许多操作，可以对32位和64位值执行基本的数学和逻辑运算。这些操作包括比较和交换，测试和设置以及测试和清除操作的原子版本。有关受支持的原子操作的列表，请参见/usr/include/libkern/OSAtomic.h头文件或[atomic手册](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/atomic.3.html#//apple_ref/doc/man/3/atomic)。

### 内存屏障和 Volatile 变量

为了获得最佳性能，编译器经常对汇编级指令进行重新排序，以使处理器的指令流水线尽可能完整。作为此优化的一部分，当编译器认为这样做不会产生不正确的数据时，可能会对访问主内存的指令进行重新排序。不幸的是，编译器并非总是能够检测到所有与内存相关的操作。如果看似独立的变量实际上相互影响，则编译器优化可能会以错误的顺序更新这些变量，从而产生可能不正确的结果。

内存屏障是一种非阻塞同步工具，用于确保内存操作以正确的顺序发生。内存屏障的作用类似于栅栏，强制处理器在栅栏之前的所有读写操作都执行后才可以开始执行栅栏之后的操作。内存屏障通常用于确保一个线程（但另一线程可见）的内存操作始终按预期的顺序发生。在这种情况下缺少内存屏障可能会使其他线程看到看似不可能的结果。（有关示例，请参阅Wikipedia条目中的[内存屏障](https://en.wikipedia.org/wiki/Memory_barrier)。）要使用内存障碍，只需`OSMemoryBarrier`在代码中的适当位置调用该函数。

`Volatile`将另一种类型的内存约束应用于单个变量。编译器通常通过将变量的值加载到寄存器中来优化代码。对于局部变量，这通常不是问题。但是，如果从另一个线程可见该变量，则这种优化可能会阻止另一个线程注意到对该变量的任何更改。将volatile关键字应用于变量会强制编译器每次使用时从内存中加载该变量。您可以声明一个变量，volatile好像它的值可以随时被编译器可能无法检测到的外部源更改一样。

由于内存屏障和易失性变量都会**减少编译器可执行的优化次数**，因此应谨慎使用它们，仅在需要确保正确性的地方使用它们。

### 锁
锁是最常用的同步工具之一。您可以使用锁来保护代码的关键部分，这是一段代码，一次只能允许一个线程访问。例如，关键部分可能操纵特定的数据结构或一次使用最多支持一个客户端的某些资源。通过在此部分周围加锁，可以排除其他线程进行可能影响代码正确性的更改。
下表列出了程序员常用的一些锁。OS X和iOS提供了大多数此类锁类型的实现，但并非全部。对于不受支持的锁类型，描述列说明了未在平台上直接实现这些锁的原因。

|  锁 | 描述  |
|---|---|
| 互斥锁  | 互斥（或互斥）锁充当资源周围的保护性屏障。互斥锁是一种信号量，它一次只能授予对一个线程的访问权限。如果正在使用互斥锁，而另一个线程试图获取该互斥锁，则该线程将阻塞，直到该互斥锁被其原始持有者释放为止。如果多个线程竞争同一个互斥锁，则一次只能访问一个。  |
| 递归锁  |  递归锁是互斥锁的一种变体。递归锁允许单个线程在释放它之前多次获取该锁。其他线程将保持阻塞状态，直到锁的所有者以与获取锁相同的次数释放锁。递归锁主要在递归迭代期间使用，但也可以在多个方法各自需要分别获取锁的情况下使用。 |
|  读写锁 | 读写锁也称为共享独占锁。这种类型的锁通常用于较大规模的操作，如果经常读取受保护的数据结构并仅偶尔进行修改，则可以显着提高性能。在正常操作期间，多个读取器可以同时访问数据结构。但是，当线程要写入结构时，它将阻塞，直到所有读取器都释放锁为止，此时，它获取了锁并可以更新结构。当写入线程正在等待锁定时，新的读取器线程将阻塞，直到写入线程完成。系统仅支持使用POSIX线程的读写锁。  |
|分布式锁| 分布式锁在进程级别提供互斥访问。与真正的互斥锁不同，分布式锁不会阻止进程或阻止其运行。它仅报告锁何时繁忙，并让进程决定如何进行。  |
|自旋锁   |  自旋锁反复轮询其锁定条件，直到该条件变为true。自旋锁最常用于多处理器系统，其中锁的预期等待时间很小。在这些情况下，轮询通常比阻塞线程更有效，这需要上下文切换和线程数据结构的更新。由于它们具有轮询性质，因此系统不提供自旋锁的任何实现，但是您可以在特定情况下轻松地实现它们。 |
|双重检查锁| 双重检查锁是通过在获取锁之前测试锁定条件来减少获取锁的开销的尝试。由于双重检查的锁可能不安全，因此系统不会为它们提供明确的支持，因此不建议使用它们。|

> 注意：大多数类型的锁还包含一个内存屏障，以确保在进入关键部分之前完成所有先前的装载和存储指令。

### 条件
Condition是信号量的另一种类型，当某个条件为真时，它允许线程彼此发信号。Condition通常用于指示资源的可用性或确保任务以特定顺序执行。当线程测试条件时，除非该条件已经为true，否则它将阻塞。它保持阻塞状态，直到其他线程显式更改并发出条件信号为止。条件和互斥锁之间的区别在于，可以允许多个线程同时访问该条件。条件更像是一个根据某些指定的标准筛选线程的门卫。

使用条件的一种方法是管理事件池。当事件队列中有事件时，事件队列将使用条件变量来通知等待线程。如果一个事件到达，则队列将适当地发出条件信号。如果一个线程已经在等待，它将被唤醒，随后它将把事件从队列中拉出并进行处理。如果两个事件几乎同时进入队列，则队列将两次发出信号通知状态以唤醒两个线程。

### Perform Selector
Cocoa应用程序有一种以同步方式将消息传递到单个线程的便捷方法，一个在NSObject类声明对应用程序的活动线程的一个进行选择的方法。这些方法使您的线程可以异步传递消息，并确保它们将由目标线程同步执行。例如，您可以使用执行选择器消息将结果从分布式计算传递到应用程序的主线程或指定的协调器线程。每个执行选择器的请求都在目标线程的RunLoop中排队，然后按照接收顺序对请求进行顺序处理。

## 同步成本和性能
同步有助于确保代码的正确性，但这样做会牺牲性能。即使在没有竞争的情况下，使用同步工具也会带来延迟。锁和原子操作为了确保充分的保护代码，通常要使用内存屏障和内核级同步。如果存在争用锁的情况，您的线程可能会阻塞并经历更大的延迟。

下表列出了在无争议的情况下与互斥锁和原子操作相关的一些近似成本。这些测量值代表了数千个样本的平均时间。但是，与线程创建时间一样，互斥锁获取时间（即使在无争议的情况下）也可能因处理器负载，计算机速度以及可用系统和程序内存量的不同而有很大差异。

|项目|大致消耗|描述|
|---|---|---|
|互斥体获取时间|约0.2微秒|这是无争议情况下的锁获取时间。如果该锁由另一个线程持有，则获取时间可能会更长。这些数字是通过分析在基于Intel的iMac（具有2 GHz Core Duo处理器和1 GB运行OS X v10.5的RAM）上的互斥锁获取期间生成的平均值和中值确定的。|
|原子比较和交换|约0.05微秒|这是无争议情况下的比较和交换时间。这些数字是通过分析操作的平均值和中值确定的，是在基于Intel的iMac上生成的，该iMac具有2 GHz Core Duo处理器和1 GB运行OS X v10.5的RAM。|

在设计并发任务时，正确性始终是最重要的因素，但是您也应该考虑性能因素。如果在多个线程下可以正确执行的代码，比在单个线程上运行的相同代码还慢，那就几乎没有改进的意义了。

如果要翻新现有的单线程应用程序，则应始终对关键任务的性能进行测量。添加其他线程后，您应该对那些相同的任务进行新的测量，并将多线程案例与单线程案例的性能进行比较。如果在调整代码后，线程无法改善性能，则您可能需要重新考虑特定的实现或完全使用线程。

有关性能和用于收集指标的工具的信息，请参阅[性能概述](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/PerformanceOverview/Introduction/Introduction.html#//apple_ref/doc/uid/TP40001410)。


## 线程安全和信号
对于线程化应用程序，没有什么比处理信号（signal）问题引起更多的恐惧或困惑了。信号是一种底层BSD机制，可用于将信息传递给进程或以某种方式操纵它。一些程序使用信号来检测某些事件，例如子进程的死亡。系统使用信号终止失控过程并传达其他类型的信息。

信号的问题不是它们的作用，而是应用程序具有多个线程时的行为。在单线程应用程序中，所有信号处理程序都在主线程上运行。在多线程应用程序中，与特定硬件错误（例如非法指令）无关的信号将传递到当时正在运行的任何线程。如果同时运行多个线程，则将信号传递给系统碰巧的任何一个。换句话说，信号可以传递到应用程序的任何线程。

在应用程序中实现信号处理程序的第一条规则是避免假设哪个线程正在处理信号。如果特定线程要处理给定的信号，则需要制定某种方法在信号到达时通知该线程。您不能仅仅假设从该线程安装信号处理程序将导致信号传递到同一线程。

## 线程安全设计技巧
同步工具是使代码线程安全的一种有用方法，但不是万能药。与非线程性能相比，使用过多的锁和其他类型的同步原语实际上会降低应用程序的线程性能。在安全和性能之间找到合适的平衡是一门需要经验的艺术。以下各节提供了一些技巧，以帮助您为应用程序选择适当的同步级别。

### 完全避免同步
对于您正在从事的任何新项目，甚至对于现有项目，设计代码和数据结构来避免需要同步都是最佳的解决方案。尽管锁和其他同步工具很有用，但它们确实会影响任何应用程序的性能。而且，如果设计导致特定资源之间的竞争较高，则您的线程可能会等待更长的时间。

实施并发的最好方法是减少并发任务之间的交互和相互依赖性。如果每个任务都在其自己的私有数据集上运行，则无需使用锁来保护该数据。即使在两个任务确实共享一个公共数据集的情况下，您也可以查看对该集进行分区的方式或为每个任务提供自己的副本。当然，复制数据集也有其成本，因此在做出决定之前，您必须权衡这些成本和同步成本。


### 理解同步的限制
同步工具仅在应用程序中的所有线程一致使用时才有效。如果创建互斥量以限制对特定资源的访问，则所有线程在尝试操作该资源之前必须获取相同的互斥量。否则会破坏互斥锁提供的保护，这是程序员的错误。

### 注意代码正确性的风险
使用锁和内存屏障时，应始终仔细考虑它们在代码中的位置。即使是看似位置正确的锁，实际上也会使您陷入一种错误的安全感。以下一系列示例试图通过指出看似无害的代码中的缺陷来说明这个问题。基本前提是您具有一个包含一组不可变对象的可变数组。假设您要调用数组中第一个对象的方法。您可以使用以下代码进行操作：

```C++
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[arrayLock unlock];
 
[anObject doSomething];
```
由于数组是可变的，因此数组周围的锁可防止其他线程修改数组，直到获得所需的对象为止。并且由于您检索的对象本身是不可变的，因此`doSomething`并不需要锁。

但是，前面的示例存在问题。如果释放锁并有另一个线程进入并从数组中删除所有对象，然后才有可能执行该`doSomething`方法，会发生什么？在没有垃圾回收的应用程序中，可以释放代码所持有的对象，而anObject指向无效的内存地址。要解决此问题，您可以决定简单地重新排列现有代码，并在调用后释放锁doSomething，如下所示：

```C++
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[anObject doSomething];
[arrayLock unlock];
```
通过doSomething在锁内移动调用，您的代码可确保在调用该方法时该对象仍然有效。不幸的是，如果该doSomething方法花费很长时间执行，则可能导致您的代码长时间保持锁定，这可能会导致性能瓶颈。

代码的问题不是关键区域定义不正确，而是实际问题未被理解。真正的问题是仅由其他线程的存在触发的内存管理问题。因为它可以被另一个线程释放，所以更好的解决方案是anObject在释放锁之前保留它。该解决方案解决了对象被释放的实际问题，并且这样做不会造成潜在的性能损失。
```C++
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[anObject retain];
[arrayLock unlock];
 
[anObject doSomething];
[anObject release];
```
尽管以上示例本质上非常简单，但是它们确实说明了非常重要的一点。当涉及到正确性时，您必须超越明显的问题进行思考。内存管理和设计的其他方面也可能会受到多个线程的影响，因此您必须预先考虑这些问题。另外，您应该始终假设编译器在安全方面会做最坏的事情。这种了解和警惕应有助于您避免潜在的问题，并确保您的代码正常运行。

### 注意死锁和活锁


活锁类似于死锁，当两个线程竞争同一组资源时发生。在活锁情况下，线程放弃其第一把锁，以尝试获取其第二把锁。一旦获得第二个锁，它将返回并尝试再次获取第一个锁。它之所以锁定，是因为它花费了所有时间释放一个锁并试图获取另一个锁，而不是进行任何实际工作。

避免出现死锁和活锁情况的最佳方法是一次只锁定一个。如果一次必须获取多个锁，则应确保其他线程不要尝试执行类似的操作。


### 正确地使用 Volatile 变量
如果您已经在使用互斥锁来保护代码部分，则不要自动假定您需要使用volatile关键字来保护该部分中的重要变量。互斥锁包括一个内存屏障，以确保正确地排序装入和存储操作。将volatile关键字添加到关键部分中的变量后，每次访问该值时都会强制将其从内存中加载。两种同步技术的组合在特定情况下可能是必需的，但也会导致明显的性能损失。如果仅互斥量足以保护变量，请省略volatile关键字。

同样重要的是，不要使用易失性变量来避免使用互斥体。通常，互斥锁和其他同步机制是比易失性变量更好的方法来保护数据结构的完整性。的volatile关键字仅确保一个变量被从存储器加载，而不是存储在寄存器中。它不能确保您的代码正确访问该变量。




## 使用原子操作
非阻塞同步可以执行某些类型的操作并且避免锁的开销。尽管锁是同步两个线程的有效方法，但是即使在无竞争的情况下，获取锁也是有代价的操作。相比之下，许多原子操作仅需花费一小部分时间即可完成，并且与锁一样有效。

原子运算使您可以对32位或64位值执行简单的数学和逻辑运算。这些操作依靠特殊的硬件指令（和可选的内存屏障）来确保给定的操作在再次访问受影响的内存之前完成。在多线程情况下，应始终使用包含内存屏障的原子操作来确保内存在线程之间正确同步。

[表](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW14)列出了可用的原子数学和逻辑运算以及相应的函数名称。这些函数都在/usr/include/libkern/OSAtomic.h头文件中声明，您还可以在其中找到完整的语法。这些功能的64位版本仅在64位进程中可用。

大多数原子函数的行为应相对简单明了，并具有您所期望的。但是，清单4-1显示了原子测试设置和比较交换操作的行为，这些操作稍微复杂一些。对OSAtomicTestAndSet函数的前三个调用说明了对整数值使用的位操作公式及其结果可能与您期望的不同。最后两个调用显示了该OSAtomicCompareAndSwap32函数的行为。在所有情况下，当没有其他线程在操纵这些值时，将在无争议的情况下调用这些函数。

```C++
int32_t  theValue = 0;
OSAtomicTestAndSet(0, &theValue);
// theValue is now 128.
 
theValue = 0;
OSAtomicTestAndSet(7, &theValue);
// theValue is now 1.
 
theValue = 0;
OSAtomicTestAndSet(15, &theValue)
// theValue is now 256.
 
OSAtomicCompareAndSwap32(256, 512, &theValue);
// theValue is now 512.
 
OSAtomicCompareAndSwap32(256, 1024, &theValue);
// theValue is still 512.
```

## 使用锁
锁是用于线程编程的基本同步工具。锁使您可以轻松保护大部分代码，从而可以确保该代码的正确性。OS X和iOS为所有应用程序类型提供基本互斥锁，并且Foundation框架为特殊情况定义了互斥锁的一些其他变体。以下各节说明如何使用这些锁类型中的几种。

### 使用POSIX互斥锁
POSIX互斥锁在任何应用程序中都非常易于使用。要创建互斥锁，您需要声明并初始化一个pthread_mutex_t结构。要锁定和解锁互斥锁，请使用pthread_mutex_lock 和 pthread_mutex_unlock功能。下面显示了初始化和使用POSIX线程互斥锁所需的基本代码。完成锁后，只需致电pthread_mutex_destroy 释放锁数据结构。

```C++
pthread_mutex_t mutex;
void MyInitFunction()
{
    pthread_mutex_init(&mutex, NULL);
}
 
void MyLockingFunction()
{
    pthread_mutex_lock(&mutex);
    // Do work.
    pthread_mutex_unlock(&mutex);
}
```

> 注意：前面的代码是一个简化的示例，旨在显示POSIX线程互斥函数的基本用法。您自己的代码应检查这些函数返回的错误代码并进行适当处理。

### 使用NSLock类

一个 NSLock对象为Cocoa应用程序实现基本互斥量。所有锁（包括NSLock）的接口实际上都是由NSLocking协议定义的，协议定义了lock和unlock方法。您可以像使用任何互斥锁一样使用这些方法来获取和释放锁。

除了标准的锁定行为外，NSLock该类还添加了`tryLock`和`lockBeforeDate:`方法。该tryLock方法尝试获取锁，但是如果锁不可用则不会阻塞；相反，该方法仅返回NO。如果未在指定的时间限制内获取锁，则该lockBeforeDate:方法尝试获取锁，但取消阻塞线程（并返回NO）。

下面的示例演示如何使用NSLock对象来协调视觉显示的更新，该视觉显示的数据是由多个线程计算的。如果线程无法立即获取锁，则仅继续执行计算，直到可以获取锁并更新显示。
```C++
BOOL moreToDo = YES;
NSLock *theLock = [[NSLock alloc] init];
...
while (moreToDo) {
    /* Do another increment of calculation */
    /* until there’s no more to do. */
    if ([theLock tryLock]) {
        /* Update display used by all threads. */
        [theLock unlock];
    }
}
```
### 使用@synchronized指令

使用`@synchronized`指令是在Objective-C代码中动态创建互斥锁的便捷方法。`@synchronized`指令执行任何其他互斥锁将执行的操作--防止不同的线程同时获取同一锁。但是，在这种情况下，您不必直接创建互斥量或锁定对象。相反，您只需将任何Objective-C对象用作锁定令牌，如以下示例所示：
```C++
- (void)myMethod:(id)anObj
{
    @synchronized(anObj)
    {
        // Everything between the braces is protected by the @synchronized directive.
    }
}
```
传递给`@synchronized`指令的对象是用于区分受保护块的唯一标识符。如果在两个不同的线程中执行上述方法，并在每个线程上为参数传递一个不同的对象，则每个线程将获得其锁并继续进行处理而不会被另一个线程阻塞。但是，如果在两种情况下都传递相同的对象，则其中一个线程将首先获取锁，而另一个线程将阻塞，直到第一个线程完成。

作为一种预防措施，`@synchronized`会向受保护的代码隐式添加一个异常处理程序。如果抛出异常，此处理程序将自动释放互斥量。这意味着，为了使用该`@synchronized`指令，还必须在代码中启用Objective-C异常处理。如果您不希望由隐式异常处理程序引起的额外开销，则应考虑使用锁类。

### 使用其他可可锁
#### 使用NSRecursiveLock对象

该NSRecursiveLock班定义一个锁，同一线程可以多次获取该锁，而不会导致线程死锁。每次成功获取锁，必须通过相应的调用来平衡以解锁该锁。仅当所有`lock`和`unlock`调用均达到平衡时，才实际释放该锁定，以便其他线程可以获取它。

顾名思义，这种类型的锁通常在递归函数内部使用，以防止递归阻塞线程。在非递归情况下，您可以类似地使用它来调用函数，这些函数的语义要求它们也具有锁定功能。这是一个简单的递归函数示例，该函数通过递归获取锁。

```C++
NSRecursiveLock *theLock = [[NSRecursiveLock alloc] init];
 
void MyRecursiveFunction(int value)
{
    [theLock lock];
    if (value != 0)
    {
        --value;
        MyRecursiveFunction(value);
    }
    [theLock unlock];
}
 
MyRecursiveFunction(5);
```
> 注意：因为在所有`lock`与`unlock`平衡之前不会释放递归锁定，所以您应该仔细权衡使用性能锁定的决定与潜在的性能影响。长时间持有任何锁都可能导致其他线程阻塞，直到递归完成为止。如果您可以重写代码以消除递归或不需要使用递归锁，则可能会获得更好的性能。

#### 使用NSConditionLock对象
一个NSConditionLock对象定义了一个互斥锁，该互斥锁可以使用特定的值进行lock和unlock。您不应将这种类型的锁与条件混淆。该行为在某种程度上类似于条件，但实现方式却大不相同。

通常，NSConditionLock当线程需要按特定顺序执行任务时（例如，当一个线程产生另一个线程消耗的数据时），您可以使用一个对象。生产者执行时，消费者使用特定于您的程序的条件来获取锁。（条件本身只是您定义的整数值。）生产者完成时，它将解锁锁，并将锁定条件设置为适当的整数值以唤醒使用者线程，然后消费者线程继续处理数据。

NSConditionLock对象响应的锁定和解锁方法可以任意组合使用。例如，您可以将一条lock消息与`unlockWithCondition:`或`lockWhenCondition:`的消息unlock。当然，后一种组合可以解锁该锁，但可能不会释放等待特定条件值的任何线程。

下面的示例显示如何使用条件锁来处理生产者－消费者问题。想象一个应用程序包含一个数据队列。生产者线程将数据添加到队列，而消费者线程从队列中提取数据。生产者不必等待特定的条件，但是必须等待锁可用，以便可以安全地将数据添加到队列中。

```C++
id condLock = [[NSConditionLock alloc] initWithCondition:NO_DATA];
 
while(true)
{
    [condLock lock];
    /* Add data to the queue. */
    [condLock unlockWithCondition:HAS_DATA];
}
```
因为锁的初始条件设置为`NO_DATA`，所以生产者线程应该在最初获取锁时没有任何麻烦。它用数据填充队列，并将条件设置为`HAS_DATA`。在后续迭代期间，生产者线程可以在到达时添加新数据，而不管队列是空还是仍有一些数据。它唯一阻止的时间是使用者线程从队列中提取数据。

因为使用者线程必须要处理数据，所以它使用特定条件在队列上等待。当生产者将数据放入队列时，消费者线程将唤醒并获取其锁。然后，它可以从队列中提取一些数据并更新队列状态。以下示例显示了使用者线程处理循环的基本结构。

```C++
while (true)
{
    [condLock lockWhenCondition:HAS_DATA];
    /* Remove data from the queue. */
    [condLock unlockWithCondition:(isEmpty ? NO_DATA : HAS_DATA)];
 
    // Process the data locally.
}

```
#### 使用NSDistributedLock对象

`NSDistributedLock`可以被多个主机上的多个应用程序用来限制对某些共享资源（例如文件）的访问。该锁本身实际上是使用文件系统项（如文件或目录）实现的互斥锁。为了使`NSDistributedLock`对象可用，该锁必须可由使用它的所有应用程序写入。这通常意味着将其放置在运行该应用程序的所有计算机都可以访问的文件系统上。

与其他类型的锁不同，`NSDistributedLock`它不符合`NSLocking`协议，因此没有lock方法。一种lock方法将阻止线程的执行，并要求系统以预定速率轮询锁。与其对您的代码强加惩罚，不如`NSDistributedLock`提供`tryLock`方法，让您决定是否要轮询。

因为它是使用文件系统实现的，所以`NSDistributedLock`除非所有者明确释放对象，否则不会释放对象。如果您的应用程序在持有分布式锁的同时崩溃，则其他客户端将无法访问受保护的资源。在这种情况下，您可以使用breakLock打破现有锁的方法，以便您可以获取它。但是，通常应该避免破坏锁，除非您确定拥有进程已死并且无法释放锁。

与其他类型的锁一样，使用`NSDistributedLock`完对象后，可以通过调用`unlock`方法来释放它。


## 使用条件（Condition）


条件是一种特殊类型的锁，可用于同步操作必须执行的顺序。它们与互斥锁有一个微妙的区别。等待某个条件的线程保持阻塞状态，直到`condition`被另一个线程显式发出信号为止。

由于实现操作系统所涉及的微妙之处，即使代码未真正发出条件锁，也允许伪造成功返回条件锁。为了避免由这些虚假信号引起的问题，您应始终将谓词与条件锁结合使用。谓词是确定线程继续执行是否安全的更具体方法。该条件只是让您的线程处于睡眠状态，直到可以由信令线程设置谓词为止。

以下各节说明如何在代码中使用条件。

### 使用NSCondition类
NSCondition类提供相同的语义POSIX的条件，但在单个对象包装二者所需的锁和条件数据结构。结果是可以像互斥锁一样锁定对象，然后像条件一样等待。

下面显示了一个代码片段，演示了等待NSCondition对象的事件序列。该`cocoaCondition`变量包含一个NSCondition对象，并且该`timeToDoWork`变量是一个整数，在发出该信号之前立即从另一个线程递增
```C++
[cocoaCondition lock];
while (timeToDoWork <= 0)
    [cocoaCondition wait];
 
timeToDoWork--;
 
// Do real work here.
 
[cocoaCondition unlock];
```
显示了用于发出可可条件信号并增加谓词变量的代码。您应该始终在发出信号之前锁定该条件。

```C++
[cocoaCondition lock];
timeToDoWork++;
[cocoaCondition signal];
[cocoaCondition unlock];

```


### 使用POSIX条件
POSIX线程条件锁需要同时使用条件数据结构和互斥量。尽管两个锁结构是分开的，但互斥锁在运行时与条件结构密切相关。等待信号的线程应始终一起使用相同的互斥锁和条件结构。更改配对会导致错误。

下面显示了条件和谓词的基本初始化和用法。在初始化条件和互斥锁之后，等待线程使用该`ready_to_go`变量作为其谓词进入while循环。仅当谓词已设置且随后发出条件通知时，等待线程才会唤醒并开始执行其工作。
```C++
pthread_mutex_t mutex;
pthread_cond_t condition;
Boolean     ready_to_go = true;
 
void MyCondInitFunction()
{
    pthread_mutex_init(&mutex);
    pthread_cond_init(&condition, NULL);
}
 
void MyWaitOnConditionFunction()
{
    // Lock the mutex.
    pthread_mutex_lock(&mutex);
 
    // If the predicate is already set, then the while loop is bypassed;
    // otherwise, the thread sleeps until the predicate is set.
    while(ready_to_go == false)
    {
        pthread_cond_wait(&condition, &mutex);
    }
 
    // Do work. (The mutex should stay locked.)
 
    // Reset the predicate and release the mutex.
    ready_to_go = false;
    pthread_mutex_unlock(&mutex);
}
```
信令线程既负责设置谓词，也负责将信号发送到条件锁。 下面显示了实现此行为的代码。在此示例中，条件在互斥锁内部发出信号，以防止在等待条件的线程之间发生竞争条件。

```C++
void SignalThreadUsingCondition()
{
    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(&mutex);
    ready_to_go = true;
 
    // Signal the other thread to begin work.
    pthread_cond_signal(&condition);
 
    pthread_mutex_unlock(&mutex);
}
```

> 注意：  前面的代码是一个简化的示例，旨在显示POSIX线程条件函数的基本用法。您自己的代码应检查这些函数返回的错误代码并进行适当处理。

