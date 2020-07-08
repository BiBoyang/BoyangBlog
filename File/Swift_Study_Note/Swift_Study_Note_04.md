# Swift学习笔记(四)：上手

## 纯代码创建页面
如果想要使用纯代码创建页面，请：

1. 删除 Main.storyboard，SceneDelegate.swift 和 ViewController.swift 文件。
2. 在 Info.plist 文件中删除 `Main storyboard file base name` 属性和 `Application Scene Manifest`属性。
3. 创建简单首页：`xxxViewController.swift`。
4. 在 `AppDelegate.swift` 文件的 `didFinishLaunchingWithOptions` 函数中增加页面代码：

并且 注释下面的函数：
```swift
// MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

```

## 限制 Swift 版本
在 Bulid Settings 中，设置 Swift Language Version。

## 使用 Cocoapods
```swift
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
use_frameworks!
inhibit_all_warnings!

use_frameworks!

target 'Swift_Study_01' do
	pod 'Alamofire'
	pod 'SnapKit'
	pod 'RxSwift', '~> 5'
    	pod 'RxCocoa', '~> 5'

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '5.0'
        end
    end
end

```


