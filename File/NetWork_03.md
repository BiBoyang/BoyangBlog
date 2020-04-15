# 伯阳的网络笔记（四）：TCP 
> 因为疫情期间在外当志愿者，晚上回家无聊翻翻网络知识，权当记录了。
> 初始动笔：2019-02-11
> 修改时间：2019-04-01

# TCP是什么？
互联网有两个核心协议： IP 和 TCP。IP，即 Internet Protocol（因特网协议）负责联网主机之间的路由选择和寻址；TCP，即 Transmission Control Protocol（传输控制协议）。

TCP 负责在不可靠的传输信道上提供可靠的抽象，向应用层隐藏了大多数网络通信的复杂细节。采用 TCP 数据流可以确保发送的所有字节都能够完整的被接收到，而且到达客户端的顺序也一样。一般来说， HTTP 协议是基于 TCP 的，但也不绝对，实际上已经有人用 UDP 来搞定 HTTP 了。

我们可以这么说，HTTP 协议专注于要传输的信息，TCP 协议专注于确保传输的可靠，而IP则负责因特网传输。
# TCP 首部格式
首部格式如图所示：
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_17.png?raw=true)

它的标准长度是20字节。TCP 中没有单独的字段表示包长度和数据长度。可由 IP 层获知 TCP 的包长，由 TCP 的包长可知数据的长度。

* 序列号 (Sequence Number):
        字段长 32 位，序列号是指发送数据的位置，每发送一次数据，就累加一次该数据字节数的大小。序列号不会从0 或者 1 开始，而是在建立连接的时候由计算机生成的随机数作为其初始值，通过 SYN 包传给接收端主机。

* 确认应答号 (Acknowledgement Number)：
        确认应答号字段长度为 32 位。是指下一次应该收到的数据的序列号，实际上，它是指已收到确认应答号减一为止的数据。发送端收到这个确认应答以后可以认为在这个序号以前的数据都已经正常接收了。ACK=1 时有效。

* 数据偏移 (Data Offset)
        该字段表示 TCP 所传输的数据部分应该从 TCP 包的哪个位开始计算，当然也可以把它看作 TCP 首部的长度。该字段长 4 位，单位为 4 字节 (即 32 位)。不包含选项字段的话，数据偏移字段可以设置为 5 。反之，如果该字段的值为 5，那说明从 TCP 包的最一开始到 20 字节为止都是 TCP 首部，余下的部分为 TCP 数据。

* 保留 (Reserved):
        该字段主要是为了以后扩展使用，其长度为 4 位，一般设置成 0 ，即使收到的包在该字段不为 0 ，此包也不会被丢弃。

    *   控制位 (Control Flag):
字段长为 8 位，从左往右分别如下图：








# TCP 三次握手
所有的 TCP 连接一开始都要经过三次握手，如下图所示。客户端在于服务器在交换应用数据之前，必须就起始分组序列号，以及其他一些连接相关的细节达成一致。处于安全考虑，序列号由两端随机生成。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_16.png?raw=true)



# TCP拥塞控制

# TCP 流量控制

# TCP洪泛攻击

# 保活机制



# 引用
[RFC791](https://tools.ietf.org/html/rfc791)

[RFC793](https://tools.ietf.org/html/rfc793)

[为什么 TCP 建立连接需要三次握手](https://draveness.me/whys-the-design-tcp-three-way-handshake/)

《Web权威性能指南》

《计算机网络》

《计算机网络：自顶向下方法》