# 当前状态

更新：2026-10-13。阶段：Windows 环境和最小测试 App 已准备，首轮 macOS iOS 云端编译及 IPA 校验成功；正在完成自动化恢复与重复构建验证。

远端：https://github.com/6666mumu/ios-ipa-lab ，分支 main。用户已完成 GitHub CLI workflow 授权，工作流提交 `553f0cf331cab2f311ac0695abaa97763fe0444d` 已推送。不要重复要求授权或创建仓库。

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

## 未验证 / 下一步

- 首轮云端构建成功，但原 Windows 自动化因 JSON 日期转回字符串丢失 UTC 时区而未识别该 run；已改为 run ID 差集并增加 `-RunId` 恢复。应完成新入口的实际重复构建和 Release 下载验证，记录真实结果；先查 Actions 避免盲目重复触发。
- 真机全能签导入、签名、安装和按钮互动均待用户验证。描述文件若为显式 App ID，需要本地匹配 Bundle ID。
- 不从本仓库延伸为独立 watchOS 已可安装的结论。
