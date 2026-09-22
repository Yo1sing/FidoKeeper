use crate::api::models::{
    BioTemplateSummary, CredentialSummary, DeviceSummary, HiddenAuthenticator, Preferences,
};
use crate::authenticator::enrollment::CANCELLED;
use crate::authenticator::{
    platform_authenticator, Authenticator, Inventory, DEVICE_TIMEOUT_MS, PIN_PERM_BIO,
    PIN_PERM_CRED,
};
use crate::preferences;
use std::sync::{
    atomic::{AtomicBool, AtomicU8, Ordering},
    Mutex, OnceLock,
};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CommandKind {
    Initialize,
    EnterFingerprints,
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
    RenameBio,
    Reset,
    Filter,
    Theme,
    Locale,
    Shutdown,
    DynamicColor,
    ColorSeed,
}

// 输入要求属于操作协议，界面只负责渲染对应字段。
#[derive(Clone, Debug, PartialEq)]
pub struct OperationInputs {
    pub ask_pin: bool,
    pub change_pin: bool,
    pub requires_confirmation: bool,
    /// 会打开设备。界面用它占用忙碌状态；筛选和偏好设置不占。
    pub touches_hardware: bool,
    /// 会改设备内容。关闭时要等满一次设备 I/O，避免写到一半进程退出。
    pub mutates_device: bool,
}

pub const FINGERPRINT_NAME_MAX_BYTES: usize = 64;
const READ_CLOSE_TIMEOUT_MS: u32 = 3_000;

#[flutter_rust_bridge::frb(sync)]
pub fn operation_inputs(kind: CommandKind) -> OperationInputs {
    let mutates_device = matches!(
        kind,
        CommandKind::ChangePin
            | CommandKind::Reset
            | CommandKind::DeleteCredential
            | CommandKind::DeleteBio
            | CommandKind::RenameBio
            | CommandKind::EnrollBio
    );
    let touches_hardware = mutates_device
        || matches!(
            kind,
            CommandKind::Initialize
                | CommandKind::Scan
                | CommandKind::Connect
                | CommandKind::ListCredentials
                | CommandKind::ListBio
                | CommandKind::EnterFingerprints
        );
    OperationInputs {
        ask_pin: kind == CommandKind::Connect,
        change_pin: kind == CommandKind::ChangePin,
        requires_confirmation: matches!(
            kind,
            CommandKind::Reset | CommandKind::DeleteCredential | CommandKind::DeleteBio
        ),
        touches_hardware,
        mutates_device,
    }
}

/// 写操作等待当前这次设备调用结束；读取类超时后可以先退出，句柄随进程回收。
#[flutter_rust_bridge::frb(sync)]
pub fn close_timeout_ms(kind: Option<CommandKind>) -> u32 {
    if kind.is_some_and(|kind| operation_inputs(kind).mutates_device) {
        DEVICE_TIMEOUT_MS as u32
    } else {
        READ_CLOSE_TIMEOUT_MS
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn color_seeds() -> Vec<String> {
    preferences::COLOR_SEEDS
        .iter()
        .map(|seed| (*seed).to_owned())
        .collect()
}

#[flutter_rust_bridge::frb(sync)]
pub fn default_color_seed() -> String {
    preferences::DEFAULT_COLOR_SEED.to_owned()
}

#[flutter_rust_bridge::frb(sync)]
pub fn supported_locales() -> Vec<String> {
    preferences::SUPPORTED_LOCALES
        .iter()
        .map(|code| (*code).to_owned())
        .collect()
}

#[flutter_rust_bridge::frb(sync)]
pub fn fingerprint_name_max_bytes() -> u16 {
    FINGERPRINT_NAME_MAX_BYTES as u16
}

#[derive(Clone, Debug)]
pub struct CommandError {
    pub cancelled: bool,
    pub message: String,
}

#[flutter_rust_bridge::frb(sync)]
pub fn enroll_captured() -> u8 {
    ENROLL_CAPTURED.load(Ordering::Relaxed)
}

#[flutter_rust_bridge::frb(sync)]
pub fn cancel_enrollment() -> bool {
    ENROLL_STATE
        .compare_exchange(1, 2, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
}

pub struct Command {
    pub kind: CommandKind,
    pub value: String,
    pub pin: String,
    pub new_pin: String,
    pub confirm_pin: String,
    pub confirmed: bool,
    /// 指纹新名称。和 PIN 分开，避免调用方把名称写进 PIN 字段。
    pub name: String,
}

#[derive(Clone)]
pub struct Snapshot {
    pub can_manage_credentials: bool,
    pub can_manage_fingerprints: bool,
    pub devices: Vec<DeviceSummary>,
    pub active: Option<DeviceSummary>,
    pub credentials: Vec<CredentialSummary>,
    pub existing: u64,
    pub remaining: u64,
    pub templates: Vec<BioTemplateSummary>,
    pub preferences: Preferences,
    pub query: String,
    pub credentials_loaded: bool,
    pub fingerprints_loaded: bool,
}

struct State {
    hardware: Box<dyn Authenticator + Send>,
    devices: Vec<DeviceSummary>,
    active: Option<DeviceSummary>,
    inventory: Option<Inventory>,
    templates: Vec<BioTemplateSummary>,
    preferences: Preferences,
    query: String,
    unlocked_pin: Option<zeroize::Zeroizing<String>>,
    credentials_loaded: bool,
    fingerprints_loaded: bool,
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
            unlocked_pin: None,
            credentials_loaded: false,
            fingerprints_loaded: false,
        }
    }
    fn snapshot(&self) -> Snapshot {
        Snapshot {
            can_manage_credentials: self
                .active
                .as_ref()
                .is_some_and(|d| d.credential_management && d.pin)
                && self.unlocked_pin.is_some(),
            can_manage_fingerprints: self.active.as_ref().is_some_and(|d| d.fingerprint)
                && self.unlocked_pin.is_some(),
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
            credentials_loaded: self.credentials_loaded,
            fingerprints_loaded: self.fingerprints_loaded,
        }
    }
    fn scan(&mut self) -> Result<(), String> {
        let devices = self.hardware.discover(&cancel_requested)?;
        if self
            .active
            .as_ref()
            .is_some_and(|a| !devices.iter().any(|d| d.path == a.path))
        {
            self.disconnect();
        }
        self.devices = devices;
        Ok(())
    }
    fn disconnect(&mut self) {
        self.hardware.discard_pin_token();
        self.active = None;
        self.inventory = None;
        self.templates.clear();
        self.unlocked_pin = None;
        self.credentials_loaded = false;
        self.fingerprints_loaded = false;
    }
    fn active(&self) -> Result<DeviceSummary, String> {
        self.active
            .clone()
            .ok_or_else(|| "请先选择认证器".to_owned())
    }
    fn session_pin(
        &self,
        provided: &zeroize::Zeroizing<String>,
    ) -> Result<zeroize::Zeroizing<String>, String> {
        if !provided.is_empty() {
            return Ok(zeroize::Zeroizing::new((**provided).clone()));
        }
        self.unlocked_pin
            .clone()
            .ok_or_else(|| "请先选择认证器并输入 PIN".to_owned())
    }
    fn apply(&mut self, command: Command) -> Result<(), String> {
        let Command {
            kind,
            value,
            pin,
            new_pin,
            confirm_pin,
            confirmed,
            name,
        } = command;
        let pin = zeroize::Zeroizing::new(pin);
        let new_pin = zeroize::Zeroizing::new(new_pin);
        let confirm_pin = zeroize::Zeroizing::new(confirm_pin);
        if operation_inputs(kind).requires_confirmation && !confirmed {
            return Err("请先确认此不可撤销操作".to_owned());
        }
        if kind == CommandKind::ChangePin && new_pin != confirm_pin {
            return Err("两次输入的 PIN 不一致".to_owned());
        }
        match kind {
            CommandKind::Initialize => {
                self.preferences = preferences::load()?;
                self.scan()?;
                return Ok(());
            }
            CommandKind::EnterFingerprints => {
                // 同一把已解锁的钥匙、列表没有改过时不再打开设备。
                if self.snapshot().can_manage_fingerprints && !self.fingerprints_loaded {
                    let device = self.active()?;
                    let pin = self.session_pin(&pin)?;
                    self.templates = self.hardware.fingerprints(&device.path, &pin)?;
                    self.fingerprints_loaded = true;
                }
                return Ok(());
            }
            CommandKind::Load => {
                self.preferences = preferences::load()?;
                return Ok(());
            }
            CommandKind::Scan => {
                self.scan()?;
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
            CommandKind::Theme
            | CommandKind::Locale
            | CommandKind::DynamicColor
            | CommandKind::ColorSeed => {
                let mut preferences = self.preferences.clone();
                match kind {
                    CommandKind::Theme => {
                        if !["system", "light", "dark"].contains(&value.as_str()) {
                            return Err("无效主题".to_owned());
                        }
                        preferences.theme = value;
                    }
                    CommandKind::Locale => {
                        if !preferences::SUPPORTED_LOCALES.contains(&value.as_str()) {
                            return Err("无效语言".to_owned());
                        }
                        preferences.locale = value;
                    }
                    CommandKind::DynamicColor => {
                        preferences.dynamic_color = match value.as_str() {
                            "true" => true,
                            "false" => false,
                            _ => return Err("无效动态取色".to_owned()),
                        };
                    }
                    CommandKind::ColorSeed => {
                        let seed = value.to_ascii_lowercase();
                        if !preferences::COLOR_SEEDS.contains(&seed.as_str()) {
                            return Err("无效配色".to_owned());
                        }
                        preferences.color_seed = seed;
                    }
                    _ => unreachable!(),
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
            CommandKind::Connect => {
                let device = self
                    .devices
                    .iter()
                    .find(|d| d.path == value)
                    .cloned()
                    .ok_or("认证器已断开，请重新扫描")?;
                if !device.pin {
                    return Err("此设备不支持 PIN".into());
                }
                if !device.credential_management && !device.fingerprint {
                    return Err("此设备不支持凭证管理或指纹".into());
                }
                let permissions = (u32::from(device.credential_management) * PIN_PERM_CRED)
                    | (u32::from(device.fingerprint) * PIN_PERM_BIO);
                // 验证失败时保留原选择和已读取的列表，成功后再切换。
                let (inventory, templates, credentials_loaded, fingerprints_loaded) =
                    if self.hardware.reusable_pin_token() {
                        self.hardware
                            .authenticate(&device.path, &pin, permissions)?;
                        (
                            None,
                            Vec::new(),
                            !device.credential_management,
                            !device.fingerprint,
                        )
                    } else if device.credential_management {
                        (
                            Some(
                                self.hardware
                                    .inventory(&device.path, &pin, &cancel_requested)?,
                            ),
                            Vec::new(),
                            true,
                            !device.fingerprint,
                        )
                    } else {
                        (
                            None,
                            self.hardware.fingerprints(&device.path, &pin)?,
                            true,
                            true,
                        )
                    };
                self.inventory = inventory;
                self.templates = templates;
                self.credentials_loaded = credentials_loaded;
                self.fingerprints_loaded = fingerprints_loaded;
                self.active = Some(device);
                self.unlocked_pin = Some(zeroize::Zeroizing::new((*pin).clone()));
            }
            CommandKind::ListCredentials => {
                let device = self.active()?;
                if !device.credential_management || !device.pin {
                    return Err("此设备不支持凭证管理或 PIN".into());
                }
                let pin = self.session_pin(&pin)?;
                self.inventory = Some(self.hardware.inventory(
                    &device.path,
                    &pin,
                    &cancel_requested,
                )?);
                self.credentials_loaded = true;
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
                let pin = self.session_pin(&pin)?;
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
                let pin = self.session_pin(&pin)?;
                self.hardware
                    .update_pin(&self.active()?.path, &pin, &new_pin)?;
                self.unlocked_pin = Some(zeroize::Zeroizing::new((*new_pin).clone()));
            }
            CommandKind::ListBio
            | CommandKind::EnrollBio
            | CommandKind::DeleteBio
            | CommandKind::RenameBio => {
                let device = self.active()?;
                if !device.fingerprint {
                    return Err("此设备不支持指纹管理".into());
                }
                let pin = self.session_pin(&pin)?;
                match kind {
                    CommandKind::ListBio => {
                        self.templates = self.hardware.fingerprints(&device.path, &pin)?;
                        self.fingerprints_loaded = true;
                    }
                    CommandKind::EnrollBio => {
                        ENROLL_CAPTURED.store(0, Ordering::Relaxed);
                        ENROLL_STATE.store(1, Ordering::SeqCst);
                        let result = self.hardware.enroll(
                            &device.path,
                            &pin,
                            &mut || {
                                ENROLL_CAPTURED.fetch_add(1, Ordering::Relaxed);
                            },
                            &|| {
                                SHUTTING_DOWN.load(Ordering::SeqCst)
                                    || ENROLL_STATE.load(Ordering::SeqCst) == 2
                            },
                        );
                        ENROLL_STATE.store(0, Ordering::SeqCst);
                        result?;
                        if SHUTTING_DOWN.load(Ordering::SeqCst) {
                            return Err("应用正在关闭".into());
                        }
                        self.templates = self.hardware.fingerprints(&device.path, &pin)?;
                        self.fingerprints_loaded = true;
                    }
                    CommandKind::RenameBio => {
                        let name = name.trim().to_owned();
                        if name.is_empty()
                            || name.contains('\0')
                            || name.len() > FINGERPRINT_NAME_MAX_BYTES
                        {
                            return Err(format!(
                                "指纹名称不能为空、不能包含空字符，且最多 {FINGERPRINT_NAME_MAX_BYTES} 字节"
                            ));
                        }
                        if !self.templates.iter().any(|t| t.id == value) {
                            return Err("指纹不存在，请刷新".into());
                        }
                        self.hardware
                            .rename_fingerprint(&device.path, &pin, &value, &name)?;
                        if let Some(template) = self.templates.iter_mut().find(|t| t.id == value) {
                            template.name = name;
                        }
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

/// 传给硬件层的取消判定：关闭请求置位后，设备循环在调用之间提前退出。
fn cancel_requested() -> bool {
    SHUTTING_DOWN.load(Ordering::SeqCst)
}
// 单个原子状态防止完成后到达的取消请求污染下一次录入。
// 0：空闲，1：录入中，2：已请求取消。
static ENROLL_STATE: AtomicU8 = AtomicU8::new(0);
static ENROLL_CAPTURED: AtomicU8 = AtomicU8::new(0);

// 桥接在后台执行；统一串行化状态与硬件调用，避免扫描、切换和关闭互相打断。
pub fn dispatch(command: Command) -> Result<Snapshot, CommandError> {
    let shutdown = command.kind == CommandKind::Shutdown;
    if shutdown {
        SHUTTING_DOWN.store(true, Ordering::SeqCst);
    }
    let mut state = STATE
        .get_or_init(|| Mutex::new(State::new()))
        .lock()
        .map_err(|_| CommandError {
            cancelled: false,
            message: "应用状态异常，请重启".to_owned(),
        })?;
    // 关闭请求可能先于已排队的桥接任务取得锁，禁止后者重新打开硬件。
    if !shutdown && SHUTTING_DOWN.load(Ordering::SeqCst) {
        return Err(CommandError {
            cancelled: false,
            message: "应用正在关闭".to_owned(),
        });
    }
    state.apply(command).map_err(|message| CommandError {
        cancelled: message == CANCELLED,
        message,
    })?;
    Ok(state.snapshot())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device(path: &str) -> DeviceSummary {
        DeviceSummary {
            transport: crate::api::models::Transport::from_path(path),
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
            unlocked_pin: None,
            credentials_loaded: true,
            fingerprints_loaded: false,
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
            name: String::new(),
        }
    }
    struct SimulatedDevice {
        fail: bool,
        fingerprint_reads: u32,
    }
    impl Authenticator for SimulatedDevice {
        fn reusable_pin_token(&self) -> bool {
            true
        }
        fn authenticate(&mut self, _: &str, pin: &str, _: u32) -> Result<(), String> {
            if self.fail {
                return Err("模拟 PIN 验证失败".into());
            }
            if pin.is_empty() {
                return Err("模拟缺少 PIN".into());
            }
            Ok(())
        }
        fn discover(&mut self, _: &dyn Fn() -> bool) -> Result<Vec<DeviceSummary>, String> {
            Ok(vec![])
        }
        fn inventory(
            &mut self,
            _: &str,
            _: &str,
            _: &dyn Fn() -> bool,
        ) -> Result<Inventory, String> {
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
        fn fingerprints(&mut self, _: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String> {
            self.fingerprint_reads += 1;
            if pin.is_empty() {
                return Err("模拟缺少 PIN".into());
            }
            Ok(vec![BioTemplateSummary {
                id: "t1".to_owned(),
                name: "finger".to_owned(),
            }])
        }
        fn enroll(
            &mut self,
            _: &str,
            _: &str,
            on_sample: &mut dyn FnMut(),
            _cancelled: &dyn Fn() -> bool,
        ) -> Result<(), String> {
            on_sample();
            on_sample();
            on_sample();
            Ok(())
        }
        fn remove_fingerprint(&mut self, _: &str, _: &str, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn rename_fingerprint(&mut self, _: &str, _: &str, _: &str, _: &str) -> Result<(), String> {
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
    fn input_contract_matches_session_operations() {
        assert!(operation_inputs(CommandKind::Connect).ask_pin);
        let change = operation_inputs(CommandKind::ChangePin);
        assert!(change.change_pin);
        assert!(!change.ask_pin);
        for kind in [
            CommandKind::Reset,
            CommandKind::DeleteCredential,
            CommandKind::DeleteBio,
        ] {
            let inputs = operation_inputs(kind);
            assert!(inputs.requires_confirmation);
            assert!(!inputs.ask_pin);
            assert!(!inputs.change_pin);
        }
        assert!(!operation_inputs(CommandKind::EnrollBio).requires_confirmation);
        assert!(operation_inputs(CommandKind::Reset).mutates_device);
        assert!(!operation_inputs(CommandKind::Scan).mutates_device);
        assert!(operation_inputs(CommandKind::Scan).touches_hardware);
        assert!(!operation_inputs(CommandKind::Filter).touches_hardware);
        assert_eq!(
            close_timeout_ms(Some(CommandKind::Reset)),
            DEVICE_TIMEOUT_MS as u32
        );
        assert_eq!(close_timeout_ms(Some(CommandKind::Scan)), 3_000);
        assert_eq!(close_timeout_ms(None), 3_000);
    }

    #[test]
    fn entering_fingerprints_uses_current_session_and_skips_unavailable_devices() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        state
            .apply(command(CommandKind::EnterFingerprints, ""))
            .unwrap();
        assert!(state.templates.is_empty());
        assert!(!state.snapshot().can_manage_credentials);
        state.active.as_mut().unwrap().fingerprint = true;
        state.unlocked_pin = Some(zeroize::Zeroizing::new("1234".into()));
        assert!(state.snapshot().can_manage_credentials);
        assert!(state.snapshot().can_manage_fingerprints);
        state
            .apply(command(CommandKind::EnterFingerprints, ""))
            .unwrap();
        assert_eq!(state.templates[0].id, "t1");
        assert!(state.fingerprints_loaded);
        state.templates.clear();
        state
            .apply(command(CommandKind::EnterFingerprints, ""))
            .unwrap();
        assert!(state.templates.is_empty());
        state.disconnect();
        state
            .apply(command(CommandKind::EnterFingerprints, ""))
            .unwrap();
        assert!(state.templates.is_empty());
        assert!(!state.snapshot().can_manage_fingerprints);
    }

    #[test]
    fn selecting_device_verifies_pin_then_switches_active() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        let mut request = command(CommandKind::Connect, "two");
        request.pin = "1234".to_owned();
        state.apply(request).unwrap();
        assert_eq!(state.active.as_ref().unwrap().path, "two");
        assert!(!state.snapshot().credentials_loaded);
        assert!(state.snapshot().credentials.is_empty());
        assert!(state.unlocked_pin.is_some());
        state
            .apply(command(CommandKind::ListCredentials, ""))
            .unwrap();
        assert!(state.snapshot().credentials_loaded);
        assert_eq!(state.snapshot().remaining, 20);
    }
    #[test]
    fn unlocked_session_reuses_pin_for_fingerprints() {
        let mut state = state();
        let mut bio = device("one");
        bio.fingerprint = true;
        state.devices[0] = bio.clone();
        state.active = Some(bio);
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        state.unlocked_pin = Some(zeroize::Zeroizing::new("1234".to_owned()));
        state.apply(command(CommandKind::ListBio, "")).unwrap();
        assert_eq!(state.templates[0].id, "t1");
        state.apply(command(CommandKind::Disconnect, "")).unwrap();
        assert!(state.unlocked_pin.is_none());
        assert_eq!(
            state.apply(command(CommandKind::ListBio, "")).unwrap_err(),
            "请先选择认证器"
        );
    }
    #[test]
    fn renaming_fingerprint_updates_template_name() {
        let mut state = state();
        let mut bio = device("one");
        bio.fingerprint = true;
        state.devices[0] = bio.clone();
        state.active = Some(bio);
        state.templates = vec![BioTemplateSummary {
            id: "t1".to_owned(),
            name: "finger".to_owned(),
        }];
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        state.unlocked_pin = Some(zeroize::Zeroizing::new("1234".to_owned()));
        let mut request = command(CommandKind::RenameBio, "t1");
        request.name = " 右手食指 ".to_owned();
        state.apply(request).unwrap();
        assert_eq!(state.templates[0].name, "右手食指");
        let mut empty = command(CommandKind::RenameBio, "t1");
        empty.name = "   ".to_owned();
        assert_eq!(
            state.apply(empty).unwrap_err(),
            "指纹名称不能为空、不能包含空字符，且最多 64 字节"
        );
    }
    #[test]
    fn enrolling_fingerprint_counts_each_sample() {
        let mut state = state();
        let mut bio = device("one");
        bio.fingerprint = true;
        state.devices[0] = bio.clone();
        state.active = Some(bio);
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        state.unlocked_pin = Some(zeroize::Zeroizing::new("1234".to_owned()));
        state.apply(command(CommandKind::EnrollBio, "")).unwrap();
        assert_eq!(enroll_captured(), 3);
        assert_eq!(state.templates[0].id, "t1");
    }
    #[test]
    fn rejected_device_commands_preserve_inventory_and_binding() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice {
            fail: true,
            fingerprint_reads: 0,
        });
        for (kind, value) in [
            (CommandKind::Connect, "two"),
            (CommandKind::DeleteCredential, "01"),
            (CommandKind::Reset, "one"),
        ] {
            let mut request = command(kind, value);
            request.confirmed = true;
            request.pin = "1234".to_owned();
            assert!(state.apply(request).is_err());
            assert_eq!(state.active.as_ref().unwrap().path, "one");
            assert_eq!(state.snapshot().existing, 1);
            assert_eq!(state.snapshot().credentials.len(), 1);
        }
    }
    #[test]
    fn successful_removal_updates_counts_and_rescan_releases_missing_device() {
        let mut state = state();
        state.hardware = Box::new(SimulatedDevice {
            fail: false,
            fingerprint_reads: 0,
        });
        state.unlocked_pin = Some(zeroize::Zeroizing::new("1234".to_owned()));
        let mut request = command(CommandKind::DeleteCredential, "01");
        request.confirmed = true;
        state.apply(request).unwrap();
        assert_eq!(state.snapshot().remaining, 10);
        assert!(state.snapshot().credentials.is_empty());
        state.apply(command(CommandKind::Scan, "")).unwrap();
        assert!(state.active.is_none());
    }

    #[test]
    fn failed_pin_preserves_selected_device_and_credentials() {
        let mut state = state();
        // 空 PIN 在打开硬件前被拒绝，验证失败不会覆盖已有选择。
        assert!(state.apply(command(CommandKind::Connect, "two")).is_err());
        assert!(state
            .apply(command(CommandKind::ListCredentials, ""))
            .is_err());
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
        assert!(state.unlocked_pin.is_none());
    }
    #[test]
    fn invalid_preferences_do_not_change_state_or_write_files() {
        let mut state = state();
        assert!(state.apply(command(CommandKind::Theme, "invalid")).is_err());
        assert!(state
            .apply(command(CommandKind::Locale, "invalid"))
            .is_err());
        assert!(state
            .apply(command(CommandKind::DynamicColor, "maybe"))
            .is_err());
        assert!(state
            .apply(command(CommandKind::ColorSeed, "ffffff"))
            .is_err());
        assert_eq!(state.preferences, Preferences::default());
    }
}
