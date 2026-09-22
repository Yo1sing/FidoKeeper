use crate::api::models::Preferences;
use std::{collections::HashSet, fs, path::PathBuf};

fn location() -> Result<PathBuf, String> {
    #[cfg(target_os = "android")]
    {
        return Ok(crate::authenticator::android_files_dir()?.join("FidoKeeper/settings.json"));
    }
    #[cfg(not(target_os = "android"))]
    {
        let base = if cfg!(target_os = "windows") {
            std::env::var_os("LOCALAPPDATA").map(PathBuf::from)
        } else if cfg!(target_os = "macos") {
            std::env::var_os("HOME").map(|p| PathBuf::from(p).join("Library/Application Support"))
        } else {
            std::env::var_os("XDG_CONFIG_HOME")
                .map(PathBuf::from)
                .or_else(|| std::env::var_os("HOME").map(|p| PathBuf::from(p).join(".config")))
        };
        Ok(base
            .ok_or("找不到用户配置目录")?
            .join("FidoKeeper/settings.json"))
    }
}

/// 可保存的语言标识；"system" 表示跟随系统语言，由界面层解析。
pub(crate) const SUPPORTED_LOCALES: &[&str] = &["system", "zh-CN", "zh-TW", "en-US"];

/// 关闭动态取色时可选的种子色。界面直接使用这份列表。
pub(crate) const COLOR_SEEDS: &[&str] =
    &["356859", "1a73e8", "6750a4", "0f766e", "c2410c", "be123c"];
pub(crate) const DEFAULT_COLOR_SEED: &str = "356859";

fn decode(data: &[u8]) -> Result<Preferences, String> {
    let mut settings: Preferences =
        serde_json::from_slice(data).map_err(|_| "设置文件格式损坏".to_owned())?;
    if !SUPPORTED_LOCALES.contains(&settings.locale.as_str()) {
        settings.locale = "zh-CN".into();
    }
    if !["light", "dark", "system"].contains(&settings.theme.as_str()) {
        settings.theme = "system".into();
    }
    let seed = settings.color_seed.to_ascii_lowercase();
    if COLOR_SEEDS.contains(&seed.as_str()) {
        settings.color_seed = seed;
    } else {
        settings.color_seed = DEFAULT_COLOR_SEED.into();
    }
    let mut paths = HashSet::new();
    settings
        .hidden_authenticators
        .retain(|device| !device.path.is_empty() && paths.insert(device.path.clone()));
    Ok(settings)
}

pub fn load() -> Result<Preferences, String> {
    match fs::read(location()?) {
        Ok(data) => decode(&data),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Preferences::default()),
        Err(error) => Err(format!("读取设置失败：{error}")),
    }
}

pub fn save(settings: &Preferences) -> Result<(), String> {
    let path = location()?;
    let directory = path.parent().ok_or("设置目录无效")?;
    fs::create_dir_all(directory).map_err(|e| format!("创建设置目录失败：{e}"))?;
    let bytes = serde_json::to_vec_pretty(settings).map_err(|e| e.to_string())?;
    fs::write(path, bytes).map_err(|e| format!("保存设置失败：{e}"))
}

pub fn is_hidden(devices: &[crate::api::models::HiddenAuthenticator], path: &str) -> bool {
    devices.iter().any(|d| d.path == path)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn settings_path_uses_fidokeeper_directory() {
        let path = location().unwrap();
        assert!(path.ends_with("FidoKeeper/settings.json"));
        assert!(!path.to_string_lossy().contains("FidoKeeper-Flutter"));
    }
    #[test]
    fn settings_validate_defaults_and_deduplicate() {
        let p = decode(br#"{"theme":"bad","locale":"bad","hidden_authenticators":[{"path":"a","label":"A"},{"path":"a","label":"B"}]}"#).unwrap();
        assert_eq!(p.theme, "system");
        assert_eq!(p.locale, "zh-CN");
        assert_eq!(p.hidden_authenticators.len(), 1);
        assert!(decode(b"invalid").is_err());
        let traditional =
            decode(br#"{"theme":"light","locale":"zh-TW","hidden_authenticators":[]}"#).unwrap();
        assert_eq!(traditional.locale, "zh-TW");
        assert!(!traditional.dynamic_color);
        assert_eq!(traditional.color_seed, DEFAULT_COLOR_SEED);
        let dynamic = decode(
            br#"{"theme":"light","locale":"zh-CN","hidden_authenticators":[],"dynamic_color":true}"#,
        )
        .unwrap();
        assert!(dynamic.dynamic_color);
        let custom = decode(
            br#"{"theme":"light","locale":"zh-CN","hidden_authenticators":[],"color_seed":"1A73E8"}"#,
        )
        .unwrap();
        assert_eq!(custom.color_seed, "1a73e8");
        let bad_seed = decode(
            br#"{"theme":"light","locale":"zh-CN","hidden_authenticators":[],"color_seed":"ffffff"}"#,
        )
        .unwrap();
        assert_eq!(bad_seed.color_seed, DEFAULT_COLOR_SEED);
    }
    #[test]
    fn settings_accept_follow_system_locale() {
        let system =
            decode(br#"{"theme":"system","locale":"system","hidden_authenticators":[]}"#).unwrap();
        assert_eq!(system.locale, "system");
    }
}
