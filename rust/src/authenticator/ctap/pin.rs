use aes::Aes256;
use cbc::cipher::{block_padding::NoPadding, BlockDecryptMut, BlockEncryptMut, KeyIvInit};
use hkdf::Hkdf;
use hmac::{Hmac, Mac};
use p256::{ecdh::EphemeralSecret, EncodedPoint, PublicKey};
use rand_core::OsRng;
use sha2::{Digest, Sha256};

type HmacSha256 = Hmac<Sha256>;
type Aes256CbcEnc = cbc::Encryptor<Aes256>;
type Aes256CbcDec = cbc::Decryptor<Aes256>;

#[derive(Clone, Copy)]
pub struct PinProtocol {
    pub version: u8,
}

impl PinProtocol {
    pub fn preferred(supported: &[u8]) -> Result<Self, String> {
        if supported.contains(&2) {
            Ok(Self { version: 2 })
        } else if supported.contains(&1) {
            Ok(Self { version: 1 })
        } else {
            Err("认证器不支持 PIN/UV 协议".into())
        }
    }

    pub fn encapsulate(&self, x: &[u8], y: &[u8]) -> Result<(Vec<u8>, Vec<u8>, Vec<u8>), String> {
        if x.len() != 32 || y.len() != 32 {
            return Err("认证器密钥格式无效".into());
        }
        let mut sec1 = vec![0x04];
        sec1.extend_from_slice(x);
        sec1.extend_from_slice(y);
        let peer = PublicKey::from_sec1_bytes(&sec1).map_err(|_| "认证器公钥无效")?;
        let secret = EphemeralSecret::random(&mut OsRng);
        let shared = secret.diffie_hellman(&peer);
        let point = EncodedPoint::from(secret.public_key());
        let ours_x = point.x().ok_or("无法导出本地公钥")?.to_vec();
        let ours_y = point.y().ok_or("无法导出本地公钥")?.to_vec();
        Ok((
            ours_x,
            ours_y,
            self.kdf(shared.raw_secret_bytes().as_slice()),
        ))
    }

    fn kdf(&self, z: &[u8]) -> Vec<u8> {
        if self.version == 1 {
            return Sha256::digest(z).to_vec();
        }
        let hk = Hkdf::<Sha256>::new(Some(&[0u8; 32]), z);
        let mut hmac_key = [0u8; 32];
        let mut aes_key = [0u8; 32];
        hk.expand(b"CTAP2 HMAC key", &mut hmac_key)
            .expect("HKDF 长度固定");
        hk.expand(b"CTAP2 AES key", &mut aes_key)
            .expect("HKDF 长度固定");
        let mut out = hmac_key.to_vec();
        out.extend_from_slice(&aes_key);
        out
    }

    pub fn encrypt(&self, secret: &[u8], plaintext: &[u8]) -> Result<Vec<u8>, String> {
        if self.version == 1 {
            aes_cbc(&secret[..32.min(secret.len())], &[0u8; 16], plaintext, true)
        } else {
            let mut iv = [0u8; 16];
            rand_core::RngCore::fill_bytes(&mut OsRng, &mut iv);
            let mut out = iv.to_vec();
            out.extend(aes_cbc(&secret[32..], &iv, plaintext, true)?);
            Ok(out)
        }
    }

    pub fn decrypt(&self, secret: &[u8], ciphertext: &[u8]) -> Result<Vec<u8>, String> {
        if self.version == 1 {
            aes_cbc(
                &secret[..32.min(secret.len())],
                &[0u8; 16],
                ciphertext,
                false,
            )
        } else {
            if ciphertext.len() < 16 {
                return Err("PIN 令牌密文过短".into());
            }
            aes_cbc(&secret[32..], &ciphertext[..16], &ciphertext[16..], false)
        }
    }

    pub fn authenticate(&self, secret: &[u8], message: &[u8]) -> Result<Vec<u8>, String> {
        let key = if self.version == 1 {
            &secret[..32.min(secret.len())]
        } else {
            &secret[..32]
        };
        let mut mac = HmacSha256::new_from_slice(key).map_err(|_| "HMAC 密钥无效")?;
        mac.update(message);
        let tag = mac.finalize().into_bytes();
        if self.version == 1 {
            Ok(tag[..16].to_vec())
        } else {
            Ok(tag.to_vec())
        }
    }
}

pub fn pin_hash(pin: &str) -> [u8; 16] {
    let digest = Sha256::digest(pin.as_bytes());
    let mut out = [0u8; 16];
    out.copy_from_slice(&digest[..16]);
    out
}

pub fn pad_pin(pin: &str) -> Result<Vec<u8>, String> {
    let mut padded = pin.as_bytes().to_vec();
    if padded.len() < 4 || padded.len() > 63 {
        return Err("PIN 长度无效".into());
    }
    padded.resize(64, 0);
    Ok(padded)
}

fn aes_cbc(key: &[u8], iv: &[u8], data: &[u8], encrypt: bool) -> Result<Vec<u8>, String> {
    if key.len() != 32 || iv.len() != 16 || !data.len().is_multiple_of(16) {
        return Err("PIN 加解密参数无效".into());
    }
    let mut buf = data.to_vec();
    if encrypt {
        Aes256CbcEnc::new(key.into(), iv.into())
            .encrypt_padded_mut::<NoPadding>(&mut buf, data.len())
            .map_err(|_| "PIN 加密失败")?;
    } else {
        Aes256CbcDec::new(key.into(), iv.into())
            .decrypt_padded_mut::<NoPadding>(&mut buf)
            .map_err(|_| "PIN 解密失败")?;
    }
    Ok(buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pin_v1_roundtrip_and_mac_length() {
        let proto = PinProtocol { version: 1 };
        let secret = [7u8; 32];
        let plain = [9u8; 16];
        let cipher = proto.encrypt(&secret, &plain).unwrap();
        assert_eq!(cipher.len(), 16);
        assert_eq!(proto.decrypt(&secret, &cipher).unwrap(), plain);
        assert_eq!(proto.authenticate(&secret, b"abc").unwrap().len(), 16);
        assert_eq!(pad_pin("1234").unwrap().len(), 64);
        assert!(pad_pin("12").is_err());
    }

    #[test]
    fn pin_v2_prefixes_iv_and_uses_full_hmac() {
        let proto = PinProtocol { version: 2 };
        let mut secret = vec![1u8; 32];
        secret.extend_from_slice(&[2u8; 32]);
        let plain = [3u8; 16];
        let cipher = proto.encrypt(&secret, &plain).unwrap();
        assert_eq!(cipher.len(), 32);
        assert_eq!(proto.decrypt(&secret, &cipher).unwrap(), plain);
        assert_eq!(proto.authenticate(&secret, b"abc").unwrap().len(), 32);
        assert_eq!(PinProtocol::preferred(&[1, 2]).unwrap().version, 2);
        assert_eq!(PinProtocol::preferred(&[1]).unwrap().version, 1);
    }
}
