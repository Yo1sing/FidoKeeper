const TYPE_INIT: u8 = 0x80;
pub const CMD_INIT: u8 = 0x06;
pub const CMD_CBOR: u8 = 0x10;
pub const CMD_ERROR: u8 = 0x3F;
pub const CMD_KEEPALIVE: u8 = 0x3B;
pub const BROADCAST: u32 = 0xFFFFFFFF;

pub fn encode_frames(
    cid: u32,
    cmd: u8,
    data: &[u8],
    packet_size: usize,
) -> Result<Vec<Vec<u8>>, String> {
    if packet_size < 8 {
        return Err("HID 报文过短".into());
    }
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut header = header_init(cid, cmd, data.len() as u16);
    let mut seq = 0u8;
    loop {
        let room = packet_size - header.len();
        let take = (data.len() - offset).min(room);
        let mut packet = header;
        packet.extend_from_slice(&data[offset..offset + take]);
        packet.resize(packet_size, 0);
        frames.push(packet);
        offset += take;
        if offset >= data.len() {
            break;
        }
        header = header_cont(cid, seq);
        seq = seq.checked_add(1).ok_or("HID 续包序号溢出")?;
        if seq & 0x80 != 0 {
            return Err("HID 续包过多".into());
        }
    }
    Ok(frames)
}

pub struct Decoder {
    cid: u32,
    cmd: u8,
    expected: usize,
    seq: u8,
    payload: Vec<u8>,
}

impl Decoder {
    pub fn push(&mut self, packet: &[u8]) -> Result<Option<Vec<u8>>, String> {
        if packet.len() < 5 {
            return Err("HID 应答过短".into());
        }
        let cid = u32::from_be_bytes(packet[0..4].try_into().unwrap());
        if cid != self.cid {
            return Err("HID 通道不匹配".into());
        }
        if self.payload.is_empty() && self.expected == 0 {
            if packet.len() < 7 {
                return Err("HID 首包过短".into());
            }
            let cmd = packet[4];
            if cmd == TYPE_INIT | CMD_KEEPALIVE {
                return Ok(None);
            }
            if cmd == TYPE_INIT | CMD_ERROR {
                return Err(hid_error(packet[5]));
            }
            if cmd != TYPE_INIT | self.cmd {
                return Err("HID 命令不匹配".into());
            }
            self.expected = u16::from_be_bytes([packet[5], packet[6]]) as usize;
            self.payload.extend_from_slice(&packet[7..]);
        } else {
            let seq = packet[4];
            if seq != self.seq {
                return Err("HID 续包序号错误".into());
            }
            self.seq += 1;
            self.payload.extend_from_slice(&packet[5..]);
        }
        if self.payload.len() >= self.expected {
            self.payload.truncate(self.expected);
            Ok(Some(std::mem::take(&mut self.payload)))
        } else {
            Ok(None)
        }
    }
}

pub fn decoder(cid: u32, cmd: u8) -> Decoder {
    Decoder {
        cid,
        cmd,
        expected: 0,
        seq: 0,
        payload: Vec::new(),
    }
}

pub fn parse_init(nonce: &[u8], response: &[u8]) -> Result<u32, String> {
    if response.len() < 12 || &response[..8] != nonce {
        return Err("HID INIT 握手失败".into());
    }
    Ok(u32::from_be_bytes(response[8..12].try_into().unwrap()))
}

fn header_init(cid: u32, cmd: u8, len: u16) -> Vec<u8> {
    let mut header = cid.to_be_bytes().to_vec();
    header.push(TYPE_INIT | cmd);
    header.extend_from_slice(&len.to_be_bytes());
    header
}

fn header_cont(cid: u32, seq: u8) -> Vec<u8> {
    let mut header = cid.to_be_bytes().to_vec();
    header.push(seq);
    header
}

fn hid_error(code: u8) -> String {
    match code {
        0x01 => "HID 无效命令".into(),
        0x02 => "HID 无效参数".into(),
        0x03 => "HID 无效长度".into(),
        0x04 => "HID 无效序号".into(),
        0x05 => "HID 消息超时".into(),
        0x06 => "HID 通道忙".into(),
        0x0B => "HID 通道被占用".into(),
        _ => format!("HID 错误 {code}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_and_reassembles_payload() {
        let data: Vec<u8> = (0..80).collect();
        let frames = encode_frames(0x11223344, CMD_CBOR, &data, 64).unwrap();
        assert_eq!(frames.len(), 2);
        assert_eq!(frames[0].len(), 64);
        assert_eq!(frames[1][4], 0);
        let mut decoder = decoder(0x11223344, CMD_CBOR);
        assert!(decoder.push(&frames[0]).unwrap().is_none());
        assert_eq!(decoder.push(&frames[1]).unwrap().unwrap(), data);
    }

    #[test]
    fn skips_keepalive_and_parses_init() {
        let mut decoder = decoder(BROADCAST, CMD_INIT);
        let mut keepalive = vec![0xff; 64];
        keepalive[4] = TYPE_INIT | CMD_KEEPALIVE;
        assert!(decoder.push(&keepalive).unwrap().is_none());
        let nonce = [1, 2, 3, 4, 5, 6, 7, 8];
        let mut body = nonce.to_vec();
        body.extend_from_slice(&0xAABBCCDDu32.to_be_bytes());
        body.extend_from_slice(&[2, 0, 0, 1, 4]);
        let frames = encode_frames(BROADCAST, CMD_INIT, &body, 64).unwrap();
        let payload = decoder.push(&frames[0]).unwrap().unwrap();
        assert_eq!(parse_init(&nonce, &payload).unwrap(), 0xAABBCCDD);
    }
}
