# Windows 运行库

libfido2 1.17.0（MSVC v143）动态库，按架构放在 `1.17.0-v143/` 下：amd64、x86、arm64、arm。各目录含运行时 `fido2.dll`、`cbor.dll`、`crypto-56.dll`、`zlib1.dll`，以及配套 `.lib`、`.pdb`。

Windows CMake 按目标架构把四个 DLL 复制到 EXE 旁，并附带 Visual Studio 可再分发运行库。`.lib` 和 `.pdb` 只留在仓库里，不随安装发布。

Linux / macOS 不使用本目录，分别加载系统 `libfido2.so.1` / `libfido2.1.dylib`。
