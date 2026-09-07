# FidoKeeper

Flutter 桌面界面与独立 Rust 后端组成的本地 FIDO2 安全密钥管理工具。

## 实现边界

- `rust/src/api/models.rs`：当前项目的设备、凭证、指纹与偏好数据模型。
- `rust/src/api/keeper.rs`：统一命令入口和 Rust 状态管理；负责业务校验、设备切换、筛选、隐藏及关闭协调。
- `rust/src/authenticator/`：直接调用 libfido2 公开 C ABI 的独立设备封装。通过 `Authenticator` trait 支持模拟设备测试；每次操作独立创建会话，退出作用域时关闭设备和释放内存。PIN 使用 `Zeroizing` 清理 Rust 缓冲区。
- `rust/src/preferences.rs`：当前项目独立的配置读写实现。
- `lib/keeper_app.dart`、`lib/widgets/`：仅负责 UI、输入、弹窗、等待状态和快照展示。

不引用相邻项目源码，也不复用其操作分派或设备 API。提供设备扫描、连接、断开、隐藏、凭证读取/删除、PIN 修改、指纹读取/录入/删除、设备重置、搜索、主题与语言设置。原生标题栏保留但隐藏，使用自绘标题栏。

成功读取凭证后才切换当前设备；失败保留已有绑定。删除和重置需明确确认。关闭时等待当前硬件操作结束，并禁止排队任务重新打开硬件。设备 I/O 超时为 30 秒，指纹录入设置总时限。

## 动态库

### Windows

已包含 `dll/1.17.0-v143/`，按 `amd64`、`x86`、`arm64`、`arm` 分目录，各有 `fido2.dll`、`cbor.dll`、`crypto-56.dll`、`zlib1.dll` 及原配 `.lib`、`.pdb`。

Windows CMake 按目标架构自动将四个运行 DLL 与 Visual Studio 提供的可再分发运行库复制到 EXE 旁，覆盖直接构建和安装步骤；不需要手动复制。`.lib` 和 `.pdb` 保留在项目中，不作为发布运行时文件。

Rust 使用 EXE 所在目录的 `fido2.dll`，仅允许 DLL 所在目录和 Windows 系统目录解析其依赖。不能混用其他架构的 DLL。

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

## 配置

配置保存到 `FidoKeeper/settings.json`。上级目录为 Linux 的 `$XDG_CONFIG_HOME` 或 `~/.config`、macOS 的 `~/Library/Application Support`、Windows 的 `%LOCALAPPDATA%`。不保存 PIN 或凭证内容。

## 许可证

当前项目使用根目录 LICENSE。随包动态库保留各自上游许可义务。
