# iOS启动优化简述：pre-main 阶段和 dyld 简析


# 简介

设计良好的文件格式，Mach-O，仅仅是加载和执行二进制文件这一难题的一部分。

还需要一个**动态链接器**来解析载入时（load-time）和运行时（run-time）的复杂依赖，并且将必要的组件组合在一起，然后将它们放到内存中，绑定或者链接在一起。

iOS 使用一个专用的动态链接器，也就是 dyld 来实现这些目标，它是iOS系统重要组成部分，在 App 被打包成 Mach-O 格式上传之后，dyld 负责将它重新变成可以执行的程序。

本文主要讲述从点击图标到代码执行到 main() 之前的这个过程。以及 dyld 的基本工作原理。

<!--它是如何链接和绑定符号的，还有苹果最重要的组件之一 ———— `CoreSymbolication`。
以及dyld3提出的共享缓存-dyld shared cache。-->


* dyld 版本为750.6。




## 从头开始 before dyld



用户点击 App 图标的时候，系统会调用 exec() 函数来执行，在 UNIX 提供了 6 种 exec函数，实际使用到的是里面的 execve() 函数。主要作用是根据指定的文件名，从内存中找到可执行的文件。

接着在 mach-O 文件中，读取 LC_LOAD_DYLINKER，就找到了 dyld 的入口，这个入口被称为 _dyld_start ，被编码在 dyldStartup.s 中，然后调用 dyldbootstrap::start 。

最开始这部分都是执行在内核态中的，而 dyld 结束的时候实际上进入了用户态，我们可以说 dyld 整个执行过程就是从内核态向用户态转变的一个过程。


整个流程图如下。

此处应有图片

```
_dyld_start
dyldbootstrap::start
rebaseDyld
mach_init();//glue.c
__guard_setup

runDyldInitializers

dyld_main

runLibSystemInitializer

```




### _dyld_start

从 Mach-O 的 header 中获取 读取 LC_LOAD_DYLINKER，找到入口。从这里开始运行 dyld。从这里开始，dyld 开始建立自己的执行机制，创建自己的内部状态，定位可执行文件的依赖库，然后将它们映射到内存中，并且连接所有启动所需要的未解析符号（所谓“non-lazy binding”）。幸运的是，dyld 本身仅仅是一个执行 mach-O 文件的执行工具，并没有依赖什么其他的库，不然就要陷入“鸡生蛋”的逻辑陷阱里了。dyld 与它自己的系统调用包装器之间使用的是静态链接。

在文件中，我们可以发现它会直接调用 dyldbootstrap::start 方法。

此处应有图


### dyldbootstrap::start

代码在 `dyldInitialization.cpp`中可以查看，我们直接查看代码。

```C++
//  This is code to bootstrap dyld.  This work in normally done for a program by dyld and crt.
//  In dyld we have to do this manually.
uintptr_t start(const dyld3::MachOLoaded* appsMachHeader, int argc, const char* argv[],
				const dyld3::MachOLoaded* dyldsMachHeader, uintptr_t* startGlue)
{
    dyld3::kdebug_trace_dyld_marker(DBG_DYLD_TIMING_BOOTSTRAP_START, 0, 0, 0, 0);
    
    rebaseDyld(dyldsMachHeader);
    
    const char** envp = &argv[argc+1];
    
    const char** apple = envp;
	  while(*apple != NULL) { ++apple; }
	   ++apple;
	// set up random value for stack canary
	// canary:金丝雀，原意指矿井中检查泄漏的
	__guard_setup(apple);
#if DYLD_INITIALIZER_SUPPORT
	// run all C++ initializers inside dyld
	runDyldInitializers(argc, argv, envp, apple);
#endif
	// now that we are done bootstrapping dyld, call dyld's main
	uintptr_t appsSlide = appsMachHeader->getSlide();
	return dyld::_main((macho_header*)appsMachHeader, appsSlide, argc, argv, envp, apple, startGlue);
}
```


**dyldbootstrap::start** 负责的第一个任务就是 **rebaseDyld**，如果内核提供了一个非 0 的滑动值（由 dyld_start地址与其实际加载地址之间的差异决定），那么 dyld 就必须检查其数据段中的指针，并对其重设基地址。也就是 ASLR（Address space layout randomization） 技术。接下来执行 **mach_init()** 函数（在 rebaseDyld 函数中）, 初始化 mach，允许 dyld 使用 mach 进行消息传递。

然后，**__guard_setup(apple)** 函数初始化堆栈检查器，进行栈溢出保护；最后计算滑动值并获取主程序等相关参数，并调用 **dyld_main**。

### dyld_main

可以这么说，`dyld_main` 是 dyld 进行花式操作的真正的入口，之前的过程都是在做准备。这里进行的大部分 dyld 的操作，非常复杂。

由于代码过长和无用代码过多，这里就不把整个代码贴上来了。

## setContext & configureProcessRestrictions

```C++
setContext(mainExecutableMH, argc, argv, envp, apple);
...
sExecPath = _simple_getenv(apple, "executable_path");
...
sExecShortName = ::strrchr(sExecPath, '/');
	if ( sExecShortName != NULL )
		++sExecShortName;
	else
		sExecShortName = sExecPath;
...		
configureProcessRestrictions(mainExecutableMH, envp);
```

这里使用 setContext 函数，将传入的 mainExecutableMH 等 Mach-O 文件的头部信息进行分析，设置上下文。这里 Executable 的意思就是操作系统操作的可执行文件，也就是 Mach-O 文件。

接着使用 _simple_getenv 和 strrchr，来获取可执行文件的路径，然后使用 configureProcessRestrictions 函数来检测当前的进程是否受到限制。

## 检查环境信息

[点击这里](https://www.manpagez.com/man/1/dyld/osx-10.3.php)，可以查阅关于这些环境变量代表的不通用法

使用比较多的，也就是 DYLD_PRINT_OPTS（打印参数） 、DYLD_PRINT_ENV（打印环境变量） 以及 DYLD_PRINT_STATISTICS（打印启动时间） 了。举个例子，可以在 Xcode 中 `Edit scheme` -> `Run` -> `Auguments` 将环境变量 **DYLD_PRINT_STATISTICS** 设为 1 。

之后控制台会输出类似内容：
```C++
Total pre-main time: 400.15 milliseconds (100.0%)
         dylib loading time: 211.53 milliseconds (52.8%)
        rebase/binding time:   5.03 milliseconds (1.2%)
            ObjC setup time:  26.33 milliseconds (6.5%)
           initializer time: 157.05 milliseconds (39.2%)
           slowest intializers :
             libSystem.B.dylib :   6.30 milliseconds (1.5%)
    libMainThreadChecker.dylib :  63.60 milliseconds (15.8%)
           DoraemonLoadAnalyze :  24.14 milliseconds (6.0%)
                    PalmTicket :  99.58 milliseconds (24.8%)
```
就可以查看启动时间了。






# Shared Libary Cache

在 iOS 13 之后，dyld3 全面替代了之前的 dyld2，由于dyld3 的API 全面兼容 dyld2，所以不需要开发者额外的适配。

dyld3 其实并不是 WWDC2019 提出来的新技术，实际上早在 iOS 11 的时候，就被引入优化系统库和官方App了。在 iOS 13 之后，被全面推广到所有第三方app。

dyld3 最大的特点就是 dyld 缓存了，也就是 Shared Libary Cache（SLC）。SLC 机制会收集各种系统常用的动态库，然后将它们预链接到一个文件中了；然后在在 mmap 中单独加载，并且函数地址也使用硬编码。

程序会先调用 checkSharedRegionDisable 检查共享缓存是否开启，然后检查是否有缓存，若有，则使用缓存；若无，则写入缓存。

在`SharedCacheRuntime.cpp`中，我们可以查看整个缓存的机制。


# 实例化主程序

这里实际上一连串递归调用的函数。

简单的说，先调用 `instantiateFromLoadedImage` 函数，然后调用 `instantiateMainExecutable`函数，来创建一个主执行文件的镜像；接着调用`sniffLoadCommands`函数，获取 Mach-O 文件中的信息，也就是 Load Commands的内部信息。

这个函数很长，里面的参数都是非常有用的。

```C++
void ImageLoaderMachO::sniffLoadCommands
(
const macho_header* mh, 
const char* path, bool inCache, 
bool* compressed,unsigned int* segCount, 
unsigned int* libCount, const LinkContext& context,
const linkedit_data_command** codeSigCmd,
const encryption_info_command** encryptCmd
)
```
比如说：
* libCount 
    依赖的动态库的数量 
* codeSigCmd 
    应用签名 
* encryptCmd 
    应用的加密信息，也就是我们常说的应用的 “壳” 

# 加载动态库 

```C++
if	( sEnv.DYLD_INSERT_LIBRARIES != NULL ) {
			for (const char* const* lib = sEnv.DYLD_INSERT_LIBRARIES; *lib != NULL; ++lib) 
				loadInsertedDylib(*lib);
		}
```
越狱的朋友应该对`sEnv.DYLD_INSERT_LIBRARIES`比较熟悉了，很多越狱插件，都是在这个步骤进行操作的。


# 链接主程序 & 动态库

```C++
#pragma mark --------链接主程序
		// link main executable *********
		gLinkContext.linkingMainExecutable = true;
#if SUPPORT_ACCELERATE_TABLES
		if ( mainExcutableAlreadyRebased ) {
			// previous link() on main executable has already adjusted its internal pointers for ASLR
			// work around that by rebasing by inverse amount
			sMainExecutable->rebase(gLinkContext, -mainExecutableSlide);
		}
#endif
		link(sMainExecutable, sEnv.DYLD_BIND_AT_LAUNCH, true, ImageLoader::RPathChain(NULL, NULL), -1);
		sMainExecutable->setNeverUnloadRecursive();
		if ( sMainExecutable->forceFlat() ) {
			gLinkContext.bindFlat = true;
			gLinkContext.prebindUsage = ImageLoader::kUseNoPrebinding;
		}
#pragma mark --------链接动态库
		// link any inserted libraries *********
		// do this after linking main executable so that any dylibs pulled in by inserted 
		// dylibs (e.g. libSystem) will not be in front of dylibs the program uses
		if ( sInsertedDylibCount > 0 ) {
			for(unsigned int i=0; i < sInsertedDylibCount; ++i) {
				ImageLoader* image = sAllImages[i+1];
				link(image, sEnv.DYLD_BIND_AT_LAUNCH, true, ImageLoader::RPathChain(NULL, NULL), -1);
				image->setNeverUnloadRecursive();
			}
			if ( gLinkContext.allowInterposing ) {
				// only INSERTED libraries can interpose
				// register interposing info after all inserted libraries are bound so chaining works
				for(unsigned int i=0; i < sInsertedDylibCount; ++i) {
					ImageLoader* image = sAllImages[i+1];
					image->registerInterposing(gLinkContext);
				}
			}
		}
```

点击 link 方法，我们会发现，它的内部会进行调用`this->recursiveLoadLibraries(context, preflightOnly, loaderRPaths, imagePath);`函数，然后这个函数内部也会重复进行调用，递归进行符号绑定。

而在下面，在所有的插入的镜像被链接之后，会进行弱绑定`sMainExecutable->weakBind(gLinkContext);`


# 执行初始化方法

会调用`initializeMainExecutable`函数。
 
 
 
 
# 准备进入 main 函数




# 参考连接

[dyld源码](https://opensource.apple.com/tarballs/dyld/)

[WWDC2017:App Startup Time: Past, Present, and Future](https://developer.apple.com/videos/play/wwdc2017/413/)

《Mac OS X & iOS Internals》第二版
