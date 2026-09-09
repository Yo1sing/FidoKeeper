use super::ctap::{ApduIO, CtapAuthenticator, CtapLink, DeviceSource, HidLink, NfcLink, PacketIO};
use jni::{
    objects::{JByteArray, JClass, JObject, JObjectArray, JString, JValue},
    sys::jint,
    JNIEnv, JavaVM,
};
use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
};

static VM: OnceLock<JavaVM> = OnceLock::new();
static HOST: Mutex<Option<jni::objects::GlobalRef>> = Mutex::new(None);
static FILES: OnceLock<PathBuf> = OnceLock::new();

pub type AndroidAuthenticator = CtapAuthenticator<AndroidSource>;

pub struct AndroidSource;

pub fn files_dir() -> Result<PathBuf, String> {
    FILES
        .get()
        .cloned()
        .ok_or_else(|| "找不到用户配置目录".to_owned())
}

pub fn authenticator() -> AndroidAuthenticator {
    CtapAuthenticator::new(AndroidSource)
}

impl DeviceSource for AndroidSource {
    fn enumerate(&mut self) -> Result<Vec<(String, String)>, String> {
        with_host(|env, host| {
            let result = env
                .call_method(host, "list", "()[Ljava/lang/String;", &[])
                .map_err(jni_err)?;
            let array: JObjectArray = result.l().map_err(jni_err)?.into();
            let length = env.get_array_length(&array).map_err(jni_err)?;
            let mut devices = Vec::new();
            for index in 0..length {
                let item = env
                    .get_object_array_element(&array, index)
                    .map_err(jni_err)?;
                let line = jobject_to_string(env, item)?;
                let (path, label) = line.split_once('\t').unwrap_or((line.as_str(), ""));
                devices.push((path.to_owned(), label.to_owned()));
            }
            Ok(devices)
        })
    }

    fn connect(&mut self, path: &str) -> Result<Box<dyn CtapLink>, String> {
        let handle = with_host(|env, host| {
            let jpath = env.new_string(path).map_err(jni_err)?;
            let result = env
                .call_method(
                    host,
                    "open",
                    "(Ljava/lang/String;)I",
                    &[JValue::from(&jpath)],
                )
                .map_err(jni_err)?;
            result.i().map_err(jni_err)
        })?;
        if path.starts_with("nfc") {
            Ok(Box::new(NfcLink::wrap(AndroidApdu { handle })))
        } else {
            let packet_size = call_int("packetSize", handle)? as usize;
            Ok(Box::new(HidLink::open(
                AndroidHid {
                    handle,
                    packet_size: packet_size.max(64),
                },
                30_000,
            )?))
        }
    }
}

struct AndroidHid {
    handle: i32,
    packet_size: usize,
}

impl Drop for AndroidHid {
    fn drop(&mut self) {
        let _ = call_void("close", self.handle);
    }
}

impl PacketIO for AndroidHid {
    fn packet_size(&self) -> usize {
        self.packet_size
    }
    fn write(&mut self, packet: &[u8]) -> Result<(), String> {
        with_host(|env, host| {
            let bytes = env.byte_array_from_slice(packet).map_err(jni_err)?;
            env.call_method(
                host,
                "hidWrite",
                "(I[B)V",
                &[JValue::from(self.handle), JValue::from(&bytes)],
            )
            .map_err(jni_err)?;
            Ok(())
        })
    }
    fn read(&mut self, timeout_ms: i32) -> Result<Vec<u8>, String> {
        with_host(|env, host| {
            let result = env
                .call_method(
                    host,
                    "hidRead",
                    "(II)[B",
                    &[JValue::from(self.handle), JValue::from(timeout_ms)],
                )
                .map_err(jni_err)?;
            let array: JByteArray = result.l().map_err(jni_err)?.into();
            env.convert_byte_array(&array).map_err(jni_err)
        })
    }
}

struct AndroidApdu {
    handle: i32,
}

impl Drop for AndroidApdu {
    fn drop(&mut self) {
        let _ = call_void("close", self.handle);
    }
}

impl ApduIO for AndroidApdu {
    fn transmit(&mut self, apdu: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String> {
        with_host(|env, host| {
            let bytes = env.byte_array_from_slice(apdu).map_err(jni_err)?;
            let result = env
                .call_method(
                    host,
                    "nfcTransmit",
                    "(I[BI)[B",
                    &[
                        JValue::from(self.handle),
                        JValue::from(&bytes),
                        JValue::from(timeout_ms),
                    ],
                )
                .map_err(jni_err)?;
            let array: JByteArray = result.l().map_err(jni_err)?.into();
            env.convert_byte_array(&array).map_err(jni_err)
        })
    }
}

fn call_int(method: &str, handle: i32) -> Result<i32, String> {
    with_host(|env, host| {
        env.call_method(host, method, "(I)I", &[JValue::from(handle)])
            .map_err(jni_err)?
            .i()
            .map_err(jni_err)
    })
}

fn call_void(method: &str, handle: i32) -> Result<(), String> {
    with_host(|env, host| {
        env.call_method(host, method, "(I)V", &[JValue::from(handle)])
            .map_err(jni_err)?;
        Ok(())
    })
}

fn with_host<T>(f: impl FnOnce(&mut JNIEnv, &JObject) -> Result<T, String>) -> Result<T, String> {
    let vm = VM.get().ok_or("Android USB/NFC 主机未初始化")?;
    let mut env = vm
        .attach_current_thread()
        .map_err(|e| format!("无法附加 JVM：{e}"))?;
    let guard = HOST.lock().map_err(|_| "Android 主机状态异常".to_owned())?;
    let host = guard.as_ref().ok_or("Android USB/NFC 主机未绑定")?;
    if env.exception_check().unwrap_or(false) {
        env.exception_clear().ok();
    }
    let result = f(&mut env, host.as_obj());
    if env.exception_check().unwrap_or(false) {
        let message = exception_message(&mut env);
        env.exception_clear().ok();
        return Err(message);
    }
    result
}

fn exception_message(env: &mut JNIEnv) -> String {
    let fallback = "Android 设备访问失败".to_owned();
    let Ok(exception) = env.exception_occurred() else {
        return fallback;
    };
    env.exception_clear().ok();
    let Ok(value) = env.call_method(&exception, "getMessage", "()Ljava/lang/String;", &[]) else {
        return fallback;
    };
    let Ok(message) = value.l() else {
        return fallback;
    };
    jobject_to_string(env, message)
        .ok()
        .filter(|s| !s.is_empty())
        .unwrap_or(fallback)
}

fn jobject_to_string(env: &mut JNIEnv, obj: JObject) -> Result<String, String> {
    if obj.is_null() {
        return Err("Android 返回空字符串".into());
    }
    let jstring = JString::from(obj);
    let java_str = env.get_string(&jstring).map_err(jni_err)?;
    let owned = String::from(java_str);
    Ok(owned)
}

fn jni_err<E: std::fmt::Display>(error: E) -> String {
    format!("Android 设备访问失败：{error}")
}

fn store_vm(env: &JNIEnv) {
    if let Ok(vm) = env.get_java_vm() {
        let _ = VM.set(vm);
    }
}

#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    vm: *mut jni::sys::JavaVM,
    _reserved: *mut std::ffi::c_void,
) -> jint {
    if let Ok(vm) = unsafe { JavaVM::from_raw(vm) } {
        let _ = VM.set(vm);
    }
    jni::sys::JNI_VERSION_1_6
}

#[no_mangle]
pub extern "system" fn Java_com_example_fidokeeper_FidoHost_nativeRegister(
    mut env: JNIEnv,
    _class: JClass,
    host: JObject,
) {
    store_vm(&env);
    if let Ok(global) = env.new_global_ref(&host) {
        if let Ok(dir) = env.call_method(&global, "filesDir", "()Ljava/lang/String;", &[]) {
            if let Ok(obj) = dir.l() {
                if let Ok(text) = jobject_to_string(&mut env, obj) {
                    let _ = FILES.set(PathBuf::from(text));
                }
            }
        }
        if let Ok(mut guard) = HOST.lock() {
            *guard = Some(global);
        }
    }
}
