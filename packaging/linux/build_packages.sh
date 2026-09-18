#!/usr/bin/env bash
# 把 flutter build linux 的产物打成 deb、rpm、AppImage。
#
# 用法：packaging/linux/build_packages.sh [bundle 目录] [输出目录]
#       VERSION=1.2.3 packaging/linux/build_packages.sh    # 覆盖版本号（默认取 pubspec.yaml）
#       APPIMAGETOOL=/path/to/appimagetool ...             # 指定 appimagetool
# 依赖：dpkg-deb、rpmbuild、appimagetool
set -euo pipefail

BUNDLE="${1:-build/linux/x64/release/bundle}"
OUTPUT="${2:-build/linux/packages}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$(dirname "$HERE")")"

APP_ID="dev.yo1sing.fidokeeper"
BIN="fidokeeper"
DISPLAY_NAME="FidoKeeper"
HOMEPAGE="https://github.com/Yo1sing/FidoKeeper"
SUMMARY="FIDO2 security key manager"
DESCRIPTION="FidoKeeper manages FIDO2 authenticators over USB HID and NFC: browsing and deleting credentials, changing the PIN, and enrolling or removing fingerprint templates."
DESKTOP_FILE="$HERE/$APP_ID.desktop"
METAINFO_FILE="$HERE/$APP_ID.metainfo.xml"
# 复用 macOS 应用的 512px 图标；没有独立的 Linux 图标资源
ICON_FILE="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
APPIMAGETOOL="${APPIMAGETOOL:-appimagetool}"

VERSION="${VERSION:-$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$ROOT/pubspec.yaml" | head -1)}"
[ -n "$VERSION" ] || { echo "无法从 pubspec.yaml 读取版本号" >&2; exit 1; }

case "$(uname -m)" in
  x86_64) DEB_ARCH=amd64; RPM_ARCH=x86_64 ;;
  aarch64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;;
  *) echo "暂不支持的架构：$(uname -m)" >&2; exit 1 ;;
esac

MAINTAINER="${MAINTAINER:-$(git -C "$ROOT" config user.name 2>/dev/null || true)}"
MAINTAINER_EMAIL="$(git -C "$ROOT" config user.email 2>/dev/null || true)"
MAINTAINER="${MAINTAINER:-Yo1sing} <${MAINTAINER_EMAIL:-84692985+Yo1sing@users.noreply.github.com}>"

for file in "$BUNDLE/$BIN" "$DESKTOP_FILE" "$METAINFO_FILE" "$ICON_FILE" "$ROOT/LICENSE"; do
  [ -e "$file" ] || { echo "缺少 $file" >&2; exit 1; }
done
command -v dpkg-deb >/dev/null || { echo "缺少 dpkg-deb" >&2; exit 1; }
command -v rpmbuild >/dev/null || { echo "缺少 rpmbuild" >&2; exit 1; }
command -v "$APPIMAGETOOL" >/dev/null || { echo "缺少 appimagetool" >&2; exit 1; }

mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 组装安装到文件系统各处的目录树。lib/ 与 data/ 必须和可执行文件同级：
# 二进制用 $ORIGIN/lib 找库，Flutter 引擎按可执行文件位置找 data/。
stage_filesystem() {
  local root="$1"
  install -d "$root/opt/$BIN" "$root/usr/bin" "$root/usr/share/applications" \
    "$root/usr/share/icons/hicolor/512x512/apps" "$root/usr/share/metainfo"
  cp -a "$BUNDLE/." "$root/opt/$BIN/"
  ln -sf "/opt/$BIN/$BIN" "$root/usr/bin/$BIN"
  install -m644 "$DESKTOP_FILE" "$root/usr/share/applications/$APP_ID.desktop"
  install -m644 "$ICON_FILE" "$root/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
  install -m644 "$METAINFO_FILE" "$root/usr/share/metainfo/$APP_ID.metainfo.xml"
}

build_deb() {
  local stage="$WORK/deb"
  stage_filesystem "$stage"
  install -d "$stage/usr/share/doc/$BIN" "$stage/DEBIAN"
  install -m644 "$ROOT/LICENSE" "$stage/usr/share/doc/$BIN/copyright"
  # 不写版本约束：新发行版用 t64 包名并通过 Provides 提供旧名，写死版本会匹配不上
  cat > "$stage/DEBIAN/control" <<EOF
Package: $BIN
Version: $VERSION
Architecture: $DEB_ARCH
Maintainer: $MAINTAINER
Section: utils
Priority: optional
Homepage: $HOMEPAGE
Depends: libgtk-3-0 | libgtk-3-0t64, libfido2-1 | libfido2-1t64
Description: $SUMMARY
 $DESCRIPTION
EOF
  # xz 比新版 dpkg-deb 默认的 zstd 在老发行版上兼容性更好
  dpkg-deb --root-owner-group -Z xz --build "$stage" "$OUTPUT/${BIN}_${VERSION}_${DEB_ARCH}.deb"
}

build_rpm() {
  local stage="$WORK/rpm-stage" topdir="$WORK/rpmbuild"
  stage_filesystem "$stage"
  install -d "$stage/usr/share/licenses/$BIN"
  install -m644 "$ROOT/LICENSE" "$stage/usr/share/licenses/$BIN/LICENSE"
  install -d "$topdir/SPECS"
  cat > "$topdir/SPECS/$BIN.spec" <<EOF
Name: $BIN
Version: $VERSION
Release: 1
Summary: $SUMMARY
License: AGPL-3.0-or-later
URL: $HOMEPAGE
BuildArch: $RPM_ARCH
# 包内自带的 libflutter_linux_gtk.so 会触发自动依赖检查，改为显式声明
AutoReqProv: no
Requires: gtk3
Requires: libfido2

%description
$DESCRIPTION

%install
mkdir -p %{buildroot}
cp -a "$stage/." %{buildroot}/

%files
/opt/$BIN
/usr/bin/$BIN
/usr/share/applications/$APP_ID.desktop
/usr/share/icons/hicolor/512x512/apps/$APP_ID.png
/usr/share/metainfo/$APP_ID.metainfo.xml
/usr/share/licenses/$BIN/LICENSE
EOF
  rpmbuild -bb --quiet --define "_topdir $topdir" --define "_rpmdir $topdir/RPMS" \
    "$topdir/SPECS/$BIN.spec"
  cp "$topdir/RPMS/$RPM_ARCH/"*.rpm "$OUTPUT/"
}

build_appimage() {
  local appdir="$WORK/AppDir"
  # AppDir 里保持 bundle 原样放在 usr/lib/$BIN，AppRun 负责定位，避免拆散 lib/ 与 data/
  install -d "$appdir/usr/lib/$BIN" "$appdir/usr/share/applications" \
    "$appdir/usr/share/icons/hicolor/512x512/apps" "$appdir/usr/share/metainfo"
  cp -a "$BUNDLE/." "$appdir/usr/lib/$BIN/"
  install -m644 "$DESKTOP_FILE" "$appdir/$APP_ID.desktop"
  install -m644 "$DESKTOP_FILE" "$appdir/usr/share/applications/$APP_ID.desktop"
  install -m644 "$ICON_FILE" "$appdir/$APP_ID.png"
  install -m644 "$ICON_FILE" "$appdir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
  install -m644 "$METAINFO_FILE" "$appdir/usr/share/metainfo/$APP_ID.metainfo.xml"
  cat > "$appdir/AppRun" <<EOF
#!/bin/sh
# AppRun 只负责定位 AppDir，应用自身的库由可执行文件的 \$ORIGIN/lib 提供
here="\$(dirname "\$(readlink -f "\$0")")"
exec "\$here/usr/lib/$BIN/$BIN" "\$@"
EOF
  chmod 755 "$appdir/AppRun"
  # 容器与 CI 里没有 FUSE，直接解包运行
  ARCH="$RPM_ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" \
    "$appdir" "$OUTPUT/${DISPLAY_NAME}-${VERSION}-${RPM_ARCH}.AppImage"
}

echo "打包 $DISPLAY_NAME $VERSION（$RPM_ARCH）→ $OUTPUT"
build_deb
build_rpm
build_appimage
ls -1sh "$OUTPUT"/*.deb "$OUTPUT"/*.rpm "$OUTPUT"/*.AppImage
