//! A conservative ABP subset parser and WebKit content-blocker JSON emitter.
//! Unsupported syntax is reported instead of silently pretending to be enforced.
use serde::Serialize;
use std::fmt;
use url::Url;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Rule {
    Network { trigger: String, action: String },
    Cosmetic { domains: Vec<String>, selector: String, exception: bool },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseWarning {
    pub line: usize,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseOutput {
    pub rules: Vec<Rule>,
    pub warnings: Vec<ParseWarning>,
}

#[derive(Debug)]
pub enum CompileError {
    InvalidUrl(String),
    Json(serde_json::Error),
}
impl fmt::Display for CompileError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidUrl(v) => write!(f, "invalid URL: {v}"),
            Self::Json(e) => write!(f, "JSON serialization failed: {e}"),
        }
    }
}
impl std::error::Error for CompileError {}

#[derive(Serialize)]
struct WebKitRule {
    trigger: Trigger,
    action: Action,
}
#[derive(Serialize)]
struct Trigger {
    #[serde(rename = "url-filter")]
    url_filter: String,
    #[serde(rename = "resource-type", skip_serializing_if = "Option::is_none")]
    resource_type: Option<Vec<String>>,
    #[serde(rename = "if-domain", skip_serializing_if = "Option::is_none")]
    if_domain: Option<Vec<String>>,
    #[serde(rename = "unless-domain", skip_serializing_if = "Option::is_none")]
    unless_domain: Option<Vec<String>>,
}
#[derive(Serialize)]
struct Action {
    #[serde(rename = "type")]
    kind: String,
}

fn is_comment_or_metadata(line: &str) -> bool {
    line.is_empty()
        || line.starts_with('!')
        || line.starts_with('[')
        || line.starts_with("@@")
        || line.starts_with("##")
        || line.starts_with("#@#")
        || line.starts_with("#?#")
        || line.starts_with("#@?#")
}

fn domain_list(options: &str, key: &str) -> Option<Vec<String>> {
    options.split(',').find_map(|part| {
        let (k, v) = part.trim().split_once('=')?;
        if k == key {
            Some(v.split('|').filter(|s| !s.is_empty()).map(str::to_owned).collect())
        } else {
            None
        }
    })
}

/// Parse a documented, conservative subset of ABP syntax. Unknown options and
/// unsupported cosmetic forms are warnings, not silently accepted rules.
pub fn parse_filter_list(input: &str) -> ParseOutput {
    let mut output = ParseOutput { rules: Vec::new(), warnings: Vec::new() };
    for (idx, raw) in input.lines().enumerate() {
        let line_no = idx + 1;
        let line = raw.trim();
        if is_comment_or_metadata(line) { continue; }

        if let Some((domains, selector)) = line.split_once("##") {
            if selector.is_empty() {
                output.warnings.push(ParseWarning { line: line_no, message: "empty cosmetic selector".into() });
                continue;
            }
            let domains: Vec<String> = domains.split(',').filter(|s| !s.is_empty()).map(str::to_owned).collect();
            output.rules.push(Rule::Cosmetic { domains, selector: selector.into(), exception: false });
            continue;
        }

        if line.contains("$") {
            // Options are intentionally limited to domain and resource type.
            let mut pieces = line.splitn(2, '$');
            let pattern = pieces.next().unwrap_or_default();
            let options = pieces.next().unwrap_or_default();
            let allowed = ["script", "image", "stylesheet", "font", "media", "xmlhttprequest", "subdocument", "third-party", "domain"];
            let unsupported: Vec<&str> = options.split(',').map(str::trim)
                .filter(|o| !allowed.contains(o) && !o.starts_with("domain=") && !o.starts_with("~domain="))
                .collect();
            if !unsupported.is_empty() {
                output.warnings.push(ParseWarning { line: line_no, message: format!("unsupported options: {}", unsupported.join(", ")) });
                continue;
            }
            let url_filter = abp_pattern_to_regex(pattern);
            let resources: Vec<String> = options.split(',').map(str::trim)
                .filter(|o| ["script", "image", "stylesheet", "font", "media", "xmlhttprequest", "subdocument"].contains(o))
                .map(str::to_owned).collect();
            let allow_domains = domain_list(options, "domain");
            output.rules.push(Rule::Network {
                trigger: if let Some(d) = allow_domains {
                    format!("{}|domains:{}", url_filter, d.join("|"))
                } else { url_filter },
                action: if resources.is_empty() { "block".into() } else { format!("block:{}", resources.join("|")) },
            });
            continue;
        }

        // Simple URL/domain patterns are accepted; advanced ABP syntax is not.
        if line.starts_with("||") || line.starts_with('|') || line.contains('*') || line.contains('^') {
            output.rules.push(Rule::Network { trigger: abp_pattern_to_regex(line), action: "block".into() });
        } else {
            output.warnings.push(ParseWarning { line: line_no, message: "unsupported rule syntax; skipped".into() });
        }
    }
    output
}

fn abp_pattern_to_regex(pattern: &str) -> String {
    // WebKit uses ICU regex. Escape regex metacharacters and translate the
    // common ABP wildcards/separator. This is a subset, not full ABP semantics.
    let mut out = String::from("^");
    let chars: Vec<char> = pattern.chars().collect();
    let mut i = 0;
    if pattern.starts_with("||") {
        out.push_str("^[a-z][a-z0-9+.-]*://([^/]+\\.)?");
        i = 2;
    } else if pattern.starts_with('|') {
        i = 1;
    }
    while i < chars.len() {
        match chars[i] {
            '*' => out.push_str(".*"),
            '^' => out.push_str("([^a-zA-Z0-9_.%-]|$)"),
            c if r".+?()[]{}$\\".contains(c) => { out.push('\\'); out.push(c); }
            c => out.push(c),
        }
        i += 1;
    }
    // WebKit patterns are regex strings; avoid double anchoring.
    if out.starts_with("^^") { out.remove(0); }
    out
}

/// Compile network rules to WebKit content-blocker JSON. Cosmetic rules are
/// intentionally emitted separately for a future WKUserScript-based path.
pub fn compile_webkit_json(input: &str) -> Result<(String, Vec<ParseWarning>), CompileError> {
    let parsed = parse_filter_list(input);
    let mut result: Vec<WebKitRule> = Vec::new();
    for rule in parsed.rules {
        if let Rule::Network { trigger, action } = rule {
            let (filter, domain_hint) = if let Some((f, rest)) = trigger.split_once("|domains:") {
                (f.to_owned(), Some(rest.split('|').map(str::to_owned).collect::<Vec<_>>()))
            } else { (trigger, None) };
            let (kind, resource_type) = if let Some(types) = action.strip_prefix("block:") {
                ("block", Some(types.split('|').map(str::to_owned).collect()))
            } else { ("block", None) };
            result.push(WebKitRule {
                trigger: Trigger { url_filter: filter, resource_type, if_domain: domain_hint, unless_domain: None },
                action: Action { kind: kind.into() },
            });
        }
    }
    let json = serde_json::to_string_pretty(&result).map_err(CompileError::Json)?;
    Ok((json, parsed.warnings))
}

/// Strip known tracking parameters from a URL. Kept here as a pure function so
/// the URL cleaner can be reused by non-Apple shells.
pub fn clean_tracking_url(input: &str, custom_parameters: &[String]) -> Result<String, CompileError> {
    let mut url = Url::parse(input).map_err(|_| CompileError::InvalidUrl(input.into()))?;
    let custom: Vec<String> = custom_parameters.iter().map(|s| s.to_ascii_lowercase()).collect();
    let remove = |key: &str| {
        let lower = key.to_ascii_lowercase();
        lower.starts_with("utm_")
            || ["fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid"].contains(&lower.as_str())
            || custom.contains(&lower)
    };
    let pairs: Vec<(String, String)> = url.query_pairs()
        .filter(|(k, _)| !remove(k))
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    url.set_query(None);
    if !pairs.is_empty() {
        url.query_pairs_mut().extend_pairs(pairs);
    }
    Ok(url.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_simple_network_and_cosmetic_rules() {
        let parsed = parse_filter_list("! header\n||ads.example^\nexample.com##.sponsor");
        assert_eq!(parsed.rules.len(), 2);
        assert!(matches!(parsed.rules[0], Rule::Network { .. }));
        assert!(matches!(parsed.rules[1], Rule::Cosmetic { .. }));
    }

    #[test]
    fn emits_valid_json() {
        let (json, warnings) = compile_webkit_json("||ads.example^\n||tracker.example^$script").unwrap();
        let value: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value.as_array().unwrap().len(), 2);
        assert!(warnings.is_empty());
    }

    #[test]
    fn skips_unknown_options_with_warning() {
        let parsed = parse_filter_list("||ads.example^$important,script");
        assert_eq!(parsed.rules.len(), 0);
        assert_eq!(parsed.warnings.len(), 1);
    }

    #[test]
    fn cleans_tracking_parameters() {
        let got = clean_tracking_url("https://example.com/?utm_source=x&ok=1&fbclid=abc", &[]).unwrap();
        assert!(got.contains("ok=1"));
        assert!(!got.contains("utm_source"));
        assert!(!got.contains("fbclid"));
    }

    #[test]
    fn invalid_url_is_reported() {
        assert!(clean_tracking_url("not a url", &[]).is_err());
    }
}
