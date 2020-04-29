# 如何获取 LinkMap

## 第一步
在工程中的Build Setting中搜索map，使能Linking下的选项“Write Link Map File”为“Yes”。并在“Path to Link Map File”中设置LinkMap文件的路径，或直接使用默认设置。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_05.png?raw=true)

## 第二步
 编译完成之后，点击查看 xxx.app 文件， show in Finder ，获取路径。
 ![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_06.png?raw=true)
 
## 第三步
 获取路径如下所示
 ![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_07.png?raw=true)
 
然后顺着往上，找到如下路径。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_08.png?raw=true)

找到格式为 xxx-LinkMap-xxx-x86_64.txt 的文件，就是符号表了。

# 分析 LinkMap 文件

## Path 
这个指的是文件路径 
**Path: /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Products/Debug-iphonesimulator/property.app/property**

## Arch
这个指的是架构类型
Arch: x86_64

## Object files
```C++
[  0] linker synthesized
[  1] /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Intermediates.noindex/property.build/Debug-iphonesimulator/property.build/property.app-Simulated.xcent
[  2] /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Intermediates.noindex/property.build/Debug-iphonesimulator/property.build/Objects-normal/x86_64/ViewController.o
[  3] /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Intermediates.noindex/property.build/Debug-iphonesimulator/property.build/Objects-normal/x86_64/AppDelegate.o
[  4] /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Intermediates.noindex/property.build/Debug-iphonesimulator/property.build/Objects-normal/x86_64/main.o
[  5] /Users/biboyang/Library/Developer/Xcode/DerivedData/property-bhhbrvpktpszcsgocfqvsjwduyxl/Build/Intermediates.noindex/property.build/Debug-iphonesimulator/property.build/Objects-normal/x86_64/SceneDelegate.o
[  6] /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.4.sdk/System/Library/Frameworks//Foundation.framework/Foundation.tbd
[  7] /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.4.sdk/usr/lib/libobjc.tbd
[  8] /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.4.sdk/System/Library/Frameworks//UIKit.framework/UIKit.tbd
```
这里展示的是链接时用到的文件，包括 .o 文件和 .tbd 动态库，前面的序号用于之后的标识。


## Sections
描述各个段在最后编译成的可执行文件中的偏移位置及大小，包括了代码段（__TEXT，保存程序代码段编译后的机器码）和数据段（__DATA，保存变量值）
```C++
# Sections:
# Address	Size    	Segment	Section
0x100000DF0	0x00000633	__TEXT	__text
0x100001424	0x00000048	__TEXT	__stubs
0x10000146C	0x00000088	__TEXT	__stub_helper
0x1000014F4	0x00000D40	__TEXT	__objc_methname
0x100002234	0x000000B9	__TEXT	__cstring
0x1000022ED	0x00000070	__TEXT	__objc_classname
0x10000235D	0x00000AE6	__TEXT	__objc_methtype
0x100002E43	0x0000016A	__TEXT	__entitlements
0x100002FB0	0x00000048	__TEXT	__unwind_info
0x100003000	0x00000018	__DATA_CONST	__got
0x100003018	0x00000040	__DATA_CONST	__cfstring
0x100003058	0x00000018	__DATA_CONST	__objc_classlist
0x100003070	0x00000020	__DATA_CONST	__objc_protolist
0x100003090	0x00000008	__DATA_CONST	__objc_imageinfo
0x100004000	0x00000060	__DATA	__la_symbol_ptr
0x100004060	0x00001390	__DATA	__objc_const
0x1000053F0	0x00000020	__DATA	__objc_selrefs
0x100005410	0x00000010	__DATA	__objc_classrefs
0x100005420	0x00000008	__DATA	__objc_superrefs
0x100005428	0x00000010	__DATA	__objc_ivar
0x100005438	0x000000F0	__DATA	__objc_data
0x100005528	0x00000188	__DATA	__data
```

第一列是段的地址，第二列是段占用大小；第三列是段类型，代码段和数据段.

其中，__text表示编译后的程序执行语句，__data表示已初始化的全局变量和局部静态变量，__bss表示未初始化的全局变量和局部静态变量，__cstring表示代码里的字符串常量，等。
## Symbols
按每个文件列出每个对应字段的位置和占用空间。
```C++
0x100000DF0	0x00000060	[  2] -[ViewController viewDidLoad]
0x100000E50	0x00000030	[  2] -[ViewController Boyang]
0x100000E80	0x00000040	[  2] -[ViewController setBoyang:]
0x100000EC0	0x00000033	[  2] -[ViewController .cxx_destruct]
0x100000F00	0x00000080	[  3] -[AppDelegate application:didFinishLaunchingWithOptions:]
0x100000F80	0x00000120	[  3] -[AppDelegate application:configurationForConnectingSceneSession:options:]
0x1000010A0	0x00000070	[  3] -[AppDelegate application:didDiscardSceneSessions:]
```
一二列和Sections的情况一样，分别是偏移地址和大小。第三列是文件序号，这个序号是哪里来的的，就是前面提到的Object files里文件的序号，比如这里 Boyang 的序号是 2 ，去 Object files 去找序号是 2 的文件。第四列是方法的符号，类名+方法名。

通过这个，我们可以知道一个 .o 文件里有多少方法被编译进了安装包，每个方法所占的体积，加起来我就知道每个 .o 文件的大小了。



# 总结

这个文件可以让人了解到 App 编译之后的情况，可以计算出静态链接库在项目中占的大小。