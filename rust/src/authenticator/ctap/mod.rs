mod cbor;
mod hid;
mod nfc;
mod pin;

use super::{Authenticator, Inventory};
use crate::api::models::{BioTemplateSummary, CredentialSummary, DeviceSummary};
use cbor::Value;
use pin::PinProtocol;
use rand_core::{OsRng, RngCore};
use std::time::{Duration, Instant};
use zeroize::Zeroizing;

const TIMEOUT_MS: i32 = 30_000;
const PIN_PERM_CRED: u8 = 0x04;
const PIN_PERM_BIO: u8 = 0x08;
const CTAP_GET_INFO: u8 = 0x04;
const CTAP_CLIENT_PIN: u8 = 0x06;
const CTAP_RESET: u8 = 0x07;
const CTAP_BIO: u8 = 0x09;
const CTAP_CREDMAN: u8 = 0x0A;
const CTAP_BIO_PRE: u8 = 0x40;
const CTAP_CREDMAN_PRE: u8 = 0x41;

pub trait CtapLink: Send {
    fn cbor(&mut self, payload: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String>;
}

pub trait DeviceSource: Send {
    fn enumerate(&mut self) -> Result<Vec<(String, String)>, String>;
    fn connect(&mut self, path: &str) -> Result<Box<dyn CtapLink>, String>;
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub trait PacketIO: Send {
    fn packet_size(&self) -> usize;
    fn write(&mut self, packet: &[u8]) -> Result<(), String>;
    fn read(&mut self, timeout_ms: i32) -> Result<Vec<u8>, String>;
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub trait ApduIO: Send {
    fn transmit(&mut self, apdu: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String>;
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub struct HidLink<T: PacketIO> {
    io: T,
    cid: u32,
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
impl<T: PacketIO> HidLink<T> {
    pub fn open(io: T, timeout_ms: i32) -> Result<Self, String> {
        let mut link = Self {
            io,
            cid: hid::BROADCAST,
        };
        let mut nonce = [0u8; 8];
        OsRng.fill_bytes(&mut nonce);
        let response = link.exchange(hid::CMD_INIT, &nonce, timeout_ms)?;
        link.cid = hid::parse_init(&nonce, &response)?;
        Ok(link)
    }

    fn exchange(&mut self, cmd: u8, data: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String> {
        for frame in hid::encode_frames(self.cid, cmd, data, self.io.packet_size())? {
            self.io.write(&frame)?;
        }
        let deadline = Instant::now() + Duration::from_millis(timeout_ms.max(0) as u64);
        let mut decoder = hid::decoder(self.cid, cmd);
        loop {
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                return Err("设备响应超时".into());
            }
            let packet = self
                .io
                .read(left.as_millis().min(i32::MAX as u128) as i32)?;
            if let Some(payload) = decoder.push(&packet)? {
                return Ok(payload);
            }
        }
    }
}

impl<T: PacketIO> CtapLink for HidLink<T> {
    fn cbor(&mut self, payload: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String> {
        self.exchange(hid::CMD_CBOR, payload, timeout_ms)
    }
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub struct NfcLink<T: ApduIO> {
    io: T,
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
impl<T: ApduIO> NfcLink<T> {
    pub fn wrap(io: T) -> Self {
        Self { io }
    }
}

impl<T: ApduIO> CtapLink for NfcLink<T> {
    fn cbor(&mut self, payload: &[u8], timeout_ms: i32) -> Result<Vec<u8>, String> {
        self.io.transmit(&nfc::cbor_apdu(payload), timeout_ms)
    }
}

pub struct CtapAuthenticator<S: DeviceSource> {
    source: S,
}

impl<S: DeviceSource> CtapAuthenticator<S> {
    pub fn new(source: S) -> Self {
        Self { source }
    }

    fn session(&mut self, path: &str) -> Result<Session, String> {
        let mut link = self.source.connect(path)?;
        let info = read_info(link.as_mut())?;
        Ok(Session { link, info })
    }

    fn probe(&mut self, path: &str, label: String) -> Result<DeviceSummary, String> {
        let session = self.session(path)?;
        Ok(DeviceSummary {
            transport: crate::api::models::Transport::from_path(path),
            path: path.to_owned(),
            label: if label.trim().is_empty() {
                "FIDO 认证器".into()
            } else {
                label
            },
            protocol: if session.info.ctap2 {
                "CTAP2 / FIDO2"
            } else {
                "CTAP1 / U2F"
            }
            .into(),
            credential_management: session.info.credman,
            pin: session.info.pin,
            fingerprint: session.info.bio,
        })
    }
}

impl<S: DeviceSource> Authenticator for CtapAuthenticator<S> {
    fn discover(&mut self) -> Result<Vec<DeviceSummary>, String> {
        let listed = self.source.enumerate()?;
        if listed.is_empty() {
            return Ok(vec![]);
        }
        let mut devices = Vec::new();
        let mut last_error = None;
        for (path, label) in listed {
            match self.probe(&path, label) {
                Ok(device) => devices.push(device),
                Err(error) => last_error = Some(error),
            }
        }
        if devices.is_empty() {
            Err(last_error.unwrap_or_else(|| "未发现可用认证器".into()))
        } else {
            Ok(devices)
        }
    }

    fn inventory(&mut self, path: &str, pin: &str) -> Result<Inventory, String> {
        let mut session = self.session(path)?;
        if !session.info.credman {
            return Err("认证器不支持凭证管理".into());
        }
        let token = session.pin_token(pin, PIN_PERM_CRED)?;
        let proto = session.protocol()?;
        let metadata = session.credman(0x01, None, Some((&proto, &token)))?;
        let existing = cbor::as_u64(cbor::map_get(&metadata, 0x01).ok_or("缺少凭证数量")?)
            .ok_or("凭证数量无效")?;
        let remaining = cbor::as_u64(cbor::map_get(&metadata, 0x02).ok_or("缺少剩余容量")?)
            .ok_or("剩余容量无效")?;
        let mut credentials = Vec::new();
        for rp in session.enumerate_rps(&proto, &token)? {
            let rp_id = cbor::map_get_text(&rp.entity, "id");
            if rp_id.is_empty() {
                return Err("设备返回空网站标识".into());
            }
            let rp_name = cbor::map_get_text(&rp.entity, "name");
            for cred in session.enumerate_creds(&rp.id_hash, &proto, &token)? {
                credentials.push(CredentialSummary {
                    id: encode_hex(&cred.id)?,
                    rp_id: rp_id.clone(),
                    rp_name: if rp_name.is_empty() {
                        rp_id.clone()
                    } else {
                        rp_name.clone()
                    },
                    user_name: cbor::map_get_text(&cred.user, "name"),
                    user_display_name: cbor::map_get_text(&cred.user, "displayName"),
                });
            }
        }
        credentials
            .sort_by(|a, b| (&a.rp_id, &a.user_name, &a.id).cmp(&(&b.rp_id, &b.user_name, &b.id)));
        Ok(Inventory {
            existing,
            remaining,
            credentials,
        })
    }

    fn remove_credential(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode_hex(id)?;
        let mut session = self.session(path)?;
        let token = session.pin_token(pin, PIN_PERM_CRED)?;
        let proto = session.protocol()?;
        session.credman(
            0x06,
            Some(cbor::map(vec![(
                cbor::integer(0x02),
                cbor::credential_descriptor(&id),
            )])),
            Some((&proto, &token)),
        )?;
        Ok(())
    }

    fn update_pin(&mut self, path: &str, current: &str, replacement: &str) -> Result<(), String> {
        let mut session = self.session(path)?;
        if !session.info.pin {
            return Err("认证器不支持 PIN".into());
        }
        if session.info.pin_set {
            session.change_pin(current, replacement)
        } else {
            session.set_pin(replacement)
        }
    }

    fn fingerprints(&mut self, path: &str, pin: &str) -> Result<Vec<BioTemplateSummary>, String> {
        let mut session = self.session(path)?;
        if !session.info.bio {
            return Err("此设备不支持指纹管理".into());
        }
        let token = session.pin_token(pin, PIN_PERM_BIO)?;
        let proto = session.protocol()?;
        let response = match session.bio(0x04, None, Some((&proto, &token))) {
            Ok(value) => value,
            Err(error) if is_empty_ctap(&error) => return Ok(vec![]),
            Err(error) => return Err(error),
        };
        let mut result = Vec::new();
        if let Some(items) = cbor::map_get(&response, 0x07).and_then(cbor::as_array) {
            for item in items {
                let id = cbor::as_bytes(cbor::map_get(item, 0x01).ok_or("设备返回无效指纹")?)
                    .ok_or("设备返回无效指纹")?;
                let name = cbor::map_get(item, 0x02)
                    .and_then(cbor::as_text)
                    .unwrap_or_default();
                result.push(BioTemplateSummary {
                    id: encode_hex(&id)?,
                    name,
                });
            }
        }
        Ok(result)
    }

    fn enroll(&mut self, path: &str, pin: &str, on_sample: &mut dyn FnMut()) -> Result<(), String> {
        let mut session = self.session(path)?;
        let token = session.pin_token(pin, PIN_PERM_BIO)?;
        let proto = session.protocol()?;
        let result = (|| {
            let begin = session.bio(
                0x01,
                Some(cbor::map(vec![(
                    cbor::integer(0x03),
                    cbor::integer(30_000),
                )])),
                Some((&proto, &token)),
            )?;
            require_good_sample(&begin)?;
            on_sample();
            let mut remaining = cbor::as_u8(cbor::map_get(&begin, 0x06).ok_or("缺少剩余次数")?)
                .ok_or("剩余次数无效")?;
            let template = cbor::as_bytes(cbor::map_get(&begin, 0x04).ok_or("缺少指纹标识")?)
                .ok_or("指纹标识无效")?;
            let deadline = Instant::now() + Duration::from_secs(180);
            while remaining > 0 {
                if Instant::now() >= deadline {
                    return Err("指纹录入超时，请重试".into());
                }
                let next = session.bio(
                    0x02,
                    Some(cbor::map(vec![
                        (cbor::integer(0x01), cbor::bytes(template.clone())),
                        (cbor::integer(0x03), cbor::integer(30_000)),
                    ])),
                    Some((&proto, &token)),
                )?;
                require_good_sample(&next)?;
                on_sample();
                remaining = cbor::as_u8(cbor::map_get(&next, 0x06).ok_or("缺少剩余次数")?)
                    .ok_or("剩余次数无效")?;
            }
            Ok(())
        })();
        if result.is_err() {
            let _ = session.bio(0x03, None, None);
        }
        result
    }

    fn remove_fingerprint(&mut self, path: &str, pin: &str, id: &str) -> Result<(), String> {
        let id = decode_hex(id)?;
        let mut session = self.session(path)?;
        let token = session.pin_token(pin, PIN_PERM_BIO)?;
        let proto = session.protocol()?;
        session.bio(
            0x06,
            Some(cbor::map(vec![(cbor::integer(0x01), cbor::bytes(id))])),
            Some((&proto, &token)),
        )?;
        Ok(())
    }

    fn rename_fingerprint(
        &mut self,
        path: &str,
        pin: &str,
        id: &str,
        name: &str,
    ) -> Result<(), String> {
        let id = decode_hex(id)?;
        let mut session = self.session(path)?;
        let token = session.pin_token(pin, PIN_PERM_BIO)?;
        let proto = session.protocol()?;
        session.bio(
            0x05,
            Some(cbor::map(vec![
                (cbor::integer(0x01), cbor::bytes(id)),
                (cbor::integer(0x02), cbor::text(name.to_owned())),
            ])),
            Some((&proto, &token)),
        )?;
        Ok(())
    }

    fn reset(&mut self, path: &str) -> Result<(), String> {
        let mut session = self.session(path)?;
        session.send(CTAP_RESET, None)?;
        Ok(())
    }
}

struct Session {
    link: Box<dyn CtapLink>,
    info: Info,
}

struct Info {
    ctap2: bool,
    pin: bool,
    pin_set: bool,
    pin_token: bool,
    pin_protocols: Vec<u8>,
    credman: bool,
    credman_official: bool,
    bio: bool,
    bio_official: bool,
}

struct RpRecord {
    id_hash: Vec<u8>,
    entity: Value,
}

struct CredRecord {
    id: Vec<u8>,
    user: Value,
}

impl Session {
    fn protocol(&self) -> Result<PinProtocol, String> {
        PinProtocol::preferred(&self.info.pin_protocols)
    }

    fn send(&mut self, cmd: u8, params: Option<Value>) -> Result<Value, String> {
        let mut payload = vec![cmd];
        if let Some(value) = params {
            payload.extend(cbor::encode(&value)?);
        }
        let response = self.link.cbor(&payload, TIMEOUT_MS)?;
        if response.is_empty() {
            return Err("设备返回空应答".into());
        }
        if response[0] != 0 {
            return Err(ctap_error(response[0]));
        }
        if response.len() == 1 {
            return Ok(cbor::map(vec![]));
        }
        cbor::decode(&response[1..])
    }

    fn client_pin(&mut self, entries: Vec<(i64, Value)>) -> Result<Value, String> {
        self.send(CTAP_CLIENT_PIN, Some(cbor::map(cbor_entries(entries))))
    }

    fn shared_secret(&mut self, proto: &PinProtocol) -> Result<(Value, Vec<u8>), String> {
        let response = self.client_pin(vec![
            (1, cbor::integer(proto.version as i64)),
            (2, cbor::integer(0x02)),
        ])?;
        let peer = cbor::map_get(&response, 0x01).ok_or("缺少密钥协商参数")?;
        let (x, y) = cbor::cose_xy(peer)?;
        let (ours_x, ours_y, secret) = proto.encapsulate(&x, &y)?;
        Ok((cbor::cose_key(ours_x, ours_y), secret))
    }

    fn pin_token(&mut self, pin: &str, permissions: u8) -> Result<Zeroizing<Vec<u8>>, String> {
        if pin.is_empty() || pin.contains('\0') {
            return Err("PIN 不能为空或包含空字符".into());
        }
        let proto = self.protocol()?;
        let (agreement, secret) = self.shared_secret(&proto)?;
        let pin_hash_enc = proto.encrypt(&secret, &pin::pin_hash(pin))?;
        let sub = if self.info.pin_token { 0x09 } else { 0x05 };
        let mut entries = vec![
            (1, cbor::integer(proto.version as i64)),
            (2, cbor::integer(sub)),
            (3, agreement),
            (6, cbor::bytes(pin_hash_enc)),
        ];
        if sub == 0x09 {
            entries.push((9, cbor::integer(permissions as i64)));
        }
        let response = self.client_pin(entries)?;
        let token = cbor::as_bytes(cbor::map_get(&response, 0x02).ok_or("缺少 PIN 令牌")?)
            .ok_or("PIN 令牌无效")?;
        Ok(Zeroizing::new(proto.decrypt(&secret, &token)?))
    }

    fn set_pin(&mut self, pin: &str) -> Result<(), String> {
        let proto = self.protocol()?;
        let (agreement, secret) = self.shared_secret(&proto)?;
        let new_pin_enc = proto.encrypt(&secret, &pin::pad_pin(pin)?)?;
        let auth = proto.authenticate(&secret, &new_pin_enc)?;
        self.client_pin(vec![
            (1, cbor::integer(proto.version as i64)),
            (2, cbor::integer(0x03)),
            (3, agreement),
            (4, cbor::bytes(auth)),
            (5, cbor::bytes(new_pin_enc)),
        ])?;
        Ok(())
    }

    fn change_pin(&mut self, current: &str, replacement: &str) -> Result<(), String> {
        if current.is_empty() || current.contains('\0') {
            return Err("PIN 不能为空或包含空字符".into());
        }
        let proto = self.protocol()?;
        let (agreement, secret) = self.shared_secret(&proto)?;
        let pin_hash_enc = proto.encrypt(&secret, &pin::pin_hash(current))?;
        let new_pin_enc = proto.encrypt(&secret, &pin::pad_pin(replacement)?)?;
        let mut auth_msg = new_pin_enc.clone();
        auth_msg.extend_from_slice(&pin_hash_enc);
        let auth = proto.authenticate(&secret, &auth_msg)?;
        self.client_pin(vec![
            (1, cbor::integer(proto.version as i64)),
            (2, cbor::integer(0x04)),
            (3, agreement),
            (4, cbor::bytes(auth)),
            (5, cbor::bytes(new_pin_enc)),
            (6, cbor::bytes(pin_hash_enc)),
        ])?;
        Ok(())
    }

    fn credman(
        &mut self,
        sub: u8,
        params: Option<Value>,
        auth: Option<(&PinProtocol, &Zeroizing<Vec<u8>>)>,
    ) -> Result<Value, String> {
        let cmd = if self.info.credman_official {
            CTAP_CREDMAN
        } else {
            CTAP_CREDMAN_PRE
        };
        let mut mac = vec![sub];
        let mut entries = vec![(1, cbor::integer(sub as i64))];
        if let Some(params) = &params {
            mac.extend(cbor::encode(params)?);
            entries.push((2, params.clone()));
        }
        if let Some((proto, token)) = auth {
            entries.push((3, cbor::integer(proto.version as i64)));
            entries.push((4, cbor::bytes(proto.authenticate(token, &mac)?)));
        }
        self.send(cmd, Some(cbor::map(cbor_entries(entries))))
    }

    fn bio(
        &mut self,
        sub: u8,
        params: Option<Value>,
        auth: Option<(&PinProtocol, &Zeroizing<Vec<u8>>)>,
    ) -> Result<Value, String> {
        let cmd = if self.info.bio_official {
            CTAP_BIO
        } else {
            CTAP_BIO_PRE
        };
        let mut mac = vec![0x01, sub];
        let mut entries = vec![(1, cbor::integer(1)), (2, cbor::integer(sub as i64))];
        if let Some(params) = &params {
            mac.extend(cbor::encode(params)?);
            entries.push((3, params.clone()));
        }
        if let Some((proto, token)) = auth {
            entries.push((4, cbor::integer(proto.version as i64)));
            entries.push((5, cbor::bytes(proto.authenticate(token, &mac)?)));
        }
        self.send(cmd, Some(cbor::map(cbor_entries(entries))))
    }

    fn enumerate_rps(
        &mut self,
        proto: &PinProtocol,
        token: &Zeroizing<Vec<u8>>,
    ) -> Result<Vec<RpRecord>, String> {
        let first = match self.credman(0x02, None, Some((proto, token))) {
            Ok(value) => value,
            Err(error) if is_empty_ctap(&error) => return Ok(vec![]),
            Err(error) => return Err(error),
        };
        let total =
            cbor::as_u64(cbor::map_get(&first, 0x05).unwrap_or(&cbor::integer(1))).unwrap_or(1);
        if total == 0 {
            return Ok(vec![]);
        }
        let mut records = vec![rp_record(&first)?];
        for _ in 1..total {
            records.push(rp_record(&self.credman(0x03, None, None)?)?);
        }
        Ok(records)
    }

    fn enumerate_creds(
        &mut self,
        rp_id_hash: &[u8],
        proto: &PinProtocol,
        token: &Zeroizing<Vec<u8>>,
    ) -> Result<Vec<CredRecord>, String> {
        let params = cbor::map(vec![(
            cbor::integer(0x01),
            cbor::bytes(rp_id_hash.to_vec()),
        )]);
        let first = match self.credman(0x04, Some(params), Some((proto, token))) {
            Ok(value) => value,
            Err(error) if is_empty_ctap(&error) => return Ok(vec![]),
            Err(error) => return Err(error),
        };
        let total =
            cbor::as_u64(cbor::map_get(&first, 0x09).unwrap_or(&cbor::integer(1))).unwrap_or(1);
        let mut records = vec![cred_record(&first)?];
        for _ in 1..total {
            records.push(cred_record(&self.credman(0x05, None, None)?)?);
        }
        Ok(records)
    }
}

fn read_info(link: &mut dyn CtapLink) -> Result<Info, String> {
    let response = link.cbor(&[CTAP_GET_INFO], TIMEOUT_MS)?;
    if response.is_empty() {
        return Err("设备返回空应答".into());
    }
    if response[0] != 0 {
        return Err(ctap_error(response[0]));
    }
    let value = if response.len() == 1 {
        cbor::map(vec![])
    } else {
        cbor::decode(&response[1..])?
    };
    let versions = cbor::map_get(&value, 1)
        .and_then(cbor::as_array)
        .map(|items| items.iter().filter_map(cbor::as_text).collect::<Vec<_>>())
        .unwrap_or_default();
    let options = cbor::map_get(&value, 4)
        .cloned()
        .unwrap_or_else(|| cbor::map(vec![]));
    let pin_protocols = cbor::map_get(&value, 6)
        .and_then(cbor::as_array)
        .map(|items| items.iter().filter_map(cbor::as_u8).collect())
        .unwrap_or_else(|| vec![1]);
    let credman_official = cbor::option_present(&options, "credMgmt");
    let bio_official = cbor::option_present(&options, "bioEnroll");
    Ok(Info {
        ctap2: versions.iter().any(|v| v.starts_with("FIDO_2")),
        pin: cbor::option_present(&options, "clientPin"),
        pin_set: cbor::option_true(&options, "clientPin"),
        pin_token: cbor::option_true(&options, "pinUvAuthToken"),
        pin_protocols,
        credman: credman_official || cbor::option_present(&options, "credentialMgmtPreview"),
        credman_official,
        bio: bio_official || cbor::option_present(&options, "userVerificationMgmtPreview"),
        bio_official,
    })
}

fn rp_record(value: &Value) -> Result<RpRecord, String> {
    Ok(RpRecord {
        id_hash: cbor::as_bytes(cbor::map_get(value, 0x04).ok_or("缺少网站哈希")?)
            .ok_or("网站哈希无效")?,
        entity: cbor::map_get(value, 0x03).cloned().ok_or("缺少网站信息")?,
    })
}

fn cred_record(value: &Value) -> Result<CredRecord, String> {
    let descriptor = cbor::map_get(value, 0x07).ok_or("缺少凭证标识")?;
    Ok(CredRecord {
        id: cbor::map_get_bytes(descriptor, "id").ok_or("设备返回空记录标识")?,
        user: cbor::map_get(value, 0x06)
            .cloned()
            .unwrap_or_else(|| cbor::map(vec![])),
    })
}

fn require_good_sample(value: &Value) -> Result<(), String> {
    match cbor::as_u8(cbor::map_get(value, 0x05).unwrap_or(&cbor::integer(0))).unwrap_or(0) {
        0 => Ok(()),
        _ => Err("指纹采集失败，请按提示重试".into()),
    }
}

fn cbor_entries(entries: Vec<(i64, Value)>) -> Vec<(Value, Value)> {
    entries
        .into_iter()
        .map(|(k, v)| (cbor::integer(k), v))
        .collect()
}

fn is_empty_ctap(error: &str) -> bool {
    error.contains("CTAP2: 46") || error.contains("CTAP2: 44")
}

fn ctap_error(code: u8) -> String {
    let reason = match code {
        0x26 => "需要触碰设备",
        0x27 => "等待用户操作超时",
        0x2E => "没有可管理的凭证",
        0x31 => "PIN 码错误，请重试",
        0x32 => "PIN 已锁定，请查阅设备说明，不要继续重试",
        0x34 => "PIN 验证暂时锁定，请重新插入设备",
        0x35 => "尚未设置 PIN",
        0x36 => "需要 PIN 验证",
        _ => return format!("设备错误 {code}（CTAP2）"),
    };
    format!("{reason}（CTAP2: {code}）")
}

fn encode_hex(bytes: &[u8]) -> Result<String, String> {
    if bytes.is_empty() {
        return Err("设备返回空记录标识".into());
    }
    Ok(bytes.iter().map(|b| format!("{b:02x}")).collect())
}

fn decode_hex(value: &str) -> Result<Vec<u8>, String> {
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

#[cfg(test)]
mod tests {
    use super::*;

    struct MockLink {
        info: Vec<u8>,
    }
    impl CtapLink for MockLink {
        fn cbor(&mut self, payload: &[u8], _: i32) -> Result<Vec<u8>, String> {
            match payload.first().copied() {
                Some(CTAP_GET_INFO) => {
                    let mut response = vec![0];
                    response.extend_from_slice(&self.info);
                    Ok(response)
                }
                Some(CTAP_RESET) => Ok(vec![0]),
                _ => Err("意外命令".into()),
            }
        }
    }
    struct MockSource {
        info: Vec<u8>,
    }
    impl DeviceSource for MockSource {
        fn enumerate(&mut self) -> Result<Vec<(String, String)>, String> {
            Ok(vec![("usb:1".into(), "Mock Key".into())])
        }
        fn connect(&mut self, _: &str) -> Result<Box<dyn CtapLink>, String> {
            Ok(Box::new(MockLink {
                info: self.info.clone(),
            }))
        }
    }

    fn info_payload() -> Vec<u8> {
        cbor::encode_map(vec![
            (
                1,
                Value::Array(vec![cbor::text("FIDO_2_1"), cbor::text("FIDO_2_0")]),
            ),
            (
                4,
                cbor::map(vec![
                    (cbor::text("rk"), cbor::bool_val(true)),
                    (cbor::text("clientPin"), cbor::bool_val(true)),
                    (cbor::text("credMgmt"), cbor::bool_val(true)),
                    (cbor::text("bioEnroll"), cbor::bool_val(false)),
                    (cbor::text("pinUvAuthToken"), cbor::bool_val(true)),
                ]),
            ),
            (6, Value::Array(vec![cbor::integer(2), cbor::integer(1)])),
        ])
        .unwrap()
    }

    #[test]
    fn discover_reads_get_info_options() {
        let mut authenticator = CtapAuthenticator::new(MockSource {
            info: info_payload(),
        });
        let devices = authenticator.discover().unwrap();
        assert_eq!(devices.len(), 1);
        assert_eq!(devices[0].label, "Mock Key");
        assert_eq!(devices[0].protocol, "CTAP2 / FIDO2");
        assert!(devices[0].credential_management);
        assert!(devices[0].pin);
        assert!(devices[0].fingerprint);
        authenticator.reset("usb:1").unwrap();
    }

    #[test]
    fn empty_hex_and_ctap_errors_are_mapped() {
        assert!(decode_hex("").is_err());
        assert!(encode_hex(&[]).is_err());
        assert!(ctap_error(0x31).contains("PIN 码错误"));
        assert!(is_empty_ctap(&ctap_error(0x2E)));
    }
}
