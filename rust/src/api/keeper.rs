use crate::api::models::{
    BioTemplateSummary, CredentialSummary, DeviceSummary, HiddenAuthenticator, Preferences,
};
use crate::authenticator::{Authenticator, Inventory, platform_authenticator};
use crate::preferences;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Mutex, OnceLock,
};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CommandKind {
    Load,
    Scan,
    Connect,
    Disconnect,
    Hide,
    Unhide,
    ListCredentials,
    DeleteCredential,
    ChangePin,
    ListBio,
    EnrollBio,
    DeleteBio,
    Reset,
    Filter,
    Theme,
    Locale,
    Shutdown,
}

pub struct Command {
    pub kind: CommandKind,
    pub value: String,
    pub pin: String,
    pub new_pin: String,
    pub confirm_pin: String,
    pub confirmed: bool,
}

#[derive(Clone)]
pub struct Snapshot {
    pub devices: Vec<DeviceSummary>,
    pub active: Option<DeviceSummary>,
    pub credentials: Vec<CredentialSummary>,
    pub existing: u64,
    pub remaining: u64,
    pub templates: Vec<BioTemplateSummary>,
    pub preferences: Preferences,
    pub query: String,
}

struct State {
    hardware: Box<dyn Authenticator + Send>,
    devices: Vec<DeviceSummary>,
    active: Option<DeviceSummary>,
    inventory: Option<Inventory>,
    templates: Vec<BioTemplateSummary>,
    preferences: Preferences,
    query: String,
}

impl State {
    fn new() -> Self {
        Self {
            hardware: platform_authenticator(),
            devices: vec![],
            active: None,
            inventory: None,
            templates: vec![],
            preferences: Preferences::default(),
            query: String::new(),
        }
    }
    fn snapshot(&self) -> Snapshot {
        Snapshot {
            devices: self
                .devices
                .iter()
                .filter(|d| {
                    !preferences::is_hidden(&self.preferences.hidden_authenticators, &d.path)
                })
                .cloned()
                .collect(),
            active: self.active.clone(),
            credentials: self
                .inventory
                .as_ref()
                .map(|i| {
                    let query = self.query.trim().to_lowercase();
                    i.credentials
                        .iter()
                        .filter(|c| {
                            [&c.rp_id, &c.rp_name, &c.user_name, &c.user_display_name]
                                .iter()
                                .any(|field| field.to_lowercase().contains(&query))
                        })
                        .cloned()
                        .collect()
                })
                .unwrap_or_default(),
            existing: self.inventory.as_ref().map(|i| i.existing).unwrap_or(0),
            remaining: self.inventory.as_ref().map(|i| i.remaining).unwrap_or(0),
            templates: self.templates.clone(),
            preferences: self.preferences.clone(),
            query: self.query.clone(),
        }
    }
    fn disconnect(&mut self) {
        self.active = None;
        self.inventory = None;
        self.templates.clear();
    }
    fn active(&self) -> Result<DeviceSummary, String> {
        self.active
            .clone()
            .ok_or_else(|| "请先连接认证器".to_owned())
    }
    fn apply(&mut self, command: Command) -> Result<(), String> {
        let Command {
            kind,
            value,
            pin,
            new_pin,
            confirm_pin,
            confirmed,
        } = command;
        let pin = zeroize::Zeroizing::new(pin);
        let new_pin = zeroize::Zeroizing::new(new_pin);
        let confirm_pin = zeroize::Zeroizing::new(confirm_pin);
        if matches!(
            kind,
            CommandKind::Reset | CommandKind::DeleteCredential | CommandKind::DeleteBio
        ) && !confirmed
        {
            return Err("请先确认此不可撤销操作".to_owned());
        }
        if kind == CommandKind::ChangePin && new_pin != confirm_pin {
            return Err("两次输入的 PIN 不一致".to_owned());
        }
        match kind {
            CommandKind::Load => {
                self.preferences = preferences::load()?;
                return Ok(());
            }
            CommandKind::Scan => {
                let devices = self.hardware.discover()?;
                if self
                    .active
                    .as_ref()
                    .is_some_and(|a| !devices.iter().any(|d| d.path == a.path))
                {
                    self.disconnect();
                }
                self.devices = devices;
                return Ok(());
            }
            CommandKind::Disconnect | CommandKind::Shutdown => {
                self.disconnect();
                return Ok(());
            }
            CommandKind::Filter => {
                self.query = value;
                return Ok(());
            }
            CommandKind::Theme | CommandKind::Locale => {
                let mut preferences = self.preferences.clone();
                if kind == CommandKind::Theme {
                    if !["system", "light", "dark"].contains(&value.as_str()) {
                        return Err("无效主题".to_owned());
                    }
                    preferences.theme = value;
                } else {
                    if !["zh-CN", "en-US"].contains(&value.as_str()) {
                        return Err("无效语言".to_owned());
                    }
                    preferences.locale = value;
                }
                preferences::save(&preferences)?;
                self.preferences = preferences;
                return Ok(());
            }
            CommandKind::Hide => {
                let device = self
                    .devices
                    .iter()
                    .find(|d| d.path == value)
                    .ok_or("认证器已断开")?
                    .clone();
                let mut preferences = self.preferences.clone();
                if !preferences::is_hidden(&preferences.hidden_authenticators, &value) {
                    preferences.hidden_authenticators.push(HiddenAuthenticator {
                        path: value.clone(),
                        label: device.label,
                    });
                }
                preferences::save(&preferences)?;
                self.preferences = preferences;
                if self.active.as_ref().is_some_and(|a| a.path == value) {
                    self.disconnect();
                }
                return Ok(());
            }
            CommandKind::Unhide => {
                let mut preferences = self.preferences.clone();
                preferences
                    .hidden_authenticators
                    .retain(|d| d.path != value);
                preferences::save(&preferences)?;
                self.preferences = preferences;
                return Ok(());
            }
            CommandKind::Connect | CommandKind::ListCredentials => {
                let device = if kind == CommandKind::Connect {
                    self.devices
                        .iter()
                        .find(|d| d.path == value)
                        .cloned()
                        .ok_or("认证器已断开，请重新扫描")?
                } else {
                    self.active()?
                };
                if !device.credential_management || !device.pin {
                    return Err("此设备不支持凭证管理或 PIN".into());
                }
                let inventory = self.hardware.inventory(&device.path, &pin)?;
                if self.active.as_ref().is_none_or(|a| a.path != device.path) {
                    self.templates.clear();
                }
                self.active = Some(device);
                self.inventory = Some(inventory);
            }
            CommandKind::DeleteCredential => {
                let device = self.active()?;
                if !self
                    .inventory
                    .as_ref()
                    .is_some_and(|i| i.credentials.iter().any(|c| c.id == value))
                {
                    return Err("凭证不存在，请刷新".into());
                }
                self.hardware
                    .remove_credential(&device.path, &pin, &value)?;
                if let Some(inventory) = &mut self.inventory {
                    inventory.credentials.retain(|c| c.id != value);
                    inventory.existing = inventory.existing.saturating_sub(1);
                    inventory.remaining = inventory.remaining.saturating_add(1);
                }
            }
            CommandKind::ChangePin => {
                if new_pin.chars().count() < 4 || new_pin.len() > 63 || new_pin.contains('\0') {
                    return Err("新 PIN 至少 4 个字符、最多 63 字节且不能包含空字符".into());
                }
                self.hardware
                    .update_pin(&self.active()?.path, &pin, &new_pin)?;
            }
            CommandKind::ListBio | CommandKind::EnrollBio | CommandKind::DeleteBio => {
                let device = self.active()?;
                if !device.fingerprint {
                    return Err("此设备不支持指纹管理".into());
                }
                match kind {
                    CommandKind::ListBio => {
                        self.templates = self.hardware.fingerprints(&device.path, &pin)?
                    }
                    CommandKind::EnrollBio => {
                        self.hardware.enroll(&device.path, &pin)?;
                        self.templates.clear();
                    }
                    _ => {
                        if !self.templates.iter().any(|t| t.id == value) {
                            return Err("指纹不存在，请刷新".into());
                        }
                        self.hardware
                            .remove_fingerprint(&device.path, &pin, &value)?;
                        self.templates.retain(|t| t.id != value);
                    }
                }
            }
            CommandKind::Reset => {
                let device = self
                    .devices
                    .iter()
                    .find(|d| d.path == value)
                    .ok_or("认证器已断开")?;
                self.hardware.reset(&device.path)?;
                self.disconnect();
                self.devices.clear();
            }
        }
        Ok(())
    }
}

static STATE: OnceLock<Mutex<State>> = OnceLock::new();
static SHUTTING_DOWN: AtomicBool = AtomicBool::new(false);

// 桥接在后台执行；统一串行化状态与硬件调用，避免扫描、切换和关闭互相打断。
pub fn dispatch(command: Command) -> Result<Snapshot, String> {
    let shutdown = command.kind == CommandKind::Shutdown;
    if shutdown {
        SHUTTING_DOWN.store(true, Ordering::SeqCst);
    }
    let mut state = STATE
        .get_or_init(|| Mutex::new(State::new()))
        .lock()
        .map_err(|_| "应用状态异常，请重启".to_owned())?;
    // 关闭请求可能先于已排队的桥接任务取得锁，禁止后者重新打开硬件。
    if !shutdown && SHUTTING_DOWN.load(Ordering::SeqCst) {
        return Err("应用正在关闭".to_owned());
    }
    state.apply(command)?;
    Ok(state.snapshot())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device(path: &str) -> DeviceSummary {
        DeviceSummary {
            label: path.to_owned(),
            path: path.to_owned(),
            protocol: "CTAP2".to_owned(),
            credential_management: true,
            pin: true,
            fingerprint: false,
        }
    }
    fn state() -> State {
        State {
            hardware: platform_authenticator(),
            devices: vec![device("one"), device("two")],
            active: Some(device("one")),
            inventory: Some(Inventory {
                existing: 1,
                remaining: 9,
                credentials: vec![CredentialSummary {
                    id: "01".to_owned(),
                    rp_id: "example.com".to_owned(),
                    rp_name: "Example".to_owned(),
                    user_name: "Alice".to_owned(),
                    user_display_name: "Alice Zhang".to_owned(),
                }],
            }),
            templates: vec![],
            preferences: Preferences::default(),
            query: String::new(),
        }
    }
    fn command(kind: CommandKind, value: &str) -> Command {
        Command {
            kind,
            value: value.to_owned(),
            pin: String::new(),
            new_pin: String::new(),
            confirm_pin: String::new(),
            confirmed: false,
        }
    }
    struct SimulatedDevice {
        fail: bool,
    }
    impl Authenticator for SimulatedDevice {
        fn discover(&mut self) -> Result<Vec<DeviceSummary>, String> {
            Ok(vec![])
        }
        fn inventory(&mut self, _: &str, _: &str) -> Result<Inventory, String> {
            if self.fail {
                return Err("模拟 PIN 验证失败".into());
            }
            Ok(Inventory {
                existing: 0,
                remaining: 20,
                credentials: vec![],
            })
        }
        fn remove_credential(&mut self, _: &str, _: &str, _: &str) -> Result<(), String> {
            if self.fail {
                Err("模拟删除失败".into())
            } else {
                Ok(())
            }
        }
        fn update_pin(&mut self, _: &str, _: &str, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn fingerprints(&mut self, _: &str, _: &str) -> Result<Vec<BioTemplateSummary>, String> {
            Ok(vec![])
        }
        fn enroll(&mut self, _: &str, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn remove_fingerprint(&mut self, _: &str, _: &str, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn reset(&mut self, _: &str) -> Result<(), String> {
            if self.fail {
                Err("模拟重置失败".into())
            } else {
                Ok(())
            }
        }
    }
    #[test]
    fn successful_connection_commits_device_and_inventory_together() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice { fail: false });
        state.apply(command(CommandKind::Connect, "two")).unwrap();
        assert_eq!(state.active.as_ref().unwrap().path, "two");
        assert_eq!(state.snapshot().remaining, 20);
        assert!(state.snapshot().credentials.is_empty());
    }
    #[test]
    fn rejected_device_commands_preserve_inventory_and_binding() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice { fail: true });
        for (kind, value) in [
            (CommandKind::Connect, "two"),
            (CommandKind::DeleteCredential, "01"),
            (CommandKind::Reset, "one"),
        ] {
            let mut request = command(kind, value);
            request.confirmed = true;
            assert!(state.apply(request).is_err());
            assert_eq!(state.active.as_ref().unwrap().path, "one");
            assert_eq!(state.snapshot().existing, 1);
            assert_eq!(state.snapshot().credentials.len(), 1);
        }
    }
    #[test]
    fn successful_removal_updates_counts_and_rescan_releases_missing_device() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice { fail: false });
        let mut request = command(CommandKind::DeleteCredential, "01");
        request.confirmed = true;
        state.apply(request).unwrap();
        assert_eq!(state.snapshot().remaining, 10);
        assert!(state.snapshot().credentials.is_empty());
        state.apply(command(CommandKind::Scan, "")).unwrap();
        assert!(state.active.is_none());
    }

    #[test]
    fn failed_connection_preserves_active_device_and_credentials() {
        let mut state = state();
        // 空 PIN 在打开硬件前被拒绝，验证失败不会覆盖已有绑定。
        assert!(state.apply(command(CommandKind::Connect, "two")).is_err());
        assert_eq!(state.active.as_ref().unwrap().path, "one");
        assert_eq!(state.snapshot().credentials.len(), 1);
    }
    #[test]
    fn destructive_commands_require_confirmation_before_accessing_hardware() {
        let mut state = state();
        for kind in [
            CommandKind::DeleteCredential,
            CommandKind::DeleteBio,
            CommandKind::Reset,
        ] {
            assert_eq!(
                state.apply(command(kind, "one")).unwrap_err(),
                "请先确认此不可撤销操作"
            );
        }
        assert_eq!(state.snapshot().existing, 1);
    }
    #[test]
    fn filtering_and_hidden_devices_are_applied_in_rust() {
        let mut state = state();
        state
            .preferences
            .hidden_authenticators
            .push(HiddenAuthenticator {
                path: "two".to_owned(),
                label: "two".to_owned(),
            });
        state.apply(command(CommandKind::Filter, "ALICE")).unwrap();
        assert_eq!(state.snapshot().credentials.len(), 1);
        assert_eq!(state.snapshot().devices.len(), 1);
        state
            .apply(command(CommandKind::Filter, "missing"))
            .unwrap();
        assert!(state.snapshot().credentials.is_empty());
        assert_eq!(state.snapshot().existing, 1);
    }
    #[test]
    fn pin_confirmation_is_validated_in_rust() {
        let mut state = state();
        let mut input = command(CommandKind::ChangePin, "");
        input.new_pin = "1234".to_owned();
        input.confirm_pin = "5678".to_owned();
        assert_eq!(state.apply(input).unwrap_err(), "两次输入的 PIN 不一致");
    }
    #[test]
    fn shutdown_releases_binding_and_sensitive_inventory() {
        let mut state = state();
        state.apply(command(CommandKind::Shutdown, "")).unwrap();
        assert!(state.snapshot().active.is_none());
        assert!(state.snapshot().credentials.is_empty());
        assert!(state.snapshot().templates.is_empty());
    }
    #[test]
    fn invalid_preferences_do_not_change_state_or_write_files() {
        let mut state = state();
        assert!(state.apply(command(CommandKind::Theme, "invalid")).is_err());
        assert_eq!(state.preferences, Preferences::default());
    }
}
