# 项目连续性

先读 PROJECT_STATE.md、TODO.md，按需读 CHANGELOG.md。每个实质性变化后更新现有交接文件，使用模型无关的表述。

此仓库仅包含可公开的演示 App 与构建工具。禁止添加个人设备数据、P12、私钥、密码或 mobileprovision。云端只编译未签名 IPA；没有云端签名授权。

Windows 执行 Flutter 时优先使用 scripts/Run-Checks.ps1；它处理固定 SDK 和中文路径的英文 junction。不要因为 flutter doctor 缺 Android SDK 就安装 Android Studio，本项目当前目标是 iOS 云端编译与本地 Web 检查。

构建入口 scripts/Build-Ipa.ps1，-PublishRelease 表示额外发布 Release。审阅和提交源码后再运行，不自动暂存个人文件。外来开源项目应放进独立仓库，不覆盖本演示。

明确区分：文件已修改、静态检查、分析/测试/编译日志通过、IPA 校验通过，以及 iPhone 实际签名/安装/启动通过。未取得用户真机验收时，不把最后一项标记完成。
