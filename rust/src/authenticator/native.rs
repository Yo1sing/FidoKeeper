// 根据系统 libfido2 公开头文件声明 ABI；不包含旧项目的封装代码。
#![allow(non_camel_case_types)]
use libloading::Library;
use std::{
    ffi::{c_char, c_int, CStr},
    sync::OnceLock,
};
pub enum fido_bio_enroll_t {}
pub enum fido_bio_info_t {}
pub enum fido_bio_template_array_t {}
pub enum fido_bio_template_t {}
pub enum fido_cbor_info_t {}
pub enum fido_cred_t {}
pub enum fido_credman_metadata_t {}
pub enum fido_credman_rk_t {}
pub enum fido_credman_rp_t {}
pub enum fido_dev_info_t {}
pub enum fido_dev_t {}
pub struct RawApi {
    _library: Library,
    pub fido_bio_dev_enroll_begin: unsafe extern "C" fn(
        *mut fido_dev_t,
        *mut fido_bio_template_t,
        *mut fido_bio_enroll_t,
        u32,
        *const c_char,
    ) -> c_int,
    pub fido_bio_dev_enroll_cancel: unsafe extern "C" fn(*mut fido_dev_t) -> c_int,
    pub fido_bio_dev_enroll_continue: unsafe extern "C" fn(
        *mut fido_dev_t,
        *const fido_bio_template_t,
        *mut fido_bio_enroll_t,
        u32,
    ) -> c_int,
    pub fido_bio_dev_enroll_remove:
        unsafe extern "C" fn(*mut fido_dev_t, *const fido_bio_template_t, *const c_char) -> c_int,
    pub fido_bio_dev_get_info: unsafe extern "C" fn(*mut fido_dev_t, *mut fido_bio_info_t) -> c_int,
    pub fido_bio_dev_get_template_array: unsafe extern "C" fn(
        *mut fido_dev_t,
        *mut fido_bio_template_array_t,
        *const c_char,
    ) -> c_int,
    pub fido_bio_dev_set_template_name:
        unsafe extern "C" fn(*mut fido_dev_t, *const fido_bio_template_t, *const c_char) -> c_int,
    pub fido_bio_enroll_free: unsafe extern "C" fn(*mut *mut fido_bio_enroll_t) -> (),
    pub fido_bio_enroll_new: unsafe extern "C" fn() -> *mut fido_bio_enroll_t,
    pub fido_bio_enroll_last_status: unsafe extern "C" fn(*const fido_bio_enroll_t) -> u8,
    pub fido_bio_enroll_remaining_samples: unsafe extern "C" fn(*const fido_bio_enroll_t) -> u8,
    pub fido_bio_info_free: unsafe extern "C" fn(*mut *mut fido_bio_info_t) -> (),
    pub fido_bio_info_new: unsafe extern "C" fn() -> *mut fido_bio_info_t,
    pub fido_bio_template:
        unsafe extern "C" fn(*const fido_bio_template_array_t, usize) -> *const fido_bio_template_t,
    pub fido_bio_template_array_count:
        unsafe extern "C" fn(*const fido_bio_template_array_t) -> usize,
    pub fido_bio_template_array_free:
        unsafe extern "C" fn(*mut *mut fido_bio_template_array_t) -> (),
    pub fido_bio_template_array_new: unsafe extern "C" fn() -> *mut fido_bio_template_array_t,
    pub fido_bio_template_free: unsafe extern "C" fn(*mut *mut fido_bio_template_t) -> (),
    pub fido_bio_template_id_len: unsafe extern "C" fn(*const fido_bio_template_t) -> usize,
    pub fido_bio_template_id_ptr: unsafe extern "C" fn(*const fido_bio_template_t) -> *const u8,
    pub fido_bio_template_name: unsafe extern "C" fn(*const fido_bio_template_t) -> *const c_char,
    pub fido_bio_template_new: unsafe extern "C" fn() -> *mut fido_bio_template_t,
    pub fido_bio_template_set_id:
        unsafe extern "C" fn(*mut fido_bio_template_t, *const u8, usize) -> c_int,
    pub fido_bio_template_set_name:
        unsafe extern "C" fn(*mut fido_bio_template_t, *const c_char) -> c_int,
    pub fido_cbor_info_free: unsafe extern "C" fn(*mut *mut fido_cbor_info_t) -> (),
    pub fido_cbor_info_new: unsafe extern "C" fn() -> *mut fido_cbor_info_t,
    pub fido_cbor_info_options_len: unsafe extern "C" fn(*const fido_cbor_info_t) -> usize,
    pub fido_cbor_info_options_name_ptr:
        unsafe extern "C" fn(*const fido_cbor_info_t) -> *mut *mut c_char,
    pub fido_cred_display_name: unsafe extern "C" fn(*const fido_cred_t) -> *const c_char,
    pub fido_cred_id_len: unsafe extern "C" fn(*const fido_cred_t) -> usize,
    pub fido_cred_id_ptr: unsafe extern "C" fn(*const fido_cred_t) -> *const u8,
    pub fido_cred_user_name: unsafe extern "C" fn(*const fido_cred_t) -> *const c_char,
    pub fido_credman_del_dev_rk:
        unsafe extern "C" fn(*mut fido_dev_t, *const u8, usize, *const c_char) -> c_int,
    pub fido_credman_get_dev_metadata:
        unsafe extern "C" fn(*mut fido_dev_t, *mut fido_credman_metadata_t, *const c_char) -> c_int,
    pub fido_credman_get_dev_rk: unsafe extern "C" fn(
        *mut fido_dev_t,
        *const c_char,
        *mut fido_credman_rk_t,
        *const c_char,
    ) -> c_int,
    pub fido_credman_get_dev_rp:
        unsafe extern "C" fn(*mut fido_dev_t, *mut fido_credman_rp_t, *const c_char) -> c_int,
    pub fido_credman_metadata_free: unsafe extern "C" fn(*mut *mut fido_credman_metadata_t) -> (),
    pub fido_credman_metadata_new: unsafe extern "C" fn() -> *mut fido_credman_metadata_t,
    pub fido_credman_rk:
        unsafe extern "C" fn(*const fido_credman_rk_t, usize) -> *const fido_cred_t,
    pub fido_credman_rk_count: unsafe extern "C" fn(*const fido_credman_rk_t) -> usize,
    pub fido_credman_rk_existing: unsafe extern "C" fn(*const fido_credman_metadata_t) -> u64,
    pub fido_credman_rk_free: unsafe extern "C" fn(*mut *mut fido_credman_rk_t) -> (),
    pub fido_credman_rk_new: unsafe extern "C" fn() -> *mut fido_credman_rk_t,
    pub fido_credman_rk_remaining: unsafe extern "C" fn(*const fido_credman_metadata_t) -> u64,
    pub fido_credman_rp_count: unsafe extern "C" fn(*const fido_credman_rp_t) -> usize,
    pub fido_credman_rp_free: unsafe extern "C" fn(*mut *mut fido_credman_rp_t) -> (),
    pub fido_credman_rp_id: unsafe extern "C" fn(*const fido_credman_rp_t, usize) -> *const c_char,
    pub fido_credman_rp_name:
        unsafe extern "C" fn(*const fido_credman_rp_t, usize) -> *const c_char,
    pub fido_credman_rp_new: unsafe extern "C" fn() -> *mut fido_credman_rp_t,
    pub fido_dev_close: unsafe extern "C" fn(*mut fido_dev_t) -> c_int,
    pub fido_dev_free: unsafe extern "C" fn(*mut *mut fido_dev_t) -> (),
    pub fido_dev_get_cbor_info:
        unsafe extern "C" fn(*mut fido_dev_t, *mut fido_cbor_info_t) -> c_int,
    pub fido_dev_info_free: unsafe extern "C" fn(*mut *mut fido_dev_info_t, usize) -> (),
    pub fido_dev_info_manifest:
        unsafe extern "C" fn(*mut fido_dev_info_t, usize, *mut usize) -> c_int,
    pub fido_dev_info_manufacturer_string:
        unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char,
    pub fido_dev_info_new: unsafe extern "C" fn(usize) -> *mut fido_dev_info_t,
    pub fido_dev_info_path: unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char,
    pub fido_dev_info_product_string: unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char,
    pub fido_dev_info_ptr:
        unsafe extern "C" fn(*const fido_dev_info_t, usize) -> *const fido_dev_info_t,
    pub fido_dev_is_fido2: unsafe extern "C" fn(*const fido_dev_t) -> bool,
    pub fido_dev_new: unsafe extern "C" fn() -> *mut fido_dev_t,
    pub fido_dev_open: unsafe extern "C" fn(*mut fido_dev_t, *const c_char) -> c_int,
    pub fido_dev_reset: unsafe extern "C" fn(*mut fido_dev_t) -> c_int,
    pub fido_dev_set_pin:
        unsafe extern "C" fn(*mut fido_dev_t, *const c_char, *const c_char) -> c_int,
    pub fido_dev_set_timeout: unsafe extern "C" fn(*mut fido_dev_t, c_int) -> c_int,
    pub fido_dev_supports_credman: unsafe extern "C" fn(*const fido_dev_t) -> bool,
    pub fido_dev_supports_pin: unsafe extern "C" fn(*const fido_dev_t) -> bool,
    pub fido_init: unsafe extern "C" fn(c_int) -> (),
    pub fido_strerr: unsafe extern "C" fn(c_int) -> *const c_char,
}
impl RawApi {
    pub fn get() -> Result<&'static Self, String> {
        static API: OnceLock<Result<RawApi, String>> = OnceLock::new();
        API.get_or_init(|| unsafe { Self::load() })
            .as_ref()
            .map_err(Clone::clone)
    }
    unsafe fn load() -> Result<Self, String> {
        let library = open_library()?;
        let api = Self {
            fido_bio_dev_enroll_begin: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_bio_template_t, *mut fido_bio_enroll_t, u32, *const c_char) -> c_int>(b"fido_bio_dev_enroll_begin\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_enroll_begin：{e}"))?,
            fido_bio_dev_enroll_cancel: *library.get::<unsafe extern "C" fn(*mut fido_dev_t) -> c_int>(b"fido_bio_dev_enroll_cancel\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_enroll_cancel：{e}"))?,
            fido_bio_dev_enroll_continue: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const fido_bio_template_t, *mut fido_bio_enroll_t, u32) -> c_int>(b"fido_bio_dev_enroll_continue\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_enroll_continue：{e}"))?,
            fido_bio_dev_enroll_remove: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const fido_bio_template_t, *const c_char) -> c_int>(b"fido_bio_dev_enroll_remove\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_enroll_remove：{e}"))?,
            fido_bio_dev_get_info: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_bio_info_t) -> c_int>(b"fido_bio_dev_get_info\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_get_info：{e}"))?,
            fido_bio_dev_get_template_array: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_bio_template_array_t, *const c_char) -> c_int>(b"fido_bio_dev_get_template_array\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_get_template_array：{e}"))?,
            fido_bio_dev_set_template_name: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const fido_bio_template_t, *const c_char) -> c_int>(b"fido_bio_dev_set_template_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_dev_set_template_name：{e}"))?,
            fido_bio_enroll_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_bio_enroll_t) -> ()>(b"fido_bio_enroll_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_enroll_free：{e}"))?,
            fido_bio_enroll_new: *library.get::<unsafe extern "C" fn() -> *mut fido_bio_enroll_t>(b"fido_bio_enroll_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_enroll_new：{e}"))?,
            fido_bio_enroll_last_status: *library.get::<unsafe extern "C" fn(*const fido_bio_enroll_t) -> u8>(b"fido_bio_enroll_last_status\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_enroll_last_status：{e}"))?,
            fido_bio_enroll_remaining_samples: *library.get::<unsafe extern "C" fn(*const fido_bio_enroll_t) -> u8>(b"fido_bio_enroll_remaining_samples\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_enroll_remaining_samples：{e}"))?,
            fido_bio_info_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_bio_info_t) -> ()>(b"fido_bio_info_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_info_free：{e}"))?,
            fido_bio_info_new: *library.get::<unsafe extern "C" fn() -> *mut fido_bio_info_t>(b"fido_bio_info_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_info_new：{e}"))?,
            fido_bio_template: *library.get::<unsafe extern "C" fn(*const fido_bio_template_array_t, usize) -> *const fido_bio_template_t>(b"fido_bio_template\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template：{e}"))?,
            fido_bio_template_array_count: *library.get::<unsafe extern "C" fn(*const fido_bio_template_array_t) -> usize>(b"fido_bio_template_array_count\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_array_count：{e}"))?,
            fido_bio_template_array_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_bio_template_array_t) -> ()>(b"fido_bio_template_array_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_array_free：{e}"))?,
            fido_bio_template_array_new: *library.get::<unsafe extern "C" fn() -> *mut fido_bio_template_array_t>(b"fido_bio_template_array_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_array_new：{e}"))?,
            fido_bio_template_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_bio_template_t) -> ()>(b"fido_bio_template_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_free：{e}"))?,
            fido_bio_template_id_len: *library.get::<unsafe extern "C" fn(*const fido_bio_template_t) -> usize>(b"fido_bio_template_id_len\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_id_len：{e}"))?,
            fido_bio_template_id_ptr: *library.get::<unsafe extern "C" fn(*const fido_bio_template_t) -> *const u8>(b"fido_bio_template_id_ptr\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_id_ptr：{e}"))?,
            fido_bio_template_name: *library.get::<unsafe extern "C" fn(*const fido_bio_template_t) -> *const c_char>(b"fido_bio_template_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_name：{e}"))?,
            fido_bio_template_new: *library.get::<unsafe extern "C" fn() -> *mut fido_bio_template_t>(b"fido_bio_template_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_new：{e}"))?,
            fido_bio_template_set_id: *library.get::<unsafe extern "C" fn(*mut fido_bio_template_t, *const u8, usize) -> c_int>(b"fido_bio_template_set_id\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_set_id：{e}"))?,
            fido_bio_template_set_name: *library.get::<unsafe extern "C" fn(*mut fido_bio_template_t, *const c_char) -> c_int>(b"fido_bio_template_set_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_bio_template_set_name：{e}"))?,
            fido_cbor_info_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_cbor_info_t) -> ()>(b"fido_cbor_info_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_cbor_info_free：{e}"))?,
            fido_cbor_info_new: *library.get::<unsafe extern "C" fn() -> *mut fido_cbor_info_t>(b"fido_cbor_info_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_cbor_info_new：{e}"))?,
            fido_cbor_info_options_len: *library.get::<unsafe extern "C" fn(*const fido_cbor_info_t) -> usize>(b"fido_cbor_info_options_len\0").map_err(|e| format!("缺少 libfido2 符号 fido_cbor_info_options_len：{e}"))?,
            fido_cbor_info_options_name_ptr: *library.get::<unsafe extern "C" fn(*const fido_cbor_info_t) -> *mut *mut c_char>(b"fido_cbor_info_options_name_ptr\0").map_err(|e| format!("缺少 libfido2 符号 fido_cbor_info_options_name_ptr：{e}"))?,
            fido_cred_display_name: *library.get::<unsafe extern "C" fn(*const fido_cred_t) -> *const c_char>(b"fido_cred_display_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_cred_display_name：{e}"))?,
            fido_cred_id_len: *library.get::<unsafe extern "C" fn(*const fido_cred_t) -> usize>(b"fido_cred_id_len\0").map_err(|e| format!("缺少 libfido2 符号 fido_cred_id_len：{e}"))?,
            fido_cred_id_ptr: *library.get::<unsafe extern "C" fn(*const fido_cred_t) -> *const u8>(b"fido_cred_id_ptr\0").map_err(|e| format!("缺少 libfido2 符号 fido_cred_id_ptr：{e}"))?,
            fido_cred_user_name: *library.get::<unsafe extern "C" fn(*const fido_cred_t) -> *const c_char>(b"fido_cred_user_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_cred_user_name：{e}"))?,
            fido_credman_del_dev_rk: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const u8, usize, *const c_char) -> c_int>(b"fido_credman_del_dev_rk\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_del_dev_rk：{e}"))?,
            fido_credman_get_dev_metadata: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_credman_metadata_t, *const c_char) -> c_int>(b"fido_credman_get_dev_metadata\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_get_dev_metadata：{e}"))?,
            fido_credman_get_dev_rk: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const c_char, *mut fido_credman_rk_t, *const c_char) -> c_int>(b"fido_credman_get_dev_rk\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_get_dev_rk：{e}"))?,
            fido_credman_get_dev_rp: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_credman_rp_t, *const c_char) -> c_int>(b"fido_credman_get_dev_rp\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_get_dev_rp：{e}"))?,
            fido_credman_metadata_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_credman_metadata_t) -> ()>(b"fido_credman_metadata_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_metadata_free：{e}"))?,
            fido_credman_metadata_new: *library.get::<unsafe extern "C" fn() -> *mut fido_credman_metadata_t>(b"fido_credman_metadata_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_metadata_new：{e}"))?,
            fido_credman_rk: *library.get::<unsafe extern "C" fn(*const fido_credman_rk_t, usize) -> *const fido_cred_t>(b"fido_credman_rk\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk：{e}"))?,
            fido_credman_rk_count: *library.get::<unsafe extern "C" fn(*const fido_credman_rk_t) -> usize>(b"fido_credman_rk_count\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk_count：{e}"))?,
            fido_credman_rk_existing: *library.get::<unsafe extern "C" fn(*const fido_credman_metadata_t) -> u64>(b"fido_credman_rk_existing\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk_existing：{e}"))?,
            fido_credman_rk_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_credman_rk_t) -> ()>(b"fido_credman_rk_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk_free：{e}"))?,
            fido_credman_rk_new: *library.get::<unsafe extern "C" fn() -> *mut fido_credman_rk_t>(b"fido_credman_rk_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk_new：{e}"))?,
            fido_credman_rk_remaining: *library.get::<unsafe extern "C" fn(*const fido_credman_metadata_t) -> u64>(b"fido_credman_rk_remaining\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rk_remaining：{e}"))?,
            fido_credman_rp_count: *library.get::<unsafe extern "C" fn(*const fido_credman_rp_t) -> usize>(b"fido_credman_rp_count\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rp_count：{e}"))?,
            fido_credman_rp_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_credman_rp_t) -> ()>(b"fido_credman_rp_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rp_free：{e}"))?,
            fido_credman_rp_id: *library.get::<unsafe extern "C" fn(*const fido_credman_rp_t, usize) -> *const c_char>(b"fido_credman_rp_id\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rp_id：{e}"))?,
            fido_credman_rp_name: *library.get::<unsafe extern "C" fn(*const fido_credman_rp_t, usize) -> *const c_char>(b"fido_credman_rp_name\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rp_name：{e}"))?,
            fido_credman_rp_new: *library.get::<unsafe extern "C" fn() -> *mut fido_credman_rp_t>(b"fido_credman_rp_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_credman_rp_new：{e}"))?,
            fido_dev_close: *library.get::<unsafe extern "C" fn(*mut fido_dev_t) -> c_int>(b"fido_dev_close\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_close：{e}"))?,
            fido_dev_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_dev_t) -> ()>(b"fido_dev_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_free：{e}"))?,
            fido_dev_get_cbor_info: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *mut fido_cbor_info_t) -> c_int>(b"fido_dev_get_cbor_info\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_get_cbor_info：{e}"))?,
            fido_dev_info_free: *library.get::<unsafe extern "C" fn(*mut *mut fido_dev_info_t, usize) -> ()>(b"fido_dev_info_free\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_free：{e}"))?,
            fido_dev_info_manifest: *library.get::<unsafe extern "C" fn(*mut fido_dev_info_t, usize, *mut usize) -> c_int>(b"fido_dev_info_manifest\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_manifest：{e}"))?,
            fido_dev_info_manufacturer_string: *library.get::<unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char>(b"fido_dev_info_manufacturer_string\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_manufacturer_string：{e}"))?,
            fido_dev_info_new: *library.get::<unsafe extern "C" fn(usize) -> *mut fido_dev_info_t>(b"fido_dev_info_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_new：{e}"))?,
            fido_dev_info_path: *library.get::<unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char>(b"fido_dev_info_path\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_path：{e}"))?,
            fido_dev_info_product_string: *library.get::<unsafe extern "C" fn(*const fido_dev_info_t) -> *const c_char>(b"fido_dev_info_product_string\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_product_string：{e}"))?,
            fido_dev_info_ptr: *library.get::<unsafe extern "C" fn(*const fido_dev_info_t, usize) -> *const fido_dev_info_t>(b"fido_dev_info_ptr\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_info_ptr：{e}"))?,
            fido_dev_is_fido2: *library.get::<unsafe extern "C" fn(*const fido_dev_t) -> bool>(b"fido_dev_is_fido2\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_is_fido2：{e}"))?,
            fido_dev_new: *library.get::<unsafe extern "C" fn() -> *mut fido_dev_t>(b"fido_dev_new\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_new：{e}"))?,
            fido_dev_open: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const c_char) -> c_int>(b"fido_dev_open\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_open：{e}"))?,
            fido_dev_reset: *library.get::<unsafe extern "C" fn(*mut fido_dev_t) -> c_int>(b"fido_dev_reset\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_reset：{e}"))?,
            fido_dev_set_pin: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, *const c_char, *const c_char) -> c_int>(b"fido_dev_set_pin\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_set_pin：{e}"))?,
            fido_dev_set_timeout: *library.get::<unsafe extern "C" fn(*mut fido_dev_t, c_int) -> c_int>(b"fido_dev_set_timeout\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_set_timeout：{e}"))?,
            fido_dev_supports_credman: *library.get::<unsafe extern "C" fn(*const fido_dev_t) -> bool>(b"fido_dev_supports_credman\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_supports_credman：{e}"))?,
            fido_dev_supports_pin: *library.get::<unsafe extern "C" fn(*const fido_dev_t) -> bool>(b"fido_dev_supports_pin\0").map_err(|e| format!("缺少 libfido2 符号 fido_dev_supports_pin：{e}"))?,
            fido_init: *library.get::<unsafe extern "C" fn(c_int) -> ()>(b"fido_init\0").map_err(|e| format!("缺少 libfido2 符号 fido_init：{e}"))?,
            fido_strerr: *library.get::<unsafe extern "C" fn(c_int) -> *const c_char>(b"fido_strerr\0").map_err(|e| format!("缺少 libfido2 符号 fido_strerr：{e}"))?,
            _library: library,
        };
        (api.fido_init)(0);
        Ok(api)
    }
    pub fn check(&self, code: i32) -> Result<(), String> {
        if code == 0 {
            return Ok(());
        }
        let reason = match code {
            0x31 => "PIN 码错误，请重试".to_owned(),
            0x32 => "PIN 已锁定，请查阅设备说明，不要继续重试".to_owned(),
            0x34 => "PIN 验证暂时锁定，请重新插入设备".to_owned(),
            _ => unsafe {
                let message = (self.fido_strerr)(code);
                if message.is_null() {
                    format!("设备错误 {code}")
                } else {
                    CStr::from_ptr(message).to_string_lossy().into_owned()
                }
            },
        };
        Err(format!("{reason}（libfido2: {code}）"))
    }
}

unsafe fn open_library() -> Result<Library, String> {
    #[cfg(target_os = "windows")]
    {
        let executable = std::env::current_exe().map_err(|e| e.to_string())?;
        let directory = executable.parent().ok_or("无法定位程序目录")?;
        let path = directory.join("fido2.dll");
        // 仅从应用目录和系统安全目录解析 DLL 依赖。
        return libloading::os::windows::Library::load_with_flags(&path, 0x00000100 | 0x00000800)
            .map(Into::into)
            .map_err(|e| {
                format!(
                    "无法加载 {}，请随程序提供同架构 DLL 及依赖：{e}",
                    path.display()
                )
            });
    }
    #[cfg(target_os = "linux")]
    {
        Library::new("libfido2.so.1").map_err(|e| format!("无法加载 libfido2.so.1：{e}"))
    }
    #[cfg(target_os = "macos")]
    {
        for path in [
            "libfido2.1.dylib",
            "/opt/homebrew/lib/libfido2.1.dylib",
            "/usr/local/lib/libfido2.1.dylib",
        ] {
            if let Ok(library) = Library::new(path) {
                return Ok(library);
            }
        }
        Err("无法加载 libfido2，请安装对应架构的系统库".into())
    }
    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        Err("当前平台不支持本地 FIDO 设备".into())
    }
}
