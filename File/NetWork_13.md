# 伯阳的网络笔记（十）：如何正确的获取 DNS 地址

一般情况下，获取本机 DNS 地址的时候，我们会使用以下的方法。

先在系统中加入 `libresolv.tbd` 库。
然后在头文件中引入以下几个头文件：
```C++
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <resolv.h>
#include <dns.h>
```

然后使用以下代码，或者以此进行改编：
```C++
NSMutableArray *DNSList = [NSMutableArray array];
res_state res = malloc(sizeof(struct __res_state));
int result = res_ninit(res);
if (result == 0) {
    for (int i=0;i < res->nscount;i++) {
        NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
        [DNSList addObject:s];
    }
}
res_nclose(res);
free(res);
// dnsList 就是 DNS 服务器地址
```

但是不巧，不就有个朋友告诉我，使用这段代码会造成内存泄漏，我自己试了一下，还真有，那是哪里出了问题呢？

# 查找过程

经过初步的检测，发现 `int result = res_ninit(res); `这段代码创建的内存没有释放掉。

但是下面明明已经写了 `res_nclose(res);` 了啊。

没办法，我点击进入 `res_ninit` 的页面，挨个进行查找。

终于在经过了漫长的翻阅资料之后，发现了一份 [Oracle 的文档](https://docs.oracle.com/cd/E36784_01/html/E36875/res-ndestroy-3resolv.html)。

里面有几段注释让我如获至宝：

1. The res_ndestroy() function should be called to free memory allocated by res_ninit() after the last use of statp.

2. The res_nclose() function closes any open files referenced through statp.

3. The res_ndestroy() function calls res_nclose(), then frees any memory allocated by res_ninit() referenced through statp.

以及下面这段示例代码：

```C++
#include <resolv.h>
#include <string.h>

int main(int argc, char **argv)
{
    int len;
    struct __res_state statp;
    union msg {
        uchar_t buf[NS_MAXMSG];
        HEADER  h;
    } resbuf;

    /* Initialize resolver */
    memset(&statp, 0, sizeof(statp));
    if (res_ninit(&statp) < 0) {
        fprintf(stderr, "Can't initialize statp.\n");
        return (1);
    }

    /*
     * Turning on DEBUG mode keeps this example simple,
     * without need to output anything.
     */
    statp.options |= RES_DEBUG;

    /* Search for A type records */
    len = res_nsearch(&statp, "example.com", C_IN, T_A,
         resbuf.buf, NS_MAXMSG);
    if (len < 0) {
        fprintf(stderr, "Error occured during search.\n");
        return (1);
    }
    if (len > NS_MAXMSG) {
        fprintf(stderr, "The buffer is too small.\n");
        return (1);
    }

    /* ... Process the received answer ... */

    /* Cleanup */
    res_ndestroy(&statp);
    return (0);
}
```

意思就是：
* dns 的相关信息存储于 statp 中，使用 res_ninit 去创建这个 statp，然后可以从众读取数据。
* res_nclose 函数会关闭所有打开的 statp 文件，但是并不会释放这部分的内存；如果要关闭的同时释放掉内存，应该使用 res_ndestroy 函数。

# 正确代码

```C++
NSMutableArray *DNSList = [NSMutableArray array];
res_state res = malloc(sizeof(struct __res_state));
int result = res_ninit(res);
if (result == 0) {
    for (int i=0;i < res->nscount;i++) {
        NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
        [DNSList addObject:s];
    }
}
res_ndestroy(res);
free(res);
// dnsList 就是 DNS 服务器地址
```

# 引用

[man pages section 3: Networking Library Functions](https://docs.oracle.com/cd/E36784_01/html/E36875/res-nclose-3resolv.html#scrolltoc)