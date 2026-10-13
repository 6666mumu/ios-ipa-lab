# IPA Lab：Windows 编写，macOS 云端编译

最小离线 Flutter 测试 App，以及可重复使用的未签名 iOS IPA 构建环境。正式应用应建立各自独立的仓库。

## 固定环境

- Flutter **3.47.7** / Dart **3.13.5**，版本和源码 revision 见 `.flutter-version` 与 `.flutter-revision`。
- Windows：Git、GitHub CLI、Flutter；IPA 校验复用 Python 3.9+，没有额外 Python 包依赖。
- GitHub Actions：标准 `macos-26` 运行器，自带 Xcode。每次记录实际 Xcode/macOS 版本，运行器镜像会更新。
- iPhone：先下载未签名 IPA，再使用自己的本机签名工具签名。云端没有 Apple 登录、P12、密码或描述文件。

## Windows 命令

从项目目录运行 PowerShell：

```powershell
.\scripts\Setup-Windows.ps1
.\scripts\Run-Checks.ps1 -BuildWeb
```

安装脚本先检测现有工具，仅安装缺少的 Git/GitHub CLI/校验所需 Python。已有 Flutter 版本不匹配时会停止，允许用 `-SdkDirectory` 安装隔离版本；不会替换已有 SDK。Dart 随 Flutter 提供。

中文 Windows 项目路径可能触发当前 Dart LSP 的 UTF-8 长度问题；脚本自动创建指向同一源码的英文 junction，并从英文路径执行 Flutter。文件仍在原项目中。不要把 junction 当成另一份源码。

检查通过后，审阅并提交需要构建的文件：

```powershell
git add lib test pubspec.yaml pubspec.lock
git commit -m "Describe the app change"
.\scripts\Build-Ipa.ps1 -Push
```

`Build-Ipa.ps1` 会检查仓库、依赖锁、格式、分析和测试，确认本地提交与远端一致，触发一次 Actions，等待结果，下载产物到 `artifacts/<run-id>/`，再在 Windows 上复核 IPA 和 SHA-256。脚本不自动暂存或提交文件。

需要建立包含直接 IPA 下载链接的 GitHub Release 时，显式运行：

```powershell
.\scripts\Build-Ipa.ps1 -Push -PublishRelease
```

每次显式构建才使用云端运行器；普通代码提交不会自动重复构建。Actions artifact 保留 **7 天**；Release 资产不受这项 7 天保留设置控制。

如果终端中断，或构建已经在 Actions 上完成，使用实际 run ID 接着等待、下载、校验及发布，不要再次触发云端编译：

```powershell
.\scripts\Build-Ipa.ps1 -RunId 38326824410 -PublishRelease
```

`-RunId` 不与 `-Push` 混用。恢复时以该次云端构建的源码提交为准，允许本地已有后续文档修改；已有 Release 会下载并核对 IPA，不覆盖资产。新构建通过触发前后的 run ID 差集识别结果，不依赖 Windows 的时间或时区。

恢复下载依赖 Actions artifact 尚在 7 天保留期内；过期后直接使用对应 Release 的 IPA 下载链接，或构建新版本。

GitHub CLI 需要 `workflow` scope 上传 `.github/workflows`：

```powershell
gh auth refresh -h github.com -s workflow
```

此登录属于 GitHub，和 Apple Developer 会员无关。公开仓库的标准运行器执行时间免费；私有仓库消耗账号额度，额度与存储费用以 GitHub 官方账单为准。本项目不修改支付方式、预算或购买运行器。

## 已验证的测试 IPA

2026-10-13 的[构建 #1](https://github.com/6666mumu/ios-ipa-lab/actions/runs/38326071388)与[构建 #2](https://github.com/6666mumu/ios-ipa-lab/actions/runs/38326824410)均已完成真实 iOS Release 编译、未签名打包和 Windows 二次校验；第二轮验证了完整自动化入口。运行器实际为 macOS 26.6.2 / Xcode 26.6（17F113），Flutter 3.47.7 / Dart 3.13.5。

当前可[直接下载构建 #2 的 IPA](https://github.com/6666mumu/ios-ipa-lab/releases/download/ipa-build-38326824410/IPA-Lab-unsigned.ipa)，或查看[Release 与校验文件](https://github.com/6666mumu/ios-ipa-lab/releases/tag/ipa-build-38326824410)。源码为 `bb7e4688b365974b5417177cc156a2f64b5713db`，App 1.0.0、构建号 2、iOS 15.0+。

IPA 为 6,046,366 字节，SHA-256：`de1b648f5d2ef3d4596c40e7b2ec6e7654ce8e3761166bbe8215657b8818e3f9`。主程序与两个 Flutter framework 均为未签名 arm64 iOS 真机二进制，公开链接匿名下载后哈希一致。此记录证明编译和文件校验成功，iPhone 安装与运行仍待用户确认。

## 云端到底做了什么

1. 检查受 Git 管理的文件，拒绝签名材料和常见明文凭据。
2. 从 `flutter/flutter` 官方仓库检出固定版本，并核对源码 revision。
3. 使用 `pubspec.lock`，运行分析和交互测试。
4. 执行 `flutter build ios --release --no-codesign`，得到 `Runner.app`。
5. 在临时副本中移除可能存在的上游 ad-hoc 签名，使用 macOS `ditto` 打包 `Payload/Runner.app` 为 IPA。
6. 检查 ZIP CRC、plist、执行位、iOS arm64 平台和 Mach-O 签名状态；上传 IPA、校验报告、SHA-256、源码提交和工具版本。

`ci/package_unsigned_ipa.sh` 同样可用于原生 Xcode 构建出的 `.app`，不局限于 Flutter。原生扩展入口见 [docs/NATIVE_IOS.md](docs/NATIVE_IOS.md)。

## 在 iPhone 上验证

1. 从 Release 直接下载 `.ipa`，或从 Actions 下载 artifact ZIP 并解压。
2. 在全能签导入 IPA；在手机本地选择已有 P12 和对应描述文件，密码只在本地输入。
3. 核对最终 Bundle ID 和描述文件允许的 App ID，以及设备授权、有效期和权限。本测试包的原始 ID 为 `com.example.ipaLab`。显式 App ID 的描述文件不能直接签任意新 ID；必要时在本地签名工具中设置匹配的 Bundle ID，或请对应团队提供匹配的描述文件。
4. 签名并尝试安装，启动“云端构建测试”，点击“点击 +1”和“重新测试”。

看到页面且按钮有效，才完成真机运行确认。云端编译、IPA 结构检查、证书未过期，都不能替代安装和启动验证。这里没有验证全能签当前版本的导入行为，也没有验证证书在线撤销状态。

## 后续新 App / 开源项目

自己开发的新 App：单独创建项目与仓库，选择公开或私有，复制通用构建工具，设置该项目的 Flutter 版本、Bundle ID、应用版本和依赖锁，再构建。

只有源码的开源项目：先确认许可证、对应版本、iOS target、工具链和依赖，再在独立 fork/仓库试编译。Swift 项目使用 Xcode 流程；React Native、特殊 Rust/C++ 核心等要按项目实际方案适配。扩展、推送、iCloud、App Groups、HealthKit、私有组件及部分 DRM/账号服务有额外条件。

不要把别的项目的构建成功当成本项目可编译的证明。不要提交本机证书、描述文件、个人手机报告或原始设备数据。

## 接手入口

先读 `AGENTS.md`、`PROJECT_STATE.md` 和 `TODO.md`；重要变更记入 `CHANGELOG.md`。`artifacts/`、`dist/`、`.local/` 都只保存在本地。

## 官方依据

- Flutter 安装：https://docs.flutter.dev/install/manual
- Flutter iOS 部署：https://docs.flutter.dev/deployment/ios
- `--no-codesign` 实现：https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_tools/lib/src/commands/build_ios.dart
- GitHub 运行器：https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- GitHub Actions 计费：https://docs.github.com/en/billing/concepts/product-billing/github-actions
- Apple 描述文件机制：https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles
