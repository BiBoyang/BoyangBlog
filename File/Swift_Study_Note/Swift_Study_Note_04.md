# Swift学习笔记(四)：纯代码创建页面

如果想要使用纯代码创建页面，请：

1. 删除Main.storyboard，SceneDelegate.swift和ViewController.swift文件。
2. 在Info.plist文件中删除Main storyboard file base name属性和Application Scene Manifest属性。
3. 创建简单首页：HomeViewController.swift。
4. 在AppDelegate.swift 文件的didFinishLaunchingWithOptions函数中增加页面代码：

并且 注释下面的函数：



