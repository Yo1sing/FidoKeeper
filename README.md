# FidoKeeper

Flutter 桌面界面与独立 Rust 后端组成的本地 FIDO2 安全密钥管理工具。

## 实现边界

- `rust/src/api/models.rs`：当前项目的设备、凭证、指纹与偏好数据模型。
- `rust/src/api/keeper.rs`：统一命令入口和 Rust 状态管理；负责业务校验、设备切换、筛选、隐藏及关闭协调。
- `rust/src/authenticator/`：直接调用 libfido2 公开 C ABI 的独立设备封装。通过 `Authenticator` trait 支持模拟设备测试；每次操作独立创建会话，退出作用域时关闭设备和释放内存。PIN 使用 `Zeroizing` 清理 Rust 缓冲区。
- `rust/src/preferences.rs`：当前项目独立的配置读写实现。
- `lib/keeper_app.dart`、`lib/widgets/`：仅负责 UI、输入、弹窗、等待状态和快照展示。

不引用相邻项目源码，也不复用其操作分派或设备 API。提供设备扫描、连接、断开、隐藏、凭证读取/删除、PIN 修改、指纹读取/录入/重命名/删除、设备重置、搜索、主题与语言设置。原生标题栏保留但隐藏，使用自绘标题栏。

选择认证器后立即输入 PIN，验证成功后会话保持解锁；凭证和指纹操作复用该 PIN，断开或关闭时清除。PIN 验证失败时保留已有选择。切换设备会清空已读取的凭证和指纹列表。删除和重置需明确确认。关闭时等待当前硬件操作结束，并禁止排队任务重新打开硬件。设备 I/O 超时为 30 秒，指纹录入设置总时限。

## 应用图标

各平台应用图标以 `assets/icon/fidokeeper-icon-v3.png` 为源图，由 `tool/generate_app_icons.py` 统一生成：Android 传统图标与 adaptive icon、iOS、macOS、Windows ICO、Web favicon/PWA 图标、Linux 打包图标。修改源图后运行：

```sh
python3 tool/generate_app_icons.py
```

脚本依赖 Pillow（`python3 -m pip install Pillow`）。`assets/icon/` 需要纳入版本控制，否则脚本无法重新生成。

## 动态库

### Windows

已包含 `dll/1.17.0-v143/`，按 `amd64`、`x86`、`arm64`、`arm` 分目录，各有 `fido2.dll`、`cbor.dll`、`crypto-56.dll`、`zlib1.dll` 及原配 `.lib`、`.pdb`。

Windows CMake 按目标架构自动将四个运行 DLL 与 Visual Studio 提供的可再分发运行库复制到 EXE 旁，覆盖直接构建和安装步骤；不需要手动复制。`.lib` 和 `.pdb` 保留在项目中，不作为发布运行时文件。

Rust 使用 EXE 所在目录的 `fido2.dll`，仅允许 DLL 所在目录和 Windows 系统目录解析其依赖。不能混用其他架构的 DLL。

打开 USB HID 认证器需要管理员权限，`windows/runner/runner.exe.manifest` 已声明 `requireAdministrator`，因此启动会出现 UAC；标准用户拒绝提权时进程不会启动。以管理员身份运行时调试需同样以管理员启动终端或 IDE 才能附加进程。

### Linux / macOS

分别动态加载系统 `libfido2.so.1` / `libfido2.1.dylib`。构建需要 libfido2 >= 1.13 的开发包和 pkg-config；Linux 还需 Flutter GTK 构建依赖。macOS 支持标准 Homebrew 路径。

### Android

不使用 libfido2。Kotlin 通过 USB Host / NFC 打开设备，Rust 发送 CTAP2 管理命令（凭证、PIN、指纹、重置）。首次插入 USB 密钥时需要系统授权；NFC 操作期间需保持贴紧。需要带 USB Host 或 NFC 的真机，模拟器无法访问安全密钥。

## 构建与验证

```sh
flutter pub get
flutter_rust_bridge_codegen generate --no-auto-upgrade-dependency
cargo test --manifest-path rust/Cargo.toml --offline
flutter test test/operation_dialog_test.dart
flutter analyze
flutter build linux --debug
# 在 Windows 上运行：flutter build windows
```

Linux 完整 UI 测试使用独立配置目录：

```sh
XDG_CONFIG_HOME="$PWD/build/test-config" flutter test integration_test/simple_test.dart -d linux
```

测试不会修改真实设备的凭证、PIN 或指纹，也不会重置设备。真实硬件写入与 Windows/macOS 运行仍需在对应环境验证。

## 发布包

推送 `main` 后由 `.github/workflows/build.yml` 并行产出：Linux 目录版与 deb / rpm / AppImage、Windows 目录版与 exe 安装包、Android 的 `arm64-v8a` 与 `armeabi-v7a` 两个 APK（release 构建沿用仓库配置里的 debug keystore）。

本地打 Linux 包，需要 `dpkg-deb`、`rpmbuild` 和 [appimagetool](https://github.com/AppImage/appimagetool)：

```sh
flutter build linux --release
packaging/linux/build_packages.sh build/linux/x64/release/bundle build/linux/packages
```

本地打 Windows 安装包：先用 `flutter build windows --release` 生成 `build/windows/x64/runner/Release`，再用 [Inno Setup](https://jrsoftware.org/isinfo.php) 编译 `packaging/windows/fidokeeper.iss`，输出到 `build/windows/packages/`。

三种包都依赖系统的 GTK3 与 libfido2（deb、rpm 已在元数据里声明依赖，AppImage 需要目标机自备）。deb 与 rpm 安装到 `/opt/fidokeeper`，其中 `lib/` 和 `data/` 必须与可执行文件保持同级：二进制按 `$ORIGIN/lib` 找动态库，Flutter 引擎按可执行文件位置找 `data/`。

### 版本号

版本名只在 `pubspec.yaml` 的 `version:` 一处维护，格式 `1.0.0+1`（前半段是版本名，后半段是本地构建号）。CI 不改这个文件，构建时注入：

- `--build-name` 取 pubspec 的版本名，`--build-number` 取 GitHub 运行号，于是 Windows 的 FileVersion、Android 的 versionCode、iOS 的 CFBundleVersion 每次运行都不同，能对上具体是哪次构建（分 ABI 打包时 Flutter 还会给 versionCode 加 1000×ABI 序号）。
- Linux 三种包的版本是 `<版本名>+<运行号>.<短 sha>`，例如 `fidokeeper_1.0.0+42.85cf7fa_amd64.deb`，下载到手就能看出是哪个提交构建的。
- `--build-name` 里不能带 `+`：Flutter 会把 name 与 number 拼成 `name+number` 再按 semver 解析，带 `+` 会解析失败并**静默**退回 `1.0.0` / build `0`（包看起来正常，版本是错的）。

本地打包可以用环境变量覆盖：`VERSION=1.2.3 RELEASE=2 packaging/linux/build_packages.sh ...`。rpm 用 `Version-Release` 判断新旧，同一个版本重新打包时要递增 `RELEASE`。

## 配置

配置保存到 `FidoKeeper/settings.json`。上级目录为 Linux 的 `$XDG_CONFIG_HOME` 或 `~/.config`、macOS 的 `~/Library/Application Support`、Windows 的 `%LOCALAPPDATA%`。不保存 PIN 或凭证内容。

## 许可证

当前项目使用根目录 LICENSE。随包动态库保留各自上游许可义务。
