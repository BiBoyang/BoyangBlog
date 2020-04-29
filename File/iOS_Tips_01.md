# clang -rewrite-objc 编译小Tips

clang -rewrite-objc 的作用是把 Objective-C 代码转换成 C/C++ 代码，来窥探一些幕后的秘密。

# 最简单的用法

举个例子，先创建一个最简单的项目
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_01.png?raw=true)

然后，找到对应的位置，输入
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_02.png?raw=true)

最后，就会出现对应的 cpp 文件了
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_03.png?raw=true)

# 报错

有时候，它会报下面的错误
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_04.png?raw=true)

这时候，有两种解决办法

##  第一种

改为使用
```C++
$ clang -x objective-c -rewrite-objc -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk XXXX.m
```
命令

## 第二种

改为使用如下的方案。
* 如果是模拟器 ：$  xcrun -sdk iphonesimulator clang -rewrite-objc main.m
* 真机 ： $ xcrun -sdk iphoneos clang -rewrite-objc main.m
* 真机+模拟器 有默认版本的 ：$  xcrun -sdk iphonesimulator9.3 clang -rewrite-objc main.m