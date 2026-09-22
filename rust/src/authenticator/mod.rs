#[cfg(target_os = "android")]
mod android;
mod ctap;
pub(crate) mod enrollment;
mod native;
use crate::api::models::{BioTemplateSummary, CredentialSummary, DeviceSummary};
use native::*;
use std::{
    ffi::{CStr, CString},
    ptr::NonNull,
    slice,
};
use zeroize::Zeroizing;

pub struct Inventory {
    pub existing: u64,
    pub remaining: u64,
    pub credentials: Vec<CredentialSummary>,
}

/// PIN/UV 权限位，与 CTAP `pinUvAuthToken` 以及 libfido2 `FIDO_PUAT_*` 一致。
pub(crate) const PIN_PERM_CRED: u32 = 0x04;
pub(crate) const PIN_PERM_BIO: u32 = 0x08;

/// 令牌被设备作废时的错误码：0x33 = 51，0x38 = 56。用新 PIN 再协商一次即可。
pub(crate) fn stale_pin_token(error: &str) -> bool {
    error.contains("libfido2: 51")
        || error.contains("libfido2: 56")
        || error.contains("CTAP2: 51")
        || error.contains("CTAP2: 56")
}

pub trait Authenticator {
    /// 能否在会话之间复用 PIN 令牌。不能时，连接必须顺便完成会验证 PIN 的读取。
    fn reusable_pin_token(&self) -> bool {
        false
    }
    fn authenticate(&mut self, _path: &str, _pin: &str, _permissions: u32) -> Result<(), String> {
        Err("此认证器不能复用 PIN 令牌".into())
    }
    fn discard_pin_token(&mut self) {}
    fn discover(&mut self, cancelled: &dyn Fn() -> bool) -> Result<Vec<DeviceSummary>, String>;
    fn inventory(
        &mut self,
        path: &str,
        pin: &str,
        cancelled: &dyn Fn() -> bool,
    ) -> Result<Inventory, String>;
    fn remove_credential(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String>;
    fn update_pin(&mut self, path: &str, current: &str, replacement: &str) -> Result<(), String>;
    fn fingerprints(&mut self, path: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String>;
    fn enroll(
        &mut self,
        path: &str,
        pin: &str,
        on_sample: &mut dyn FnMut(),
        cancelled: &dyn Fn() -> bool,
    ) -> Result<(), String>;
    fn remove_fingerprint(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String>;
    fn rename_fingerprint(
        &mut self,
        path: &str,
        pin: &str,
        id: &str,
        name: &str,
    ) -> Result<(), String>;
    fn reset(&mut self, path: &str) -> Result<(), String>;
}

pub struct NativeAuthenticator {
    token: Option<PinUvToken>,
}

struct PinUvToken {
    path: String,
    perms: u32,
    bytes: Zeroizing<Vec<u8>>,
}

pub fn platform_authenticator() -> Box<dyn Authenticator + Send> {
    #[cfg(target_os = "android")]
    {
        Box::new(android::authenticator())
    }
    #[cfg(not(target_os = "android"))]
    {
        Box::new(NativeAuthenticator { token: None })
    }
}

#[cfg(target_os = "android")]
pub fn android_files_dir() -> Result<std::path::PathBuf, String> {
    android::files_dir()
}

struct Owned<T> {
    ptr: NonNull<T>,
    free: unsafe extern "C" fn(*mut *mut T),
}
impl<T> Owned<T> {
    fn new(ptr: *mut T, free: unsafe extern "C" fn(*mut *mut T)) -> Result<Self, String> {
        Ok(Self {
            ptr: NonNull::new(ptr).ok_or("libfido2 内存分配失败")?,
            free,
        })
    }
    fn raw(&self) -> *mut T {
        self.ptr.as_ptr()
    }
}
impl<T> Drop for Owned<T> {
    fn drop(&mut self) {
        unsafe { (self.free)(&mut self.ptr.as_ptr()) };
    }
}

struct Session {
    device: Owned<fido_dev_t>,
    api: &'static RawApi,
    opened: bool,
}
/// 真实读写操作的设备 I/O 上限。关闭写操作至少要等满这一次调用。
pub(crate) const DEVICE_TIMEOUT_MS: i32 = 30_000;
/// 扫描时只探测能力，不需要等满读写上限；设备无响应时关闭不必久等。
const DISCOVERY_TIMEOUT_MS: i32 = 5_000;
const SHUTDOWN_ERROR: &str = "应用正在关闭";

/// 关闭请求期间停止后续设备调用：等待时间只由当前一次调用决定，而不是剩余所有设备。
fn ensure_running(cancelled: &dyn Fn() -> bool) -> Result<(), String> {
    if cancelled() {
        return Err(SHUTDOWN_ERROR.to_owned());
    }
    Ok(())
}

/// 逐台探测设备：被取消时立即停止，打不开的设备跳过，全都打不开时给出带原因和权限提示的错误。
fn probe_devices(
    candidates: Vec<(String, String)>,
    cancelled: &dyn Fn() -> bool,
    mut probe: impl FnMut(&str, &str) -> Result<DeviceSummary, String>,
) -> Result<Vec<DeviceSummary>, String> {
    let mut devices = Vec::new();
    let mut failure: Option<String> = None;
    for (path, label) in candidates {
        ensure_running(cancelled)?;
        match probe(&path, &label) {
            Ok(device) => devices.push(device),
            Err(error) => {
                if failure.is_none() {
                    failure = Some(error);
                }
            }
        }
    }
    if devices.is_empty() {
        if let Some(error) = failure {
            return Err(format!(
                "无法访问认证器，请以管理员身份运行或检查设备权限：{error}"
            ));
        }
    }
    Ok(devices)
}

impl Session {
    fn open(path: &str) -> Result<Self, String> {
        Self::open_with_timeout(path, DEVICE_TIMEOUT_MS)
    }
    fn open_with_timeout(path: &str, timeout_ms: i32) -> Result<Self, String> {
        let api = RawApi::get()?;
        let path = CString::new(path).map_err(|_| "设备路径包含空字符")?;
        unsafe {
            let mut session = Self {
                device: Owned::new((api.fido_dev_new)(), api.fido_dev_free)?,
                api,
                opened: false,
            };
            api.check((api.fido_dev_set_timeout)(session.raw(), timeout_ms))?;
            api.check((api.fido_dev_open)(session.raw(), path.as_ptr()))?;
            session.opened = true;
            Ok(session)
        }
    }
    fn raw(&self) -> *mut fido_dev_t {
        self.device.raw()
    }
    fn bio_supported(&self) -> bool {
        unsafe {
            if let Ok(info) = Owned::new(
                (self.api.fido_cbor_info_new)(),
                self.api.fido_cbor_info_free,
            ) {
                if (self.api.fido_dev_get_cbor_info)(self.raw(), info.raw()) == 0 {
                    let names = (self.api.fido_cbor_info_options_name_ptr)(info.raw());
                    let len = (self.api.fido_cbor_info_options_len)(info.raw());
                    if !names.is_null() {
                        for n in 0..len {
                            // 选项值为 false 可表示尚未录入，存在该选项即声明能力。
                            if ["bioEnroll", "userVerificationMgmtPreview"]
                                .contains(&text(*names.add(n)).as_str())
                            {
                                return true;
                            }
                        }
                    }
                    // 选项表已经读到：没有生物识别声明时不必再发一次 bio info。
                    return false;
                }
            }
            if let Ok(info) =
                Owned::new((self.api.fido_bio_info_new)(), self.api.fido_bio_info_free)
            {
                return (self.api.fido_bio_dev_get_info)(self.raw(), info.raw()) == 0;
            }
            false
        }
    }
}
impl Drop for Session {
    fn drop(&mut self) {
        if self.opened {
            unsafe {
                (self.api.fido_dev_close)(self.raw());
            }
        }
    }
}

struct Manifest {
    raw: NonNull<fido_dev_info_t>,
    api: &'static RawApi,
    capacity: usize,
}
impl Drop for Manifest {
    fn drop(&mut self) {
        unsafe { (self.api.fido_dev_info_free)(&mut self.raw.as_ptr(), self.capacity) };
    }
}

fn secret(value: &str) -> Result<Zeroizing<Vec<u8>>, String> {
    if value.is_empty() || value.contains('\0') {
        return Err("PIN 不能为空或包含空字符".into());
    }
    let mut bytes = Zeroizing::new(value.as_bytes().to_vec());
    bytes.push(0);
    Ok(bytes)
}

unsafe fn text(value: *const std::ffi::c_char) -> String {
    if value.is_null() {
        String::new()
    } else {
        CStr::from_ptr(value).to_string_lossy().into_owned()
    }
}
fn encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
fn decode(value: &str) -> Result<Vec<u8>, String> {
    if value.is_empty()
        || !value.len().is_multiple_of(2)
        || !value.bytes().all(|b| b.is_ascii_hexdigit())
    {
        return Err("设备记录标识必须是非空十六进制字符串".into());
    }
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|part| {
            u8::from_str_radix(std::str::from_utf8(part).unwrap(), 16)
                .map_err(|_| "设备记录标识无效".into())
        })
        .collect()
}
unsafe fn identifier(data: *const u8, len: usize) -> Result<String, String> {
    if data.is_null() || len == 0 {
        return Err("设备返回空记录标识".into());
    }
    Ok(encode(slice::from_raw_parts(data, len)))
}

impl NativeAuthenticator {
    /// 把已缓存的 PIN 令牌装进新会话；库不支持或需要新权限时再协商。
    /// 返回后续调用应使用的 PIN 指针，令牌生效时为空指针。
    fn install_token(
        &mut self,
        session: &Session,
        path: &str,
        pin: &Zeroizing<Vec<u8>>,
        perms: u32,
        refresh: bool,
    ) -> Result<*const std::ffi::c_char, String> {
        let Some(puat) = session.api.puat() else {
            return Ok(pin.as_ptr().cast());
        };
        if !refresh {
            if let Some(token) = &self.token {
                if token.path == path && token.perms & perms == perms {
                    unsafe {
                        session.api.check((puat.set)(
                            session.raw(),
                            token.bytes.as_ptr(),
                            token.bytes.len(),
                        ))?;
                    }
                    return Ok(std::ptr::null());
                }
            }
        }
        let wanted = if refresh {
            perms
        } else {
            self.token
                .as_ref()
                .filter(|token| token.path == path)
                .map(|token| token.perms | perms)
                .unwrap_or(perms)
        };
        unsafe {
            session.api.check((puat.get)(
                session.raw(),
                wanted,
                std::ptr::null(),
                pin.as_ptr().cast(),
            ))?;
            let ptr = (puat.ptr)(session.raw());
            let len = (puat.len)(session.raw());
            if ptr.is_null() || len == 0 {
                return Err("认证器没有返回 PIN 令牌".into());
            }
            self.token = Some(PinUvToken {
                path: path.to_owned(),
                perms: wanted,
                bytes: Zeroizing::new(slice::from_raw_parts(ptr, len).to_vec()),
            });
        }
        Ok(std::ptr::null())
    }

    fn attempt<T>(
        &mut self,
        path: &str,
        pin: &Zeroizing<Vec<u8>>,
        perms: u32,
        timeout_ms: i32,
        refresh: bool,
        body: &mut impl FnMut(&Session, *const std::ffi::c_char) -> Result<T, String>,
    ) -> Result<T, String> {
        let session = Session::open_with_timeout(path, timeout_ms)?;
        let pin_ptr = self.install_token(&session, path, pin, perms, refresh)?;
        body(&session, pin_ptr)
    }

    /// 优先复用令牌。设备宣布令牌失效时清掉缓存，用 PIN 再协商一次。
    fn with_token<T>(
        &mut self,
        path: &str,
        pin: &Zeroizing<Vec<u8>>,
        perms: u32,
        timeout_ms: i32,
        body: &mut impl FnMut(&Session, *const std::ffi::c_char) -> Result<T, String>,
    ) -> Result<T, String> {
        let cached = self
            .token
            .as_ref()
            .is_some_and(|token| token.path == path && token.perms & perms == perms);
        match self.attempt(path, pin, perms, timeout_ms, false, body) {
            Err(error) if cached && stale_pin_token(&error) => {
                let wanted = self
                    .token
                    .as_ref()
                    .map(|token| token.perms | perms)
                    .unwrap_or(perms);
                self.token = None;
                self.attempt(path, pin, wanted, timeout_ms, true, body)
            }
            other => other,
        }
    }
}

impl Authenticator for NativeAuthenticator {
    fn reusable_pin_token(&self) -> bool {
        RawApi::get().ok().is_some_and(|api| api.puat().is_some())
    }
    fn authenticate(&mut self, path: &str, pin: &str, permissions: u32) -> Result<(), String> {
        let pin = secret(pin)?;
        self.with_token(path, &pin, permissions, DEVICE_TIMEOUT_MS, &mut |_, _| {
            Ok(())
        })
    }
    fn discard_pin_token(&mut self) {
        self.token = None;
    }
    fn discover(&mut self, cancelled: &dyn Fn() -> bool) -> Result<Vec<DeviceSummary>, String> {
        let api = RawApi::get()?;
        unsafe {
            let entries = Manifest {
                raw: NonNull::new((api.fido_dev_info_new)(64)).ok_or("无法分配设备列表")?,
                api,
                capacity: 64,
            };
            let mut count = 0;
            api.check((api.fido_dev_info_manifest)(
                entries.raw.as_ptr(),
                entries.capacity,
                &mut count,
            ))?;
            let mut candidates = Vec::new();
            for index in 0..count.min(entries.capacity) {
                let entry = (api.fido_dev_info_ptr)(entries.raw.as_ptr(), index);
                if entry.is_null() {
                    return Err("设备列表包含无效记录".into());
                }
                candidates.push((
                    text((api.fido_dev_info_path)(entry)),
                    format!(
                        "{} {}",
                        text((api.fido_dev_info_manufacturer_string)(entry)),
                        text((api.fido_dev_info_product_string)(entry))
                    )
                    .trim()
                    .to_owned(),
                ));
            }
            probe_devices(candidates, cancelled, |path, label| {
                let session = Session::open_with_timeout(path, DISCOVERY_TIMEOUT_MS)?;
                let ctap2 = (api.fido_dev_is_fido2)(session.raw());
                Ok(DeviceSummary {
                    transport: crate::api::models::Transport::from_path(path),
                    path: path.to_owned(),
                    label: if label.is_empty() {
                        "FIDO 认证器".into()
                    } else {
                        label.to_owned()
                    },
                    protocol: if ctap2 {
                        "CTAP2 / FIDO2"
                    } else {
                        "CTAP1 / U2F"
                    }
                    .into(),
                    credential_management: ctap2 && (api.fido_dev_supports_credman)(session.raw()),
                    pin: ctap2 && (api.fido_dev_supports_pin)(session.raw()),
                    fingerprint: ctap2 && session.bio_supported(),
                })
            })
        }
    }
    fn inventory(
        &mut self,
        path: &str,
        pin: &str,
        cancelled: &dyn Fn() -> bool,
    ) -> Result<Inventory, String> {
        ensure_running(cancelled)?;
        let pin = secret(pin)?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_CRED,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| {
                let api = session.api;
                unsafe {
                    if !(api.fido_dev_supports_credman)(session.raw()) {
                        return Err("认证器不支持凭证管理".into());
                    }
                    let metadata = Owned::new(
                        (api.fido_credman_metadata_new)(),
                        api.fido_credman_metadata_free,
                    )?;
                    let sites = Owned::new((api.fido_credman_rp_new)(), api.fido_credman_rp_free)?;
                    api.check((api.fido_credman_get_dev_metadata)(
                        session.raw(),
                        metadata.raw(),
                        pin_ptr,
                    ))?;
                    api.check((api.fido_credman_get_dev_rp)(
                        session.raw(),
                        sites.raw(),
                        pin_ptr,
                    ))?;
                    let mut credentials = Vec::new();
                    for site in 0..(api.fido_credman_rp_count)(sites.raw()) {
                        // 每个网站一次设备调用，逐个检查关闭请求，避免读完所有网站才释放锁。
                        ensure_running(cancelled)?;
                        let rp_id = text((api.fido_credman_rp_id)(sites.raw(), site));
                        if rp_id.is_empty() {
                            return Err("设备返回空网站标识".into());
                        }
                        let rp_name = text((api.fido_credman_rp_name)(sites.raw(), site));
                        let site_id = CString::new(rp_id.as_str()).map_err(|_| "网站标识无效")?;
                        let records =
                            Owned::new((api.fido_credman_rk_new)(), api.fido_credman_rk_free)?;
                        api.check((api.fido_credman_get_dev_rk)(
                            session.raw(),
                            site_id.as_ptr(),
                            records.raw(),
                            pin_ptr,
                        ))?;
                        for index in 0..(api.fido_credman_rk_count)(records.raw()) {
                            let record = (api.fido_credman_rk)(records.raw(), index);
                            if record.is_null() {
                                return Err("设备返回无效凭证".into());
                            }
                            credentials.push(CredentialSummary {
                                id: identifier(
                                    (api.fido_cred_id_ptr)(record),
                                    (api.fido_cred_id_len)(record),
                                )?,
                                rp_id: rp_id.clone(),
                                rp_name: if rp_name.is_empty() {
                                    rp_id.clone()
                                } else {
                                    rp_name.clone()
                                },
                                user_name: text((api.fido_cred_user_name)(record)),
                                user_display_name: text((api.fido_cred_display_name)(record)),
                            });
                        }
                    }
                    credentials.sort_by(|a, b| {
                        (&a.rp_id, &a.user_name, &a.id).cmp(&(&b.rp_id, &b.user_name, &b.id))
                    });
                    Ok(Inventory {
                        existing: (api.fido_credman_rk_existing)(metadata.raw()),
                        remaining: (api.fido_credman_rk_remaining)(metadata.raw()),
                        credentials,
                    })
                }
            },
        )
    }
    fn remove_credential(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode(id)?;
        let pin = secret(pin)?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_CRED,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| unsafe {
                session.api.check((session.api.fido_credman_del_dev_rk)(
                    session.raw(),
                    id.as_ptr(),
                    id.len(),
                    pin_ptr,
                ))
            },
        )
    }
    fn update_pin(&mut self, path: &str, current: &str, replacement: &str) -> Result<(), String> {
        let old = secret(current)?;
        let new = secret(replacement)?;
        let s = Session::open(path)?;
        let changed = unsafe {
            s.api.check((s.api.fido_dev_set_pin)(
                s.raw(),
                new.as_ptr().cast(),
                old.as_ptr().cast(),
            ))
        };
        if changed.is_ok() {
            self.token = None;
        }
        changed
    }
    fn fingerprints(&mut self, path: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String> {
        let pin = secret(pin)?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_BIO,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| {
                let api = session.api;
                unsafe {
                    let list = Owned::new(
                        (api.fido_bio_template_array_new)(),
                        api.fido_bio_template_array_free,
                    )?;
                    api.check((api.fido_bio_dev_get_template_array)(
                        session.raw(),
                        list.raw(),
                        pin_ptr,
                    ))?;
                    let mut result = Vec::new();
                    for index in 0..(api.fido_bio_template_array_count)(list.raw()) {
                        let template = (api.fido_bio_template)(list.raw(), index);
                        if template.is_null() {
                            return Err("设备返回无效指纹".into());
                        }
                        result.push(BioTemplateSummary {
                            id: identifier(
                                (api.fido_bio_template_id_ptr)(template),
                                (api.fido_bio_template_id_len)(template),
                            )?,
                            name: text((api.fido_bio_template_name)(template)),
                        });
                    }
                    Ok(result)
                }
            },
        )
    }
    fn enroll(
        &mut self,
        path: &str,
        pin: &str,
        on_sample: &mut dyn FnMut(),
        cancelled: &dyn Fn() -> bool,
    ) -> Result<(), String> {
        let pin = secret(pin)?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_BIO,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| {
                let api = session.api;
                unsafe {
                    let template =
                        Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
                    let progress =
                        Owned::new((api.fido_bio_enroll_new)(), api.fido_bio_enroll_free)?;
                    enrollment::run(
                        cancelled,
                        |first, wait_ms| {
                            if first {
                                api.check((api.fido_bio_dev_enroll_begin)(
                                    session.raw(),
                                    template.raw(),
                                    progress.raw(),
                                    wait_ms,
                                    pin_ptr,
                                ))?;
                            } else {
                                api.check((api.fido_bio_dev_enroll_continue)(
                                    session.raw(),
                                    template.raw(),
                                    progress.raw(),
                                    wait_ms,
                                ))?;
                            }
                            enrollment::sample_result(
                                (api.fido_bio_enroll_last_status)(progress.raw()),
                                (api.fido_bio_enroll_remaining_samples)(progress.raw()),
                                on_sample,
                            )
                        },
                        || api.check((api.fido_bio_dev_enroll_cancel)(session.raw())),
                    )
                }
            },
        )
    }
    fn remove_fingerprint(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode(id)?;
        let pin = secret(pin)?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_BIO,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| {
                let api = session.api;
                unsafe {
                    let template =
                        Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
                    api.check((api.fido_bio_template_set_id)(
                        template.raw(),
                        id.as_ptr(),
                        id.len(),
                    ))?;
                    api.check((api.fido_bio_dev_enroll_remove)(
                        session.raw(),
                        template.raw(),
                        pin_ptr,
                    ))
                }
            },
        )
    }
    fn rename_fingerprint(
        &mut self,
        path: &str,
        pin: &str,
        id: &str,
        name: &str,
    ) -> Result<(), String> {
        let id = decode(id)?;
        let pin = secret(pin)?;
        let name = CString::new(name).map_err(|_| "指纹名称包含空字符")?;
        self.with_token(
            path,
            &pin,
            PIN_PERM_BIO,
            DEVICE_TIMEOUT_MS,
            &mut |session, pin_ptr| {
                let api = session.api;
                unsafe {
                    let template =
                        Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
                    api.check((api.fido_bio_template_set_id)(
                        template.raw(),
                        id.as_ptr(),
                        id.len(),
                    ))?;
                    api.check((api.fido_bio_template_set_name)(
                        template.raw(),
                        name.as_ptr(),
                    ))?;
                    api.check((api.fido_bio_dev_set_template_name)(
                        session.raw(),
                        template.raw(),
                        pin_ptr,
                    ))
                }
            },
        )
    }
    fn reset(&mut self, path: &str) -> Result<(), String> {
        let s = Session::open(path)?;
        let result = unsafe { s.api.check((s.api.fido_dev_reset)(s.raw())) };
        if result.is_ok() {
            self.token = None;
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn stale_pin_token_matches_auth_failures_only() {
        assert!(stale_pin_token("PIN 令牌已失效，请重试（libfido2: 51）"));
        assert!(stale_pin_token("PIN 令牌已过期，请重试（CTAP2: 56）"));
        assert!(!stale_pin_token("PIN 码错误，请重试（libfido2: 49）"));
    }
    #[test]
    fn identifier_validation() {
        assert_eq!(decode(&encode(&[0, 255])).unwrap(), [0, 255]);
        for invalid in ["", "0", "é", "zz"] {
            assert!(decode(invalid).is_err());
        }
    }
    #[test]
    fn reject_invalid_pin_without_opening_hardware() {
        assert!(secret("").is_err());
        assert!(secret("a\0b").is_err());
    }
    #[test]
    fn native_symbols_are_available() {
        RawApi::get().unwrap();
    }
    fn candidate(path: &str) -> (String, String) {
        (path.to_owned(), path.to_owned())
    }
    fn summary(path: &str) -> DeviceSummary {
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
    #[test]
    fn discovery_stops_before_probing_when_cancelled() {
        let mut probed = 0;
        let error = probe_devices(vec![candidate("a"), candidate("b")], &|| true, |path, _| {
            probed += 1;
            Ok(summary(path))
        })
        .unwrap_err();
        assert_eq!(error, "应用正在关闭");
        assert_eq!(probed, 0);
    }
    #[test]
    fn discovery_skips_devices_it_cannot_open() {
        let devices = probe_devices(
            vec![candidate("a"), candidate("b"), candidate("c")],
            &|| false,
            |path, _| {
                if path == "b" {
                    Err("访问被拒绝".to_owned())
                } else {
                    Ok(summary(path))
                }
            },
        )
        .unwrap();
        assert_eq!(
            devices.iter().map(|d| d.path.as_str()).collect::<Vec<_>>(),
            ["a", "c"]
        );
    }
    #[test]
    fn discovery_reports_permission_hint_when_nothing_is_accessible() {
        let error = probe_devices(vec![candidate("a")], &|| false, |_, _| {
            Err("访问被拒绝".to_owned())
        })
        .unwrap_err();
        assert!(error.contains("访问被拒绝"), "{error}");
        assert!(error.contains("管理员"), "{error}");
        assert!(error.contains("设备权限"), "{error}");
    }
    #[test]
    fn discovery_reports_first_device_when_none_found() {
        let devices = probe_devices(vec![], &|| false, |path, _| Ok(summary(path))).unwrap();
        assert!(devices.is_empty());
    }
}
