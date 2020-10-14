# 链接总结

# 0. About this book

# 1. Darwinism:The Evolution of OS

达尔文主义：操作系统进化论


1. 《A History of Apple's Operating Systems》
   
    
# 2. E Pluribus Unum: Architecture of OS
操作系统架构
1. Mac Technology Overview
        https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/About/About.html
2. https://github.com/steventroughtonsmith/cartool
3. Reverse engineering the .car file format (compiled Asset Catalogs)
    https://blog.timac.org/2018/1018-reverse-engineering-the-car-file-format/
4. Mach-O Programming Topics (https://www.cs.miami.edu/home/burt/learning/Csc521.091/docs/MachOTopics.pdf)
 
    
# 3. Promenade: A tour of the OS Filesystems

操作系统文件系统

# 4. Experience Points: UX and System Services
    
用户体验和系统服务

# 5. Automatic for the People: Application Service

应用服务
    
# 6. Ex Machina: The Mach-O File format
    
1. Mach-O Programming Topics (https://www.cs.miami.edu/home/burt/learning/Csc521.091/docs/MachOTopics.pdf)
2. Mach-O File Format Reference(https://github.com/aidansteele/osx-abi-macho-file-format-reference/blob/master/Mach-O_File_Format.pdf)
3. Writing Bad @$$ Malware for OS X (https://www.blackhat.com/docs/us-15/materials/us-15-Wardle-Writing-Bad-A-Malware-For-OS-X.pdf)
4. dumpdecrypted(https://github.com/stefanesser/dumpdecrypted)
# 7. In the Darkness,Bind Them: dyld  internals

在黑暗中绑定他们：dyld 核心
1. [Pointer Authentication on ARMv8.3.pdf](https://www.qualcomm.com/media/documents/files/whitepaper-pointer-authentication-on-armv8-3.pdf)
2. [ARMv8.3 Pointer Authentication.pdf](https://events.static.linuxfound.org/sites/events/files/slides/slides_23.pdf)
3. [Github:lorgnette.c](https://github.com/rodionovd/liblorgnette/blob/master/lorgnette.c)
4. [Github:CoreSymbolication](https://github.com/mountainstorm/CoreSymbolication)
5. http://newosxbook.com/src.jl?tree=listings&file=4-5-interpose.c
6. [dyld_shared_cache](https://iphonedevwiki.net/index.php/Dyld_shared_cache)
7. [App Startup Time: Past, Present, and Future](https://developer.apple.com/videos/play/wwdc2017/413/)
8. [NSModule.3](https://opensource.apple.com/source/cctools/cctools-384.1/man/NSModule.3.auto.html)


# 8. Parts of the Process: Threads and Grand Central Dispatcher

1. [MacOS/iOS userspace entitlement checking is racy](https://bugs.chromium.org/p/project-zero/issues/detail?id=1223)
2. [Prioritize Work at the Task Level](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheTaskLevel.html)
3. [Concurrency Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008091)
4. [Dispatch](https://developer.apple.com/documentation/dispatch)
5. [Blocks Programming Topics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Blocks/Articles/00_Introduction.html#//apple_ref/doc/uid/TP40007502)
6. [Block Implementation Specification](http://clang.llvm.org/docs/Block-ABI-Apple.html)
7. [Using Continuations to Implement Thread Management
and Communication in Operating Systems . pdf](https://zoo.cs.yale.edu/classes/cs422/2013/bib/draves91continuations.pdf)

# 9. In Memoriam: Process Memory Management

1. [A look at how malloc works on the Mac](https://www.cocoawithlove.com/2010/05/look-at-how-malloc-works-on-mac.html)
2. [In the Zone:OS X Heap Exploitation.pdf](https://papers.put.as/papers/macosx/2016/Summercon-2016.pdf)
3. [Magazines and Vmem:Extending the Slab Allocator to Many CPUs and Arbitrary Resources](http://www.parrot.org/sites/www.parrot.org/files/vmem.pdf)
4. [Hoard: A Scalable Memory Allocator for Multithreaded Applications](https://www.cs.utexas.edu/users/mckinley/papers/asplos-2000.pdf)
5. [NSCache](https://developer.apple.com/documentation/foundation/nscache)
6. http://newosxbook.com/src.jl?tree=&file=/listings/12-1-vmmap.c

# 10. CFRun - RunLoopRun: The Runtime Environments
    
1. [Concepts in Objective-C Programming](https://developer.apple.com/library/archive/documentation/General/Conceptual/CocoaEncyclopedia/Introduction/Introduction.html)
2. [Programming with Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011210)
3. [Core Foundation Design Concepts](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFDesignConcepts/CFDesignConcepts.html#//apple_ref/doc/uid/10000122i)
4. [Run Loops](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16-SW1)
5. [Modern Objective-C Exploitation Techniques--Phrach 69-9](http://www.phrack.org/issues/69/9.html)
6. [Nemo_JSS_Slides.pdf](https://thecyberwire.com/events/docs/Nemo_JSS_Slides.pdf)
7. [github:substitute](https://github.com/comex/substitute)
8. [CaptainHook](https://github.com/rpetrich/CaptainHook/wiki)
9. [Debugging Cocoa with DTrace on Mac OS X](http://www.1729.us/cocoasamurai/Debugging%20Cocoa%20with%20DTrace.pdf)


# 11. The Message is the Medium: Mach IPC(the user mode view)
    

# 12. Mecum Porto: Mach Primitives
# 13. The Alpha & Omega - Launchd
# 14. X is not a Procedure Call: XPC internals
# 15. Follow Me: Process Tracing and Debugging
# 16. Het-Work: Darwin Networking
