# Swift / SwiftUI 原生 iOS 扩展入口

Windows 可编写和管理 Swift 源码，iOS SDK、Xcode 和 iPhone 目标编译仍在 macOS 云端执行。Windows 版 Swift 编译器不能替代 iOS SDK，因此本环境不额外安装 Windows Swift。

当前演示已生成 Flutter 的 Swift iOS 宿主，正式原生应用应建立独立 Xcode 工程和仓库。`templates/native-ios-unsigned.yml` 是手动触发的参考工作流，复制到原生仓库 `.github/workflows/`，提供项目路径与共享 scheme 后使用。

关键命令：

```bash
xcodebuild \
  -project native/App.xcodeproj \
  -scheme App \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/Native.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  archive

bash ci/package_unsigned_ipa.sh \
  build/Native.xcarchive/Products/Applications/App.app \
  dist/Native-unsigned.ipa
```

使用 CocoaPods 的工程改用 `-workspace`，提交 Podfile.lock；使用 Swift Package Manager 的工程提交 Package.resolved。scheme 要设为 Shared。不使用 `-allowProvisioningUpdates`，不登录 Apple 账号，不上传签名材料。

模板与通用打包器的静态检查会执行；本轮没有实际创建或构建独立 SwiftUI 项目。多 target、扩展和特殊 entitlement 需要单独调整，不能把 Flutter 测试结果当成原生项目已验证。
