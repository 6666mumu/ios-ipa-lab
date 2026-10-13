# 当前状态

更新：2026-10-13。阶段：Windows 开发环境、最小测试 App、macOS 未签名 IPA 编译和发布全部跑通。两次真实云端构建成功，完整新构建自动化和已有构建恢复均已验证；iPhone 签名安装待用户验收。

远端：https://github.com/6666mumu/ios-ipa-lab ，分支 main。用户已完成 GitHub CLI workflow 授权，工作流提交 `553f0cf331cab2f311ac0695abaa97763fe0444d` 已推送。不要重复要求授权或创建仓库。

## 当前可下载产物

- 最新已验证构建：#2 / `38326824410`，源码 `bb7e4688b365974b5417177cc156a2f64b5713db`。main 后续仅更新交接文档，不改变这份产物的源码归属。
- IPA 直链：https://github.com/6666mumu/ios-ipa-lab/releases/download/ipa-build-38326824410/IPA-Lab-unsigned.ipa
- Release：https://github.com/6666mumu/ios-ipa-lab/releases/tag/ipa-build-38326824410
- 构建日志：https://github.com/6666mumu/ios-ipa-lab/actions/runs/38326824410
- 本机：`artifacts/38326824410/IPA-Lab-unsigned.ipa`，6,046,366 字节，SHA-256 `de1b648f5d2ef3d4596c40e7b2ec6e7654ce8e3761166bbe8215657b8818e3f9`。
- 版本 1.0.0、构建号 2、iOS 15.0+、原始 Bundle ID `com.example.ipaLab`。实际云端工具为 macOS 26.6.2 / Xcode 26.6（17F113）。Release 直链匿名下载后哈希一致。

## 配置

- 官方 Flutter 3.47.7 / Dart 3.13.5，固定 revision `abaf9c523780a608bd46686fd5e53740a07077f8`。
- 最小离线 App：中文启动页、点击计数/重置、构建号和源码版本；原始 Bundle ID `com.example.ipaLab`，iOS 15.0+。
- `.github/workflows/ios-unsigned.yml`：手动触发，macos-26，分析/测试，`flutter build ios --release --no-codesign`，通用打包器，IPA 校验与 7 天 artifact。
- Windows 脚本：幂等准备、固定工具链、英文 junction、检查、提交后触发云端/等待/下载/校验；可选发布 Release。`-RunId` 从已有构建恢复，以远端 run 的源码提交为准，不重新编译；新构建按 run ID 差集识别，不依赖时区。
- 仓库没有证书、密码、描述文件或个人设备报告。云端 permissions 仅 contents: read，无 Apple secrets。
- Swift 原生入口为文档与模板，尚未实编独立 SwiftUI 项目。

## 已验证

- Flutter/Dart 命令实际运行成功；Windows SDK 已复用，未安装 Android SDK。
- 从英文 junction 运行后 Flutter analyze 通过、2 项 widget 测试通过、Web release 构建通过。
- Windows 准备脚本已实际运行并复用已有 Git/GitHub CLI/Python。
- actionlint 1.7.12 校验 Flutter 工作流和 Swift 原生模板通过（未配置额外 ShellCheck/Pyflakes）；PowerShell、Python 和打包 Bash 语法检查通过。
- **真实云端编译与 IPA 校验通过**：run #1 / `38326071388`，https://github.com/6666mumu/ios-ipa-lab/actions/runs/38326071388 。macOS 26.6.2、Xcode 26.6（17F113）。Windows 下载到 `artifacts/38326071388/` 并确认 6,046,367 字节，SHA-256 `a60aed0a1e47709215f14320cb71308ac0ff6a136895c1a39844ac30d58605b4`；主程序及两个 Flutter framework 为 arm64 iOS 真机且无残余代码签名。
- **完整新构建自动化通过**：`Build-Ipa.ps1 -Push -PublishRelease` 对构建 #2 实际完成本地检查、推送、识别新 run、等待云端成功、下载、源码/结构/哈希校验及 Release 发布；第二轮约 2 分 34 秒完成 macOS job。公开直链已实际匿名下载验证。
- **中断恢复和已有 Release 通过**：`Build-Ipa.ps1 -RunId 38326071388 -PublishRelease` 实际重新下载、复核已有产物和公开 Release，没有重新编译或覆盖 Release 资产。原 UTC 日期误解析和 gh artifact 不覆盖已有文件问题已修正。

## 未验证 / 下一步

- 真机全能签导入、签名、安装和按钮互动均待用户验证。描述文件若为显式 App ID，需要本地匹配 Bundle ID。
- 当前没有开发环境或云端构建阻塞。后续修改先读 README；新 App/第三方源码用独立工程与仓库，按实际依赖与权限适配。Actions artifact 保留 7 天；过期后使用对应 Release 直链，或提交新版本后构建。
- Swift 原生模板仅通过静态检查，未实编独立 SwiftUI 项目。
- 不从本仓库延伸为独立 watchOS 已可安装的结论。
