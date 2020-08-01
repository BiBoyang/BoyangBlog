# 伯阳的网络笔记（十二）：使用 dig 查看 DNS 信息

# 使用命令查看 DNS 解析流程

我们可以使用 `dig` 命令来查看 DNS 的相关信息。

在命令行输入 
```C++
dig www.github.com 
```
可以得到以下信息：
```C++
//<-1->
; <<>> DiG 9.10.6 <<>> www.github.com

;; global options: +cmd
//<-2->
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61986
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
//<-3->
;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
//<-4->
;; QUESTION SECTION:
;www.github.com.			IN	A

//<-5->
;; ANSWER SECTION:
www.github.com.		3600	IN	CNAME	github.com.
github.com.		60	IN	A	13.229.188.59

//<-6->
;; Query time: 45 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Sat Aug 01 21:56:27 CST 2020
;; MSG SIZE  rcvd: 73
```
###  第一部分
展示的是 DIG 版本和查询地址；
### 第二部分
展示的是请求头部：
* opcode:操作码，QUERY表示查询，
* status：状态，NOERROR表示一切正常，
* id 编号：通过编号匹配返回和查询，
* flags 标志，如果出现就表示有标志，如果不出现就未设置标志：
    qr ： query，查询标志，代表是查询操作；
    rd ：recursion desired，代表希望进行递归(recursive)查询操作；
    ra ：recursive available， 在返回中设置，代表查询的服务器支持递归(recursive)查询操作；
    QUERY ：查询数，1 代表 1 个查询，对应下面的 QUESTION SECTION 中的记录数
    ANSWER ：结果数，2 代表有 2 项结果，对应下面 ANSWER SECTION 中的记录数
    AUTHORITY ：权威域名服务器记录数，5 代表该域名有 5 个权威域名服务器，可供域名解析用。对应下面AUTHORITY SECTION
    ADDITIONAL ：格外记录数，6 代表有 6 项额外记录。对应下面 ADDITIONAL SECTION。

### 第三部分

代表虚选项部OPT PSEUDOSECTION

### 第四部分
代表的是查询的域名信息，IN 代表 Internal，A 代表 Address

### 第五部分
表示的是查询到的结果，其中 www.github.com. 对应 1 个 A 记录，是13.229.188.59
* 3600 是time-to-live时间
* IN 代表Internet
*   CNAME 代表重命名
*   A 代表 Address record
### 第六部分
代表查询过程的信息
* Query time:查询消耗时间
* SERVER:本地 DNS
* 本地时间
* DNS信息大小

# 完整查询流程
```C++
www.github.com +trace
```

得到信息
```C++
; <<>> DiG 9.10.6 <<>> www.github.com +trace
;; global options: +cmd
.			126792	IN	NS	g.root-servers.net.
.			126792	IN	NS	b.root-servers.net.
.			126792	IN	NS	l.root-servers.net.
.			126792	IN	NS	k.root-servers.net.
.			126792	IN	NS	d.root-servers.net.
.			126792	IN	NS	j.root-servers.net.
.			126792	IN	NS	m.root-servers.net.
.			126792	IN	NS	i.root-servers.net.
.			126792	IN	NS	a.root-servers.net.
.			126792	IN	NS	c.root-servers.net.
.			126792	IN	NS	h.root-servers.net.
.			126792	IN	NS	f.root-servers.net.
.			126792	IN	NS	e.root-servers.net.
;; Received 239 bytes from 8.8.8.8#53(8.8.8.8) in 6 ms

com.			126792	IN	NS	g.gtld-servers.net.
com.			126792	IN	NS	f.gtld-servers.net.
com.			126792	IN	NS	l.gtld-servers.net.
com.			126792	IN	NS	e.gtld-servers.net.
com.			126792	IN	NS	j.gtld-servers.net.
com.			126792	IN	NS	h.gtld-servers.net.
com.			126792	IN	NS	i.gtld-servers.net.
com.			126792	IN	NS	b.gtld-servers.net.
com.			126792	IN	NS	a.gtld-servers.net.
com.			126792	IN	NS	m.gtld-servers.net.
com.			126792	IN	NS	c.gtld-servers.net.
com.			126792	IN	NS	d.gtld-servers.net.
com.			126792	IN	NS	k.gtld-servers.net.
com.			63026	IN	DS	30909 8 2 E2D3C916F6DEEAC73294E8268FB5885044A833FC5459588F4A9184CF C41A5766
com.			45969	IN	RRSIG	DS 8 1 86400 20200814050000 20200801040000 46594 . bIsk+4eExLTSmxwYK6YpHK86NNyDeMDL+ABquZoS0D8s8gu/pC8ZZZOp nxWkv+6e4SmylLIPSws8Wl8AYgsBoZLEPQ36mbjV9+AC6EDEybwPz5z3 07iYSPxTiLPIYGTcVSZVrLzVHLwydhdg1TWCs8OkIZy069NyRQiy6Bgu sD9zVo+PvJx4+nMDErrRAwr0TH9WiXRyBbyrC9+d0Yswfgs8NFSSmqvd JYs4TUuZKu9bh5CqCHgGh3XhpBDU92zYYtzjDt6ZmXQUPvZw7ml77LHx kxriz6jgbAq8jyIinjA06l9ABnJeqI/e6NOT3rCydyfnkmlU0SHq71K7 TK+X9A==
;; Received 1174 bytes from 193.0.14.129#53(k.root-servers.net) in 5 ms

com.			126530	IN	NS	d.gtld-servers.net.
com.			126530	IN	NS	e.gtld-servers.net.
com.			126530	IN	NS	b.gtld-servers.net.
com.			126530	IN	NS	j.gtld-servers.net.
com.			126530	IN	NS	h.gtld-servers.net.
com.			126530	IN	NS	l.gtld-servers.net.
com.			126530	IN	NS	c.gtld-servers.net.
com.			126530	IN	NS	a.gtld-servers.net.
com.			126530	IN	NS	i.gtld-servers.net.
com.			126530	IN	NS	m.gtld-servers.net.
com.			126530	IN	NS	g.gtld-servers.net.
com.			126530	IN	NS	k.gtld-servers.net.
com.			126530	IN	NS	f.gtld-servers.net.
;; BAD (HORIZONTAL) REFERRAL
;; Received 839 bytes from 192.31.80.30#53(d.gtld-servers.net) in 5 ms

github.com.		172800	IN	NS	ns-520.awsdns-01.net.
github.com.		172800	IN	NS	ns-421.awsdns-52.com.
github.com.		172800	IN	NS	ns-1707.awsdns-21.co.uk.
github.com.		172800	IN	NS	ns-1283.awsdns-32.org.
github.com.		172800	IN	NS	dns1.p08.nsone.net.
github.com.		172800	IN	NS	dns2.p08.nsone.net.
github.com.		172800	IN	NS	dns3.p08.nsone.net.
github.com.		172800	IN	NS	dns4.p08.nsone.net.
CK0POJMG874LJREF7EFN8430QVIT8BSM.com. 86400 IN NSEC3 1 1 0 - CK0Q1GIN43N1ARRC9OSM6QPQR81H5M9A  NS SOA RRSIG DNSKEY NSEC3PARAM
CK0POJMG874LJREF7EFN8430QVIT8BSM.com. 86400 IN RRSIG NSEC3 8 2 86400 20200805044132 20200729033132 24966 com. zEeq78KosYP8aknqJ7awEK1nwkjOSgg6ytKEShYUyWBh9gSlKggUPp87 tMDYY5Gu6HEyLgIfi0ELomawlIsxrbw49ZozaA1iWpR0MQNyachC6Bui VMHHa8mPbpME4S5QRMjGJ8hQhfczPmJqSFd0wtJtjnSx3KsYaLOMds/j 4egehaP/oL0AIqYrETFIN4c5jTviKxRWL5QZ8iB7/oClxQ==
4KB49MHL0SB1JJLOK123N91V2C905VHU.com. 86400 IN NSEC3 1 1 0 - 4KB4PTQQ5CTA7POCTGM7RUFC8B1RKTEU  NS DS RRSIG
4KB49MHL0SB1JJLOK123N91V2C905VHU.com. 86400 IN RRSIG NSEC3 8 2 86400 20200808044611 20200801033611 24966 com. zwah/Dpwp2ds2XJcqVnUM4cYEcuNrTA6yh/810nURFDw8BgFoTsvlpF1 3ZYyi74+oC+FBRtPHkCCAeoXcK/lXRGQ3h1Rvauh36++kUpbVCnaPzXz ZwSyYjIph11H1GbnH/uXW4f0OxoUf7P6ahISITvYcyJPRdwfgO9bgR/E 7F2htyJVrgpys7o/2DqGfiYEejUajpT8iX0+L6fWKKGBgA==
;; Received 831 bytes from 192.5.6.30#53(a.gtld-servers.net) in 446 ms

com.			126529	IN	NS	g.gtld-servers.net.
com.			126529	IN	NS	l.gtld-servers.net.
com.			126529	IN	NS	m.gtld-servers.net.
com.			126529	IN	NS	j.gtld-servers.net.
com.			126529	IN	NS	a.gtld-servers.net.
com.			126529	IN	NS	i.gtld-servers.net.
com.			126529	IN	NS	c.gtld-servers.net.
com.			126529	IN	NS	b.gtld-servers.net.
com.			126529	IN	NS	h.gtld-servers.net.
com.			126529	IN	NS	k.gtld-servers.net.
com.			126529	IN	NS	e.gtld-servers.net.
com.			126529	IN	NS	f.gtld-servers.net.
com.			126529	IN	NS	d.gtld-servers.net.
;; BAD REFERRAL
;; Received 839 bytes from 205.251.193.165#53(ns-421.awsdns-52.com) in 6 ms
```

从上面 dig 的显示可以看到，www.github.com 是如何一步步被 DNS 服务器解析的。

里面有些很奇怪的缩写，[点击这里](https://en.wikipedia.org/wiki/List_of_DNS_record_types)查看相关资料。

简单描述几个：
* A ：代表的是 Address record，返回一个 32 位的 IPv4 地址，最常用于将主机名映射到主机的IP地址
* AAAA ： 返回一个 128 位的 IPv6 地址，最常用于将主机名映射到主机的IP地址。
* IN ：代表 Internal。
* NS ：委派DNS区域以使用给定的权威名称服务器。

