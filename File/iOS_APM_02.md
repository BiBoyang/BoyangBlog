# 电量优化2
[Energy Efficiency and the User Experience](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/)
[教你开发省电的 iOS app（WWDC17 观后）](https://www.jianshu.com/p/f0dc653d04ca)
## 电量测量
#### 1.读取官方日志Sysdiagnose。
这个方法相对精确一些，有点麻烦的是，我们需要整个获取日志再拿来分析，不太好在线上应用中使用。而且无关数据过多，读取比较艰难。
我们可以读取[iOS 电量测试实践](https://cloud.tencent.com/developer/article/1006222)来了解细节。
#### 2.开发者模式配合Instruments
 打开Developer选项中的Start Logging —> 断开iphone与PC连接 —> 一系列的用户操作 —> Stop Logging —> 连接iphone与PC, 将电量消耗数据导入Instruments。
 这个方法的已经相对而言很不错的。但是缺点也很明显，只能在开发中使用。
 
#### 3.UIDevice
获取系统各种信息，也同样能获取当前电量。缺点是粒度太大了。
#### 4.IOKit framework

IOKit framework在IOS中用来跟硬件或内核服务通信，常用于获取硬件详细信息。 首先，需要将IOPowerSources.h，IOPSKeys.h，IOKit三个文件导入到工程中。把batteryMonitoringEnabled置为true,然后即可通过如下代码获取1%精确度的电量信息：
```
-(double) getBatteryLevel{
    // returns a blob of power source information in an opaque CFTypeRef
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    // returns a CFArray of power source handles, each of type CFTypeRef
    CFArrayRef sources = IOPSCopyPowerSourcesList(blob);
    CFDictionaryRef pSource = NULL;
    const void *psValue;
    // returns the number of values currently in an array
    int numOfSources = CFArrayGetCount(sources);
    // error in CFArrayGetCount
    if (numOfSources == 0) {
        NSLog(@"Error in CFArrayGetCount");
        return -1.0f;
    }

    // calculating the remaining energy
    for (int i=0; i<numOfSources; i++) {
        // returns a CFDictionary with readable information about the specific power source
        pSource = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(sources, i));
        if (!pSource) {
            NSLog(@"Error in IOPSGetPowerSourceDescription");
            return -1.0f;
        }
        psValue = (CFStringRef) CFDictionaryGetValue(pSource, CFSTR(kIOPSNameKey));

        int curCapacity = 0;
        int maxCapacity = 0;
        double percentage;

        psValue = CFDictionaryGetValue(pSource, CFSTR(kIOPSCurrentCapacityKey));
        CFNumberGetValue((CFNumberRef)psValue, kCFNumberSInt32Type, &curCapacity);

        psValue = CFDictionaryGetValue(pSource, CFSTR(kIOPSMaxCapacityKey));
        CFNumberGetValue((CFNumberRef)psValue, kCFNumberSInt32Type, &maxCapacity);

        percentage = ((double) curCapacity / (double) maxCapacity * 100.0f);
        NSLog(@"curCapacity : %d / maxCapacity: %d , percentage: %.1f ", curCapacity, maxCapacity, percentage);
        return percentage;
    }
    return -1.0f;
}
```
这种方式，相对而言，是最适合线上的了。

## 如何省电


#### 一.CPU
    1.假如需要上传非实时的数据，比如说bug上报之类的东西。我们可以将它放置到runloop空闲的时候上传。
    2.明确需要完成的任务，非必要任务不要随意添加。
    3.尽量少使用定时器（或者干脆全局有一个倒计时，避免频繁的开辟、销毁线程）。
    4.待处理的数据大小，也会影响性能（分页加载嘛）
    5.选择正确的数据结构和方法
      NSArray的遍历方法，性能就千差万别[NSArray研究](https://github.com/BiBoyang/Study/wiki/NSArray%E7%A0%94%E7%A9%B6)
    6.注意执行数据更新的次数

#### 二.网络
    1.在使用长链接的情况下，推荐使用UDP；
    2.建议关闭WiFi开关（但是可能会影响定位精度）；
    3.善用缓存；
    4.压缩下载的网络数据；
    5.断点续传，以避免每次都要重新传输；
    6.网络不可用的情况下，停止发起请求；网络请求失败之后就需要检测网络是否可用；
    7.超时时间变短；
    8.大的文件，比如视频，大批高清图片，分批下载；并且尽量避免在没有连接WiFi的情况下，进行高带宽操作。
     蜂窝无线系统(LTE,4G,3G等)对电量的消耗远远大于 WiFi信号, 根源在于 LTE 设备基于多输入,多输出技术,使用多个并发信号以维护两端的 LTE 链接,类似的,所有的蜂窝数据链接都会定期扫描以寻找更强的信号.
     
#### 三.定位以及地图
定位包括三种：
> 1.卫星定位
> 2.蜂窝基站定位
> 3.WiFi定位
我们都知道定位服务是很耗电的,使用 GPS 计算坐标需要确定两点信息:

* 时间锁 每个 GPS 卫星每毫秒广播唯一一个1023位随机数, 因而数据传播速率是1.024Mbit/s GPS 的接收芯片必须正确的与卫星的时间锁槽对齐
* 频率锁 GPS 接收器必须计算由接收器与卫星的相对运动导致的多普勒偏移带来的信号误差
计算坐标会不断的使用 CPU 和 GPS 的硬件资源,因此他们会迅速的消耗电池电量.

简单来讲，就是要：
> 1.控制精度。
> 2.不要一直使用定位。

#### 四.屏幕
> 这一部分实际上和优化页面流畅度需要的东西差不多

1.减少视图数量（不言而喻）；
2.减少不透明视图；
3.动画尽量使用低帧率；
4.避免在屏幕上使用多种帧率。
......

#### 五.其他补充
现在新款手机，采用了OLED材质的屏幕。采用这种材质的屏幕不再需要背光模组，所以可以在更薄。当然，最关键的在于，这种材质在显示黑色的情况下，不再需要耗电；低亮度，也会相对省电。我们可以利用这一特性，做成针对OLED屏幕机型省电模式（比较类似于夜晚模式）。
手机长期过热，也会加快电池的损耗，在高于35度的南方，情况会更加明显。如果是在室外使用，我们可以为手机选用易于散热，不易于吸热的保护壳。

电量消耗的时候，我们也要考虑到电池总量

| 机型 | 电池容量 |
| --- | --- |
|iPhone 7 |1960 mAh |
|iPhone 7 Plus|2900 mAh |
|iPhone 8|1821 mAh |
|iPhone 8 Plus|2675 mAh |
|iPhone X |2716 mAh （两块电池）|
|iPhone XS Max|4174 mAh（两块电池）| 
|iPhone XS|2658 mAh（一块L形电池）|
一般而言，电池容量更小，对耗电更加敏感。不过针对不同机型电池，电池老化之后的耗电研究。因为能力有限，暂未继续深入。






