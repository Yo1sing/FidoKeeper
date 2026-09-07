use ciborium::value::Integer;
pub use ciborium::value::Value;

pub fn integer(n: i64) -> Value {
    Value::Integer(Integer::from(n))
}

pub fn text(value: impl Into<String>) -> Value {
    Value::Text(value.into())
}

pub fn bytes(value: impl Into<Vec<u8>>) -> Value {
    Value::Bytes(value.into())
}

pub fn bool_val(value: bool) -> Value {
    Value::Bool(value)
}

pub fn map(entries: Vec<(Value, Value)>) -> Value {
    Value::Map(entries)
}

pub fn encode_map(entries: Vec<(i64, Value)>) -> Result<Vec<u8>, String> {
    encode(&map(entries
        .into_iter()
        .map(|(k, v)| (integer(k), v))
        .collect()))
}

pub fn encode(value: &Value) -> Result<Vec<u8>, String> {
    let mut out = Vec::new();
    ciborium::into_writer(value, &mut out).map_err(|_| "CBOR 编码失败".to_owned())?;
    Ok(out)
}

pub fn decode(data: &[u8]) -> Result<Value, String> {
    ciborium::from_reader(data).map_err(|_| "CBOR 解码失败".to_owned())
}

pub fn map_get<'a>(value: &'a Value, key: i64) -> Option<&'a Value> {
    let Value::Map(entries) = value else {
        return None;
    };
    entries.iter().find_map(|(k, v)| match k {
        Value::Integer(n) if i64::try_from(*n).ok() == Some(key) => Some(v),
        _ => None,
    })
}

pub fn map_get_text(value: &Value, key: &str) -> String {
    let Value::Map(entries) = value else {
        return String::new();
    };
    entries
        .iter()
        .find_map(|(k, v)| match (k, v) {
            (Value::Text(name), Value::Text(text)) if name == key => Some(text.clone()),
            _ => None,
        })
        .unwrap_or_default()
}

pub fn map_get_bytes(value: &Value, key: &str) -> Option<Vec<u8>> {
    let Value::Map(entries) = value else {
        return None;
    };
    entries.iter().find_map(|(k, v)| match (k, v) {
        (Value::Text(name), Value::Bytes(bytes)) if name == key => Some(bytes.clone()),
        _ => None,
    })
}

pub fn as_bytes(value: &Value) -> Option<Vec<u8>> {
    match value {
        Value::Bytes(bytes) => Some(bytes.clone()),
        _ => None,
    }
}

pub fn as_text(value: &Value) -> Option<String> {
    match value {
        Value::Text(text) => Some(text.clone()),
        _ => None,
    }
}

pub fn as_u64(value: &Value) -> Option<u64> {
    match value {
        Value::Integer(n) => u64::try_from(*n).ok(),
        _ => None,
    }
}

pub fn as_u8(value: &Value) -> Option<u8> {
    as_u64(value).and_then(|n| u8::try_from(n).ok())
}

pub fn as_array(value: &Value) -> Option<&Vec<Value>> {
    match value {
        Value::Array(items) => Some(items),
        _ => None,
    }
}

pub fn option_true(options: &Value, name: &str) -> bool {
    option(options, name) == Some(true)
}

pub fn option_present(options: &Value, name: &str) -> bool {
    option(options, name).is_some()
}

pub fn option(options: &Value, name: &str) -> Option<bool> {
    let Value::Map(entries) = options else {
        return None;
    };
    entries.iter().find_map(|(k, v)| match (k, v) {
        (Value::Text(key), Value::Bool(value)) if key == name => Some(*value),
        _ => None,
    })
}

pub fn cose_key(x: Vec<u8>, y: Vec<u8>) -> Value {
    map(vec![
        (integer(1), integer(2)),
        (integer(3), integer(-25)),
        (integer(-1), integer(1)),
        (integer(-2), bytes(x)),
        (integer(-3), bytes(y)),
    ])
}

pub fn cose_xy(value: &Value) -> Result<(Vec<u8>, Vec<u8>), String> {
    let x = as_bytes(map_get(value, -2).ok_or("缺少认证器公钥")?).ok_or("认证器公钥无效")?;
    let y = as_bytes(map_get(value, -3).ok_or("缺少认证器公钥")?).ok_or("认证器公钥无效")?;
    Ok((x, y))
}

pub fn credential_descriptor(id: &[u8]) -> Value {
    map(vec![
        (text("type"), text("public-key")),
        (text("id"), bytes(id.to_vec())),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn integer_keys_roundtrip() {
        let encoded = encode_map(vec![(1, integer(2)), (2, bytes(vec![9]))]).unwrap();
        let value = decode(&encoded).unwrap();
        assert_eq!(as_u64(map_get(&value, 1).unwrap()), Some(2));
        assert_eq!(as_bytes(map_get(&value, 2).unwrap()).unwrap(), vec![9]);
    }
}
