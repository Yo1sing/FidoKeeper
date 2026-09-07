fn main() {
    let target = std::env::var("CARGO_CFG_TARGET_OS").expect("缺少目标平台");
    if target == "linux" || target == "macos" {
        pkg_config::Config::new()
            .atleast_version("1.13.0")
            .probe("libfido2")
            .expect("请安装 libfido2 开发库及 pkg-config");
    }
}
