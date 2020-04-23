> * 原作于：2018-01-02        
> * GitHub Repo：[BoyangBlog](https://github.com/BiBoyang/BoyangBlog)

这篇文章记录 block 的 copy 和 release 过程。

本文大部分内容来自[A look inside blocks: Episode 3 (Block_copy)](http://www.galloway.me.uk/2013/05/a-look-inside-blocks-episode-3-block-copy/)，只做了一部分补充。

## Block_copy()

这部分代码在[Block.h](https://opensource.apple.com/source/clang/clang-800.0.42.1/src/projects/compiler-rt/lib/BlocksRuntime/Block.h.auto.html)中。

我们知道，在 block 创建的时候，一般来说，都是在栈上的。

但是我们知道，栈是有系统自动管理的，其所属的变量作用域结束，block 就会被废弃。那该如何解决这个问题呢？

答案就是将 block 从栈上复制到堆上。下面的代码就是关键代码的主要过程。

```C++
#define Block_copy(...) ((__typeof(__VA_ARGS__))_Block_copy((const void *)(__VA_ARGS__)))
#define Block_release(...) _Block_release((const void *)(__VA_ARGS__))
```

Block_copy 是一个宏，它将传入的参数转换为一个 const void * 然后传递给 _Block_copy() 方法。 _Block_copy() 的实现在[runtime.c](https://opensource.apple.com/source/clang/clang-800.0.42.1/src/projects/compiler-rt/lib/BlocksRuntime/runtime.c.auto.html)：

```C++
void *_Block_copy(const void *arg) {
    return _Block_copy_internal(arg, WANTS_ONE);
}
```

继续往下：

```C++
/* Copy, or bump refcount, of a block.  If really copying, call the copy helper if present. */
static void *_Block_copy_internal(const void *arg, const int flags) {
    struct Block_layout *aBlock;
    const bool wantsOne = (WANTS_ONE & flags) == WANTS_ONE;
    //-1-. 如果传入参数是 NULL 就直接返回 NULL 。防止传入一个 NULL 的 block。
    if (!arg) return NULL;
    // The following would be better done as a switch statement
    
    //-2-. 将参数转换为一个 struct Block_layout 类型的指针。
    aBlock = (struct Block_layout *)arg;
    
    //-3-. 如果 block 的 flags 字段包含 BLOCK_NEEDS_FREE ，那么这是一个堆 block。这里只需要增加引用计数然后返回原 blcok。
    if (aBlock->flags & BLOCK_NEEDS_FREE) {
        // latches on high
        latching_incr_int(&aBlock->flags);
        return aBlock;
    } else if (aBlock->flags & BLOCK_IS_GC) {
        // GC refcounting is expensive so do most refcounting here.
        if (wantsOne && ((latching_incr_int(&aBlock->flags) & BLOCK_REFCOUNT_MASK) == 1)) {
            // Tell collector to hang on this - it will bump the GC refcount version
            _Block_setHasRefcount(aBlock, true);
        }
        return aBlock;
    }
    //-4-. 如果这是一个全局 block，那么不需要做任何事，直接返回原 block。因为全局block 是一个单例。
    else if (aBlock->flags & BLOCK_IS_GLOBAL) {
        return aBlock;
    }

    // Its a stack block.  Make a copy.
    if (!isGC) {
    
        //-5-. 如果走到这里，那么这一定是一个栈上分配的block。那样的话，block需要拷贝到堆上。这才是有趣的部分！第一步，调用malloc()创建一块特定的内存。如果创建失败，返回NULL；否则，继续。
        struct Block_layout *result = malloc(aBlock->descriptor->size);
        if (!result) return (void *)0;
        
        //-6-. 调用memmove()方法将当前栈上分配的block按位拷贝到我们刚刚创建的堆内存上。这样可以保证所有的元数据都拷贝过来，比如descriptor。
        memmove(result, aBlock, aBlock->descriptor->size); // bitcopy first
        // reset refcount
        
        //-7-. 更新标志位。第一行确保引用计数为0。注释表明这行其实不需要————大概这个时候引用计数已经是0了。我猜保留这行是因为以前有个bug导致这里的引用计数不是0（所以说runtime的代码也会偷懒）。下一行设置了BLOCK_NEEDS_FREE标志位，表明这是一个堆block，一旦引用计数减为0，它所占用的内存将被释放。|1操作设置block的引用计数为1。

        result->flags &= ~(BLOCK_REFCOUNT_MASK);    // XXX not needed
        result->flags |= BLOCK_NEEDS_FREE | 1;
        
        //-8-. block的isa指针被设置为_NSConcreteMallocBlock，说明这是个堆block。
        result->isa = _NSConcreteMallocBlock;
        
        //-9-. 如果block有一个拷贝辅助函数，那么它将被调用。必要的时候编译器会生成拷贝辅助函数。比如一个捕获了对象的block就需要。那么拷贝辅助函数将持有被捕获的对象。
        if (result->flags & BLOCK_HAS_COPY_DISPOSE) {
            //printf("calling block copy helper %p(%p, %p)...\n", aBlock->descriptor->copy, result, aBlock);
            (*aBlock->descriptor->copy)(result, aBlock); // do fixup
        }
        return result;
    } else {
        // Under GC want allocation with refcount 1 so we ask for "true" if wantsOne
        // This allows the copy helper routines to make non-refcounted block copies under GC
        unsigned long int flags = aBlock->flags;
        bool hasCTOR = (flags & BLOCK_HAS_CTOR) != 0;
        struct Block_layout *result = _Block_allocator(aBlock->descriptor->size, wantsOne, hasCTOR);
        if (!result) return (void *)0;
        memmove(result, aBlock, aBlock->descriptor->size); // bitcopy first
        // reset refcount
        // if we copy a malloc block to a GC block then we need to clear NEEDS_FREE.
        flags &= ~(BLOCK_NEEDS_FREE|BLOCK_REFCOUNT_MASK);   // XXX not needed
        if (wantsOne)
            flags |= BLOCK_IS_GC | 1;
        else
            flags |= BLOCK_IS_GC;
        result->flags = flags;
        if (flags & BLOCK_HAS_COPY_DISPOSE) {
            //printf("calling block copy helper...\n");
            (*aBlock->descriptor->copy)(result, aBlock); // do fixup
        }
        if (hasCTOR) {
            result->isa = _NSConcreteFinalizingBlock;
        }
        else {
            result->isa = _NSConcreteAutoBlock;
        }
        return result;
    }
}
```

## Block_release()

我们接着来看 **_Block_release()** 的代码。

```C++
// API entry point to release a copied Block
void _Block_release(void *arg) {

    //-1-. 首先，参数被转换为一个指向struct Block_layout的指针。如果传入NULL，直接返回。
    struct Block_layout *aBlock = (struct Block_layout *)arg;
    
    //-2-. 标志位部分表示引用计数减1（之前Block_copy()中标志位操作代表的是引用计数置为1）。
    int32_t newCount;
    if (!aBlock) return;
    newCount = latching_decr_int(&aBlock->flags) & BLOCK_REFCOUNT_MASK;
    
    //-3-. 如果新的引用计数值大于0，说明有其他东西在引用block，所以block不应该被释放。
    if (newCount > 0) return;
    // Hit zero
    if (aBlock->flags & BLOCK_IS_GC) {
        // Tell GC we no longer have our own refcounts.  GC will decr its refcount
        // and unless someone has done a CFRetain or marked it uncollectable it will
        // now be subject to GC reclamation.
        _Block_setHasRefcount(aBlock, false);
    }
    
    //-4-. 否则，如果标志位包含BLOCK_NEEDS_FREE，那么表明，它既是堆block而且引用计数为0，应该被释放。首先block的处理辅助函数(dispose helper)被调用，它是拷贝辅助函数(copy helper)的反义词，执行相反的操作，比如释放被捕获的对象。最后调用_Block_deallocator方法释放block。如果你查找runtime.c你就会发现这个方法最后就是一个free的函数指针，释放malloc分配的内存。

    else if (aBlock->flags & BLOCK_NEEDS_FREE) {
        if (aBlock->flags & BLOCK_HAS_COPY_DISPOSE)(*aBlock->descriptor->dispose)(aBlock);
        _Block_deallocator(aBlock);
    }
    //-5-. 当然，如果前面没拦住，说明这个block是一个全局block，则不用管它
    else if (aBlock->flags & BLOCK_IS_GLOBAL) {
        ;
    }
    
    //-6-. 警告开发者是不是做了什么奇奇怪怪的事，要把栈block释放掉
    else {
        printf("Block_release called upon a stack Block: %p, ignored\n", (void *)aBlock);
    }
}
```

