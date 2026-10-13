# 变更记录

## 2026-10-13

- GitHub workflow 授权完成后推送工作流，真实 macOS 云端构建 #1（38326071388）成功；iOS arm64 Release、未签名 IPA 打包、Windows 结构与 SHA-256 校验通过。
- 修正 Windows 构建入口误解析 UTC 日期、未识别已触发 run 的问题：改用触发前后的 run ID 差集，避免时区和时钟偏差；增加 `-RunId` 恢复下载发布，采用该 run 的真实源码提交，已有 Release 仅下载校验、不覆盖。
- 增加产物源码提交一致性检查；artifact 先下载到本轮独立暂存目录再更新，处理 GitHub CLI 拒绝覆盖已有文件导致无法恢复的问题。同步 README、PROJECT_STATE 和 TODO。真机签名、安装与启动尚未验证。

## 2026-10-12

- 创建 Flutter 最小离线测试 App，增加互动计数和构建标识；本地分析、2 项 widget 测试和 Web release 构建通过。
- 固定官方 Flutter 3.47.7 源码 revision 与 Dart 3.13.5；Windows 脚本复用已有工具，以英文 junction 处理中文路径的 LSP 问题。
- 新增只编译未签名 IPA 的 macOS Actions 工作流、通用打包器、Mach-O/ZIP/plist/哈希校验、Windows 触发和下载脚本。
- 新增 Swift 原生 Xcode 工作流模板与说明；尚未实编独立原生项目。
- 签名材料不进入 Git；真机导入、签名、安装和运行仍待用户验证。
