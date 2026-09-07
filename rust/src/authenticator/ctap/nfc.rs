pub const FIDO_AID: &[u8] = &[0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01];

pub fn select_apdu() -> Vec<u8> {
    let mut apdu = vec![0x00, 0xA4, 0x04, 0x00, FIDO_AID.len() as u8];
    apdu.extend_from_slice(FIDO_AID);
    apdu.push(0x00);
    apdu
}

pub fn cbor_apdu(payload: &[u8]) -> Vec<u8> {
    let mut apdu = vec![0x80, 0x10, 0x00, 0x00];
    if payload.len() <= 255 {
        apdu.push(payload.len() as u8);
        apdu.extend_from_slice(payload);
        return apdu;
    }
    apdu.push(0x00);
    apdu.extend_from_slice(&(payload.len() as u16).to_be_bytes());
    apdu.extend_from_slice(payload);
    apdu
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wraps_short_and_extended_apdu() {
        let short = cbor_apdu(&[1, 2, 3]);
        assert_eq!(short[..5], [0x80, 0x10, 0x00, 0x00, 3]);
        let payload = vec![7u8; 300];
        let long = cbor_apdu(&payload);
        assert_eq!(long[..7], [0x80, 0x10, 0x00, 0x00, 0x00, 0x01, 0x2C]);
        assert_eq!(select_apdu()[4], 8);
    }
}
