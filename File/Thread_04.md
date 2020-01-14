# iOS多线程使用方法记录
本文是多年使用多线程开发的心得，偏基础。

# pthread&NSThread
## pthread
pthread，即POSIX Thread，是一套可以跨平台通用的多线程API，基于C语言。
它可以在许多类似Unix且符合POSIX的操作系统上可用，例如FreeBSD，NetBSD，OpenBSD，Linux，iOS/macOS，Android。如果要实现一个跨平台的库，使用它实际上是个很不错的选择，不过单就iOS平台而言，并不推荐使用，而且我也确实没有使用过，就不做过多的介绍。在阅读源码发现使用pthread的时候，现查就可以了。

## NSThread

NSThread是苹果官方提供的一个操作线程的API，比pthread更加简单使用，可以**直接操作**线程对象，但是同样的也需要我们手动的管理线程的生命周期。
因为苹果官方并不建议我们去手动的


