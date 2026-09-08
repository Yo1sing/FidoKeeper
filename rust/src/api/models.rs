#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Transport {
    Usb,
    Nfc,
    Hid,
}

impl Transport {
    pub(crate) fn from_path(path: &str) -> Self {
        let path = path.to_ascii_lowercase();
        if path.starts_with("nfc") {
            Self::Nfc
        } else if path.starts_with("usb") {
            Self::Usb
        } else {
            Self::Hid
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct DeviceSummary {
    pub transport: Transport,
    pub path: String,
    pub label: String,
    pub protocol: String,
    pub credential_management: bool,
    pub pin: bool,
    pub fingerprint: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CredentialSummary {
    pub id: String,
    pub rp_id: String,
    pub rp_name: String,
    pub user_name: String,
    pub user_display_name: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct BioTemplateSummary {
    pub id: String,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct HiddenAuthenticator {
    pub path: String,
    pub label: String,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(default)]
pub struct Preferences {
    pub locale: String,
    pub theme: String,
    pub hidden_authenticators: Vec<HiddenAuthenticator>,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            locale: "zh-CN".into(),
            theme: "system".into(),
            hidden_authenticators: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn transport_classification_preserves_platform_paths() {
        assert_eq!(Transport::from_path("USB:1"), Transport::Usb);
        assert_eq!(Transport::from_path("nfc:tag"), Transport::Nfc);
        assert_eq!(Transport::from_path("/dev/hidraw0"), Transport::Hid);
        assert_eq!(Transport::from_path("unknown"), Transport::Hid);
    }
}
