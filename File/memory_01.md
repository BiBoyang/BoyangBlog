# DEAD in iOS Memory 

# 虚拟内存的来由
一个系统中的进程是与其他进程共享CPU和主存资源的，最开始我们直接访问物理内存地址，但是后来我们发现会造成各种各样的问题：
> 1. **地址空间不隔离**   
 所有的进程都可以直接访问物理地址，那表明各个进程的内存空间不是互相隔离的。有些恶意的进程或者被注入恶意代码的进程非常容易去改写其他进程的内存数据，以达到破坏的目的。
> 2. **内存使用效率低**    
 由于没有有效的内存管理机制，需要一个程序执行时，会将整个程序装入内存中然后开始执行。如果我们这个时候突然想要运行另外一个程序，那么很可能遇到内存空间不足。这时候有一种处理方法是将其他程序的数据暂时写到磁盘里面，等到用的时候再读回来。由于程序所需要的空间是连续的，那么在这个方法里，如果我们将程序A换出到磁盘所释放的内存空间是不够的，所以接着会将程序B换出到磁盘，然后将程序C读入到内存开始运行。我们可以看出来，整个过程中有大量的数据在换入换出，导致效率十分低下。
> 3. **程序运行的地址不确定**  
    因为程序每次需要装入运行时，我们需要给它从内存中分配一块足够大的空闲区域，这个空闲区域的位置是不确定的。这给程序员的编写造成了一定的麻烦，因为程序在编写时，它访问数据和指令跳转的目标地址很多都是固定的，需要重定向。
     
这时候，就产生了一种解决方案，一种对主存的抽象概念，叫做 **虚拟内存**(Virtual Memory/VM，下文中为了简便可能会使用缩写) 。
# 虚拟内存的作用
虚拟内存是硬件异常、硬件地址翻译、主存、磁盘文件和内核软件的完美交互，它为每个进程提供了一个大的、一致的和私有的地址空间。
虚拟内存提供可三个重要的功能：
> 1. 它将主存看成是一个存储在磁盘上的地址空间的高速缓存，在主存中只保存活动区域，并根据需要在磁盘和主存之间来回传送数据；
> 2. 它为每个进程提供了一致的地址空间，从而简化了内存管理；
> 3. 它保护了每个进程的地址空间不被其他进程破坏。

VM是沉默的工作，不需要开发人员的任何干涉。但是，我们依然要注意它，原因有三：
> 1. **虚拟内存是核心的**       
        VM遍及计算机系统的所有层面，在硬件异常、汇编器、链接器、加载器、共享对象、文件和进程的设计中扮演着重要的角色。理解VM将帮助开发者更好的理解系统通常是如何工作的。（尤其是在iOS开发中！）
> 2. **虚拟内存是强大的**
        VM给予了应用程序强大的能力，可以创建和销毁内存片、将内存片映射到磁盘文件中的某个部分（mmap），以及与其他进程共享内存。理解VM将帮助你利用它的强大功能在应用程序中添加动力。 
> 3. **虚拟内存是危险的**
        每次应用程序引用一个变量、间接引用一个指针，或者调用一个诸如malloc这样的动态分配程序时，它就会和VM发生交互。如果VM使用不当，应用将遇到复杂危险的与内存有关的错误。理解VM可以帮助开发者规避这种错误。
   
# 寻址方式
 计算机系统的主存被组织成一个由M个连续的字节大小的单元组成的数组。每个字节都有一个唯一的物理地址(Physical Address)。第一个字节的地址为0，下一个为1，在往下是2，以此类推。直接通过物理地址访问内存的方法就是 **物理寻址**。
 
 而现在除了嵌入式设备和某些超级计算机意外，我们使用 **虚拟寻址**来取代物理寻址。
 
 使用虚拟寻址，CPU通过生成一个虚拟地址（VIrtual Address）来访问主存，这个虚拟地址在被送到内存前先转换成适当的物理地址。将虚拟地址转换成物理地址的任务叫做地址翻译。

 
# 地址空间
地址空间是一个线性的非负整数地址的有序集合：
> 如果像是{0,1,2,……}一样，我们可以称之为线性地址空间。
> 分为虚拟地址空间和物理地址空间，分别对应虚拟内存和物理内存。
    地址空间帮助我们区分了数据对象（字节）和它们的属性（地址）。主存中的每字节都有一个选自虚拟空间的虚拟地址和一个选自物理空间的物理地址。
 
# 页
（注意，这里只讲了页式虚拟内存，还有另外一种段式虚拟内存，也可以把页式当成一种特殊的段式）

现代操作系统将内存划分为页，来简化内存管理，一个页其实就是一段连续的内存地址的集合，通常有 4k 和 16k（iOS 64 位是 16K）的，成为 Virtual Page 虚拟页。与之对应的物理内存被称为 Physical Page 物理页。

注意 虚拟页的个数可能和物理页个数不一样 比如说一个 64 位操作系统中使用 48 位地址空间的 虚拟页大小为 16K，那么其虚拟页可数可达到（2^48 / 2^14 = 16M 个）假设物理内存只有 4G 那么物理页可能只有 (2^32 / 2^14 = 256k 个)。

任何时刻，虚拟页面的集合都分为三个不想交的子集：
> 1. **未分配的**
        VM系统还未分配的（或者创建）的页。未分配的块没有任何数据和它们相关联，因此也就不占用任何磁盘空间。
> 2. **缓存的**
        当前已缓存在物理内存中的已分配页。
> 3. **未缓存的**
        未缓存在物理内存中的已分配页。

#### DRAM中的结构

我们用SRAM（静态RAM）来表示L1、L2和L3高速缓存，用DRAM（动态RAM）表示虚拟内存中的缓存（它在主页中缓存虚拟页）。   

在缓存中，DRAM未命中比SRAM要昂贵的多，因为SRAM未命中可以有DRAM来兜底，DRAM未命中就需要用磁盘来兜底（磁盘要比DRAM慢100000多倍，而且从磁盘的一个扇区读取第一个字节的时间开销比读连续的字节要慢非常非常多）。因为上面的原因，虚拟页往往设置的比较大，通常4KB-2MB。而且，DRAM是全相联的， **任何虚拟页都可以放置在任何物理页之中**。

#### 页表
操作系统使用页表（PageTable），将虚拟页映射到物理页。每次地址翻译硬件将一个虚拟地址转换为物理地址时，都会读取页表。

页表实际上是一个页表条目（Page Table Entry，PTE）的数组。虚拟地址空间中的每个页在页表中一个固定偏移处都有一个PTE。


# 缺页
假如DRAM缓存未命中，被称之为缺页（page fault）。当缺页发生时，会启动内核中的缺页异常程序，选择一个牺牲页，进行磁盘和内存中数据的交换。

在iOS系统中，因为内存的紧张，并未采用这种方式，而是类似OOM警告的方式来控制，但是使用mmap不当的时候是会可能发生这种情况的。MacOS中是存在的这种情况的。

# 虚拟内存的内存管理
VM为每个进程都提供了一个独立的页表，因而也就是一个独立的虚拟地址空间。使用VM也会有很多优点
> 1. **简化链接**   
        每个独立的地址空间允许每个进程的内存映像使用相同的基本格式，而不管代码和数据实际存放在物理内存的何处。
> 2. **简化加载** 
        VM使得容易向内存中加载可执行文件和共享对象文件。
> 3. **简化共享**
        独立的地址空间为操作系统提供了一个管理用户进程和操作系统自身之间共享的一致机制。
> 4. **简化内存分配**
        假如遇到需要共享内存数据的时候，VM机制可以帮助我们有选择的访问共享页面。

# 内存保护
我们应该明白，不应该允许一个用户进程任意修改它的只读代码段；不允许修改内核的代码和数据结构；不允许读写其他进程的私有内存。
为了提供这种保护，地址翻译机制会在读取PTE的时候，添加一些额外的许可位来控制虚拟页面。

# 地址翻译
 n位的虚拟地址包含两个部分：p位的虚拟页面偏移（VPO）和一个（n-p）位的虚拟页号（VPN）。MMU使用VPN来选择适当的PTE。
 **这里详细细节查看《深入理解计算机系统》（第三版）p568-p570**
 
## TLB

每次CPU产生一个地址，MMU就必须查阅一个PTE，以便将虚拟地址翻译成为物理地址。这会造成非常大的性能损耗。如何解决呢？答案简单，使用缓存！我们在这里使用一个叫做 **翻译后备缓冲器**（Transalation Lookaside Buffer-TLB）的东西来帮助我们处理。当TLB未命中时，MMU再去L1缓存中获取对应的PTE，然后再将它放到TLB中。

## 多级页表
一般来说，系统的地址空间也是有限的，我们不能每次都要一起访问整个页表。这里我们可以使用 **多级页表**技术。

一级页表对应二级页表，二级页表对应虚拟内存页面。我们只要把一级页表一直放到主存中就好了，需要的时候再去访问二级页表。

## Linux中的虚拟内存
操作系统为每个进程维护一个单独的虚拟地址空间，分为两部分。
> * **内核虚拟内存**
        包含内核中的代码和数据结构，还有一些被映射到所有进程共享的内存页面。还有一些页表，内核在进程上下文中执行代码使用的栈。
> * **进程虚拟内存**
        OS 将内存组织为一些区域（Sement）的集合，代码端，数据端，共享库端，线程栈都是不同的区域，分段的原因是便于管理内存的权限，如果了解过 Mach-O 文件或者 ELF 文件的读者可以看到相同的 Segment 里面的内存权限是相同的，每个 Segment 再划分不同的内容为 section。


# 内存映射 （mmap）

> 在Linux中，通过将一个虚拟内存区域与一个磁盘上的对象关联起来，以初始化这个虚拟内存区域的内容。

大致过程如下：进程先在虚拟地址空间中创建虚拟映射区域，然后内核开始调用mmap函数，实现物理地址和虚拟地址的映射。

实现细节可以查看 **《深入理解计算机系统》（第三版）p582-p586**

我们需要记住：mmap为共享书、创建新的进程以及加载程序提供了一个高效的机制。应用可以使用mmap函数来手工德创建和删除虚拟地址空间区域内一个称谓堆（heap）的区域。
而mmap在iOS的用处：

> 1. mmap让读写一个文件像操作一个内存地址一样简单方便，
> 2. mmap效率极高，不用将一个内容从磁盘读入内核态再拷贝至用户态
> 3. mmap映射的文件由操作系统接管，如果进程 Crash 操作系统会保证文件刷新回磁盘。

通过以上的特点，我们可以在图片加载（例如[FastImageCache](https://github.com/path/FastImageCache)），数据存储以及关键的crash收集上报中使用。

# 动态内存分配

在运行时需要额外的虚拟内存的时候，用动态内存分配器更方便、更好的可移植性。
动态内存分配器维护着一个进程的虚拟内存区域，称之为 **堆**。堆可以被视为一组大小不同的块（block）的集合。这些块要不然就是分配的，要不然就是空闲的。
分配器有两种基本风格，两种风格都要求显式的分配块：
> * 显式分配器 （手动管理内存,严格来讲ARC算是这个的变种）
> * 隐式分配器 （垃圾收集，Java等语言采用这种）

显示分配器的实现细节可以查看 **《深入理解计算机系统》（第三版）p587-p605**。十分推荐iOS去读，很多时候跳出来看一下原理，会让自己有新的认知。
隐式分配器或者说垃圾收集实现细节可以查看 **《深入理解计算机系统》（第三版）p605-p609**。
因为我对使用GC的语言的语言没什么研究，两者的区别优劣我无法给出，不过推荐一下这篇文章[Garbage Collection vs Automatic Reference Counting](https://medium.com/computed-comparisons/garbage-collection-vs-automatic-reference-counting-a420bd4c7c81)。
[倾寒](https://www.valiantcat.cn/)推荐这个代码[C + + 实现一个简易的内存池分配器](https://blog.csdn.net/oyoung_2012/article/details/78874869)，也可以看一下。

# iOS Memory

在上边我们了解的页这一概念，iOS实际上也是使用了这一概念。

我们可以使用以下代码来查看数据
```C++
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "mach/mach.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        printf("page-size:%ld \nmask:%ld\nshift:%d \n", vm_kernel_page_size, vm_kernel_page_mask, vm_kernel_page_shift);
        printf("%ld\n", sysconf(_SC_PAGE_SIZE));
        printf("%d\n", getpagesize());
        printf("%lu\n", PAGE_SIZE);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```
得到的数据为（iPhone 8 plus和iPhone SE）：
```C++
page-size:16384 
mask:16383
shift:14 
16384
16384
16384 = 16kb
```
我们用过以上数据可以得知：页大小为16kb，虚拟地址偏移为14。这里即使用上文中提过的TLB来翻译地址。
在我们未写入数据，但是刚刚被操作系统分配或者磁盘映射的时候，内存都是出于 **Clean**的状态，但是一旦被写入了，操作系统会将它标记为 **Dirty**。
> * **Clean**
        指的是能够被系统清理出内存并且在有需要的时候重新加载的数据，包括：Memory mapped files；Frameworks中的__DATA_CONST部分；应用的二进制可执行文件。
> * **Dirty**
        指的是不能被系统回收的内存占用，包括：堆上的对象；图片解码数据；Frameworks中的__DATA和__DATA_DIRTY部分。

标记的一个好处在于：因为Dirty页面已经被写入数据，是要比Clean重要的多的。当操作系统发现内存十分紧张的时候，会尝试驱逐一部分内存页面。Clean的页面会因为优先级的原因被首先驱逐，并开始和磁盘（中的backing store部分）交换分区，等到需要使用的时候再去读取。
但是我们这里要注意一点，iOS因为是在移动端使用，移动端使用的是闪存。现在新版的iPhone使用的都是TLC(Triple-Level Cell),过于频繁的读写会严重影响闪存的使用寿命（实际上是二氧化硅薄膜因为电子的频繁进出而变薄）。所以并没有使用上边这个磁盘交换机制，因此如果出现内存紧张的情况，iOS会使用**Compressed Memory**机制。在内存紧张的时候，将不常使用的内存压缩并且在需要的时候解压。

> * When your system’s memory begins to fill up, Compressed Memory automatically compresses the least recently used items in memory, compacting them to about half their original size. When these items are needed again, they can be instantly uncompressed.

这个举措，特点可以归纳为:
> * 减少了不活跃内存占用      
> * 改善了电源效率，通过压缩减少磁盘IO带来的损耗     
> * 压缩/解压十分迅速，能够尽可能减少 CPU 的时间开销     
> * 支持多核操作      

从某种意义上来说，我们可以把**Compressed memory**视为**Dirty memory**。

**memory footprint = dirty size + compressed size ，这也就是我们需要并且能够尝试去减少的内存占用**

当我们的app的memory footprint 达到一定的值时，我们会受到内存警告（Memory Warnings）。

如果我们收到了内存警告，系统本身会释放一部分内存页面（例如NSCache机制），但是也会向当前运行的程序发送低内存警告，我们也要对此作出相应。

UIKit中有几种接受低内存警告的方法：
> 1. applicationDidReceiveMemoryWarning:方法；     
> 2. 在UIViewController中重写didReceiveMemoryWarning；       
> 3. 注册接受UIApplicationDidReceiveMemoryWarningNotification通知     
如果我们对此置之不理，程序有可能直接被干掉，那时候我们就会陷入OOM的困境之中。

# 监测内存的工具
## Xcode
命令行工具暂且不提，那套更加适合MacOS。
在Xcode中，我们可以使用三种工具来测量内存：
> 1. Xcode memory gauge     
> 2. Instruments(主要是Leaks、Allocation、Counters以及System Trace中的Virtual Memory Trace)      
> 3. Xcode Memory Debugger      

![Xcode memory gauge](https://ws4.sinaimg.cn/large/006tNbRwly1fwpuwrudttj31kw0yj7wh.jpg)

![Instruments](https://ws4.sinaimg.cn/large/006tNbRwly1fwpuxiyldxj31kw0yjjxf.jpg)

![Xcode Memory Debugger](https://ws2.sinaimg.cn/large/006tNbRwly1fwpuxr31mwj31kw0yje81.jpg)

在Xcode10之后，当内存过大的时候，也会触发debugger，自动捕获 `EXC_RESOURCE RESOURCE_TYPE_MEMORY`异常，并自动断点在出问题的地方。
![](https://ws1.sinaimg.cn/large/006tNbRwly1fwpviiqyrhj31kw0w07fh.jpg)

在在Product->Scheme->Edit Scheme->Diagnostics中，开启 Malloc Stack 功能，建议使用Live Allocations Only选项。 
中开启Malloc Stack功能，使用 **Live Allocations Only**选项，会在lldb中记录调试过程中对象创建的堆栈，配合使用 ``malloc_history``工具，可以方便我们定位到占用过大内存的对象的创建位置。

## 代码方法
获取应用使用真实物理内存值的代码：
```C++
- (NSUInteger)getResidentMemory
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
	
	int r = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)& info, & count);
	if (r == KERN_SUCCESS)
	{
		return info.resident_size;
	}
	else
	{
		return -1;
	}
}
```
## 线上内存检测工具
1. [MLeaksFinder](https://github.com/Tencent/MLeaksFinder)       
2. [FBRetainCycleDetector](https://github.com/facebook/FBRetainCycleDetector)        
3. [OOMDetector](https://github.com/Tencent/OOMDetector)     

当然，我们也可以自己在理解内存检测的原理之后，自己去实现一些轮子，以更加贴合自己的使用场景。


# 如何注意内存优化

0. 多用懒加载     
1. weak替代 unsafe_unretain ，以及注意assign；       
2. 安全的使用weak；        
3. autoreleasepool多用；        
4. 对UI、动画机制深入了解，尤其是动画以及Cell复用机制；     
5. imageName：        
5. performSelect谨慎使用；        
6. 倒计时使用注意，设计一定要严谨；      
7. 多使用Cache而非dictionary；     
8. 监测性能组件使用mmap存放读取数据；       
9. NSDateFormate注意；      
10. 谨慎小心的使用指针，小心野指针；     
11. WKWebView 是跨进程通信的，不会占用我们的 APP 使用的物理内存量，**但是依然要小心谨慎的测量**；     
12. 在保证安全的前提下，选用一些更小的数据结构；       
13. 特别大的贴图要谨慎使用；     
14. 谨慎小心的使用指针；       
15. 注意 NSDateFormatter的使用。       

# 后续记录计划
SLC/MLC/TLC对比，为什么选用TLC      
OOM是个什么鬼。       
如何设计一个一个内存监测组件。     
`如何注意内存优化`中各项的解释。       

# 参考和鸣谢
《程序员的自我修养-链接、装载和库》第一版（第十章）           
《深入理解计算机系统》第三版（第九章）             
《iOS 和 macOS 性能优化：Cocoa、Cocoa Touch、Objective-C 和 Swift》第一版（第五章）                
《高性能iOS应用开发》 第一版-第二章        
《Effective Objective-C 2.0 编写高质量iOS与OS X代码的52个有效方法》第五十条     
[WWDC 2018-Session 416： iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416/)        
[iOS Memory Deep Dive](https://www.valiantcat.cn/index.php/2018/10/06/64.html#menu_index_40)        
[OS X Mavericks Core Technology Overview](https://images.apple.com/media/us/osx/2013/docs/OSX_Mavericks_Core_Technology_Overview.pdf)       
[Memory Usage Performance Guidelines](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/ManagingMemory/ManagingMemory.html)      
[Instruments Help](https://help.apple.com/instruments/mac/current/#//apple_ref/doc/uid/TP40004652)      
[iOS-Monitor-Platform](https://aozhimin.github.io/iOS-Monitor-Platform/)        
感谢[倾寒](https://github.com/ValiantCat)、[冬瓜](https://github.com/Desgard)在创作中给予的帮助。


