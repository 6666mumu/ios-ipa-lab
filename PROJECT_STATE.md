# 当前状态

更新：2026-10-12。阶段：Windows 环境和最小测试 App 已准备，公开测试仓库源码已上传；等待完成 GitHub workflow 授权后进行首轮 iOS 云端构建。

远端：https://github.com/6666mumu/ios-ipa-lab ，分支 main。首次源码提交 `1e1978b` 未包含 `.github/workflows/ios-unsigned.yml`，该文件已在本地准备并经过检查。GitHub CLI 当前仅有 repo/read:org/gist，上传工作流需要 workflow scope；GitHub 连接器尝试创建工作流也返回 403。应由用户完成官方 CLI 授权，再上传本地已审阅的工作流。不要重复创建仓库或把权限拒绝写成云端构建失败。

- 官方 Flutter 3.47.7 / Dart 3.13.5，固定 revision `abaf9c523780a608bd46686fd5e53740a07077f8`。
- 最小离线 App：中文启动页、点击计数/重置、构建号和源码版本；原始 Bundle ID `com.example.ipaLab`，iOS 15.0+。
- `.github/workflows/ios-unsigned.yml`：手动触发，macos-26，分析/测试，`flutter build ios --release --no-codesign`，通用打包器，IPA 校验与 7 天 artifact。
- Windows 脚本：幂等准备、固定工具链、英文 junction、检查、提交后触发云端/等待/下载/校验；可选发布 Release。
- 仓库没有证书、密码、描述文件或个人设备报告。云端 permissions 仅 contents: read，无 Apple secrets。
- Swift 原生入口为文档与模板，尚未实编独立 SwiftUI 项目。

## 已验证

- Flutter/Dart 命令实际运行成功；Windows SDK 已复用，未安装 Android SDK。
- 从英文 junction 运行后 Flutter analyze 通过、2 项 widget 测试通过、Web release 构建通过。
- Windows 准备脚本已实际运行并复用已有 Git/GitHub CLI/Python。
- actionlint 1.7.12 校验 Flutter 工作流和 Swift 原生模板通过（未配置额外 ShellCheck/Pyflakes）；PowerShell、Python 和打包 Bash 语法检查通过。

## 未验证 / 下一步

- 首次云端 iOS 编译、IPA 下载与 Windows 二次校验尚未完成。下一位 Agent 应先检查 GitHub 授权和远端实际状态，避免重复触发。
- 真机全能签导入、签名、安装和按钮互动均待用户验证。描述文件若为显式 App ID，需要本地匹配 Bundle ID。
- 不从本仓库延伸为独立 watchOS 已可安装的结论。
