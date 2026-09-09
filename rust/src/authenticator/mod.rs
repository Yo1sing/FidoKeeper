#[cfg(target_os = "android")]
mod android;
mod ctap;
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

pub trait Authenticator {
    fn discover(&mut self) -> Result<Vec<DeviceSummary>, String>;
    fn inventory(&mut self, path: &str, pin: &str) -> Result<Inventory, String>;
    fn remove_credential(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String>;
    fn update_pin(&mut self, path: &str, current: &str, replacement: &str) -> Result<(), String>;
    fn fingerprints(&mut self, path: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String>;
    fn enroll(&mut self, path: &str, pin: &str) -> Result<(), String>;
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

pub struct NativeAuthenticator;

pub fn platform_authenticator() -> Box<dyn Authenticator + Send> {
    #[cfg(target_os = "android")]
    {
        Box::new(android::authenticator())
    }
    #[cfg(not(target_os = "android"))]
    {
        Box::new(NativeAuthenticator)
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
impl Session {
    fn open(path: &str) -> Result<Self, String> {
        let api = RawApi::get()?;
        let path = CString::new(path).map_err(|_| "设备路径包含空字符")?;
        unsafe {
            let mut session = Self {
                device: Owned::new((api.fido_dev_new)(), api.fido_dev_free)?,
                api,
                opened: false,
            };
            api.check((api.fido_dev_set_timeout)(session.raw(), 30_000))?;
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

impl Authenticator for NativeAuthenticator {
    fn discover(&mut self) -> Result<Vec<DeviceSummary>, String> {
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
            let mut result = Vec::new();
            for index in 0..count.min(entries.capacity) {
                let entry = (api.fido_dev_info_ptr)(entries.raw.as_ptr(), index);
                if entry.is_null() {
                    return Err("设备列表包含无效记录".into());
                }
                let path = text((api.fido_dev_info_path)(entry));
                let label = format!(
                    "{} {}",
                    text((api.fido_dev_info_manufacturer_string)(entry)),
                    text((api.fido_dev_info_product_string)(entry))
                )
                .trim()
                .to_owned();
                let session = Session::open(&path)?;
                let ctap2 = (api.fido_dev_is_fido2)(session.raw());
                result.push(DeviceSummary {
                    transport: crate::api::models::Transport::from_path(&path),
                    path,
                    label: if label.is_empty() {
                        "FIDO 认证器".into()
                    } else {
                        label
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
                });
            }
            Ok(result)
        }
    }
    fn inventory(&mut self, path: &str, pin: &str) -> Result<Inventory, String> {
        let pin = secret(pin)?;
        let session = Session::open(path)?;
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
                pin.as_ptr().cast(),
            ))?;
            api.check((api.fido_credman_get_dev_rp)(
                session.raw(),
                sites.raw(),
                pin.as_ptr().cast(),
            ))?;
            let mut credentials = Vec::new();
            for site in 0..(api.fido_credman_rp_count)(sites.raw()) {
                let rp_id = text((api.fido_credman_rp_id)(sites.raw(), site));
                if rp_id.is_empty() {
                    return Err("设备返回空网站标识".into());
                }
                let rp_name = text((api.fido_credman_rp_name)(sites.raw(), site));
                let site_id = CString::new(rp_id.as_str()).map_err(|_| "网站标识无效")?;
                let records = Owned::new((api.fido_credman_rk_new)(), api.fido_credman_rk_free)?;
                api.check((api.fido_credman_get_dev_rk)(
                    session.raw(),
                    site_id.as_ptr(),
                    records.raw(),
                    pin.as_ptr().cast(),
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
    }
    fn remove_credential(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode(id)?;
        let pin = secret(pin)?;
        let s = Session::open(path)?;
        unsafe {
            s.api.check((s.api.fido_credman_del_dev_rk)(
                s.raw(),
                id.as_ptr(),
                id.len(),
                pin.as_ptr().cast(),
            ))
        }
    }
    fn update_pin(&mut self, path: &str, current: &str, replacement: &str) -> Result<(), String> {
        let old = secret(current)?;
        let new = secret(replacement)?;
        let s = Session::open(path)?;
        unsafe {
            s.api.check((s.api.fido_dev_set_pin)(
                s.raw(),
                new.as_ptr().cast(),
                old.as_ptr().cast(),
            ))
        }
    }
    fn fingerprints(&mut self, path: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String> {
        let pin = secret(pin)?;
        let s = Session::open(path)?;
        let api = s.api;
        unsafe {
            let list = Owned::new(
                (api.fido_bio_template_array_new)(),
                api.fido_bio_template_array_free,
            )?;
            api.check((api.fido_bio_dev_get_template_array)(
                s.raw(),
                list.raw(),
                pin.as_ptr().cast(),
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
    }
    fn enroll(&mut self, path: &str, pin: &str) -> Result<(), String> {
        let pin = secret(pin)?;
        let s = Session::open(path)?;
        let api = s.api;
        unsafe {
            let template = Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
            let progress = Owned::new((api.fido_bio_enroll_new)(), api.fido_bio_enroll_free)?;
            let result = (|| {
                api.check((api.fido_bio_dev_enroll_begin)(
                    s.raw(),
                    template.raw(),
                    progress.raw(),
                    30_000,
                    pin.as_ptr().cast(),
                ))?;
                // 限制整次录入时长，设备无进展时不无限占用操作线程。
                let deadline = std::time::Instant::now() + std::time::Duration::from_secs(180);
                while (api.fido_bio_enroll_remaining_samples)(progress.raw()) > 0 {
                    if std::time::Instant::now() >= deadline {
                        return Err("指纹录入超时，请重试".into());
                    }
                    api.check((api.fido_bio_dev_enroll_continue)(
                        s.raw(),
                        template.raw(),
                        progress.raw(),
                        30_000,
                    ))?;
                }
                Ok(())
            })();
            if result.is_err() {
                (api.fido_bio_dev_enroll_cancel)(s.raw());
            }
            result
        }
    }
    fn remove_fingerprint(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode(id)?;
        let pin = secret(pin)?;
        let s = Session::open(path)?;
        let api = s.api;
        unsafe {
            let template = Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
            api.check((api.fido_bio_template_set_id)(
                template.raw(),
                id.as_ptr(),
                id.len(),
            ))?;
            api.check((api.fido_bio_dev_enroll_remove)(
                s.raw(),
                template.raw(),
                pin.as_ptr().cast(),
            ))
        }
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
        let s = Session::open(path)?;
        let api = s.api;
        unsafe {
            let template = Owned::new((api.fido_bio_template_new)(), api.fido_bio_template_free)?;
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
                s.raw(),
                template.raw(),
                pin.as_ptr().cast(),
            ))
        }
    }
    fn reset(&mut self, path: &str) -> Result<(), String> {
        let s = Session::open(path)?;
        unsafe { s.api.check((s.api.fido_dev_reset)(s.raw())) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
}
