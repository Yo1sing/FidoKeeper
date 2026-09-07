#[derive(Clone, Debug, PartialEq)]
pub struct DeviceSummary {
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
