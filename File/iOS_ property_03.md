##### @property 原理（三）：内存管理相关


# strong/retain
retain 是在 MRC 时代使用的属性关键字，而 strong 是在 ARC 时代使用的属性关键字。

表示实例变量对传入的对象要有所有权关系，即强引用。它们会使对象的引用计数 +1，对于可变数据类型，需要使用它们。

# assign
assign 是用来修饰基本数据类型的属性修饰词。

它会直接执行 setter 方法，但是不会经过 retain/release 方法，所以，在某种意义上，和 weak 有些类似。



# copy 


# weak

# 方法名

# nullable&nonnull



