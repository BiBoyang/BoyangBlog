# 获取OC汇编代码

Xcode -> Product -> Perform Action -> Assemble "*.m"即可获得汇编输出
 ![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/iOS_Tips_09.png?raw=true)

此外，还可以进入文件目录，键入命令: clang -S -fobjc-arc input.m -o output.s ,在该目录下即可获得汇编输出