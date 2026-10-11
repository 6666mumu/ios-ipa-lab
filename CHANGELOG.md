# 变更记录

## 2026-10-12

- 创建 Flutter 最小离线测试 App，增加互动计数和构建标识；本地分析、2 项 widget 测试和 Web release 构建通过。
- 固定官方 Flutter 3.47.7 源码 revision 与 Dart 3.13.5；Windows 脚本复用已有工具，以英文 junction 处理中文路径的 LSP 问题。
- 新增只编译未签名 IPA 的 macOS Actions 工作流、通用打包器、Mach-O/ZIP/plist/哈希校验、Windows 触发和下载脚本。
- 新增 Swift 原生 Xcode 工作流模板与说明；尚未实编独立原生项目。
- 签名材料不进入 Git；真机导入、签名、安装和运行仍待用户验证。
