在 M1 的 Mac mini 上安装flutter

在18年年中的时候，因为当时在杭州搞一次技术沙龙，找来了闲鱼的一些朋友，分享了一些当时还算简陋的flutter的一些东西，后来在1.0版本出来之后，还玩了一阵子。

最近一段时间，随着ReactNative 0.65版本的推出，新架构的RN在架构上有了很大的进步，我又重新对两者重新产生了兴趣。
这里记录一下重新上手的一些坑。

一开始，我按照官方教程的方式，首先安装了Android Studio。
安装了flutter。当flutter doctor 时，发现了这两个报错.

图1


分别是两个错误。

先解决 `Unable to find bundled Java version.`.

这里的解决办法在 [https://github.com/flutter/flutter/blob/3c72ef374d748ef07bb2f6781161fa6bcb0b4289/packages/flutter_tools/lib/src/android/android_studio.dart#L465](https://github.com/flutter/flutter/blob/3c72ef374d748ef07bb2f6781161fa6bcb0b4289/packages/flutter_tools/lib/src/android/android_studio.dart#L465)这里。

首先，在 flutter 的文件夹里，按照路径 flutter/packages/flutter_tools/lib/src/android/android_studio.dart，找到android_studio.dart 文件夹，然后打开。

把globals.fs.path.join(directory, 'jre', 'jdk', 'Contents', 'Home') :替换成globals.fs.path.join(directory, 'jre', 'Contents', 'Home') ，就是去掉jdk。

这里上图

然后在程序中找到android studio，右键点击，如图。

打开 jre 文件夹，然后新建 jdk 文件夹，讲 content文件夹整个复制过去。

如图所示。

这时候，就解决了第一个问题。

然后解决  Android license status unknown.的问题。

点击 Android studio。


然后，在命令行中按照提示，输入flutter doctor --android-licenses，一路 y 下去，就可以了。