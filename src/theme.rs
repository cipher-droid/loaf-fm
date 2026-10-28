//! System appearance: dark mode detection and wallpaper palettes
//! (matugen / pywal / quickshell), plus host information. Moved unchanged
//! from the original bridge.rs.

use std::fs;
use std::path::{Path, PathBuf};

fn run_cmd_stdout(cmd: &str, args: &[&str]) -> Option<String> {
    let output = std::process::Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn dark_from_gsettings() -> Option<bool> {
    let out = run_cmd_stdout("gsettings", &["get", "org.gnome.desktop.interface", "color-scheme"])?;
    let s = out.to_lowercase();
    if s.contains("prefer-dark") {
        Some(true)
    } else if s.contains("prefer-light") {
        Some(false)
    } else {
        // "default"/unset means "no preference": try the next source.
        None
    }
}

fn dark_from_portal() -> Option<bool> {
    let out = run_cmd_stdout(
        "gdbus",
        &[
            "call",
            "--session",
            "--dest",
            "org.freedesktop.portal.Desktop",
            "--object-path",
            "/org/freedesktop/portal/desktop",
            "--method",
            "org.freedesktop.portal.Settings.Read",
            "org.freedesktop.appearance",
            "color-scheme",
        ],
    )?;
    // Reply shape: (<uint32 1>,) where 0 = no preference, 1 = prefer dark, 2 = prefer light.
    if out.contains("uint32 1") {
        Some(true)
    } else if out.contains("uint32 2") {
        Some(false)
    } else {
        None
    }
}

fn dark_from_gtk_settings() -> Option<bool> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-3.0/settings.ini")),
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-4.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-3.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-4.0/settings.ini")),
    ];

    for candidate in candidates.into_iter().flatten() {
        let Ok(content) = fs::read_to_string(&candidate) else { continue };
        for line in content.lines() {
            let line = line.trim();
            let Some((key, value)) = line.split_once('=') else { continue };
            if key.trim() != "gtk-application-prefer-dark-theme" {
                continue;
            }
            let v = value.trim().to_lowercase();
            if v == "1" || v == "true" || v == "yes" || v == "on" {
                return Some(true);
            }
            if v == "0" || v == "false" || v == "no" || v == "off" {
                return Some(false);
            }
        }
    }
    None
}

/// Detection order: gsettings -> XDG desktop portal -> GTK settings.ini -> dark.
pub fn detect_system_dark_mode() -> bool {
    if let Some(dark) = dark_from_gsettings() {
        return dark;
    }
    if let Some(dark) = dark_from_portal() {
        return dark;
    }
    if let Some(dark) = dark_from_gtk_settings() {
        return dark;
    }
    true
}

pub fn read_system_hostname() -> String {
    if let Ok(s) = fs::read_to_string("/proc/sys/kernel/hostname") {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "PC".to_string()
}

// ---- Colour maths ---------------------------------------------------------

type Rgb = (u8, u8, u8);

/// Parses `#rgb`, `#rrggbb` and `#rrggbbaa`. Empty or malformed values are
/// rejected: a palette entry that is present but blank (pywalfox leaves
/// several ANSI slots empty) must never become a QML colour.
fn parse_hex(value: &str) -> Option<Rgb> {
    let raw = value.trim().trim_start_matches('#');
    let hex = match raw.len() {
        3 | 4 => raw[..3].chars().flat_map(|c| [c, c]).collect::<String>(),
        6 | 8 => raw[..6].to_string(),
        _ => return None,
    };
    if !hex.chars().all(|c| c.is_ascii_hexdigit()) {
        return None;
    }
    Some((
        u8::from_str_radix(&hex[0..2], 16).ok()?,
        u8::from_str_radix(&hex[2..4], 16).ok()?,
        u8::from_str_radix(&hex[4..6], 16).ok()?,
    ))
}

fn to_hex(c: Rgb) -> String {
    format!("#{:02x}{:02x}{:02x}", c.0, c.1, c.2)
}

fn luminance(c: Rgb) -> f32 {
    fn channel(v: u8) -> f32 {
        let v = v as f32 / 255.0;
        if v <= 0.04045 {
            v / 12.92
        } else {
            ((v + 0.055) / 1.055).powf(2.4)
        }
    }
    0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
}

fn contrast(a: Rgb, b: Rgb) -> f32 {
    let (la, lb) = (luminance(a), luminance(b));
    (la.max(lb) + 0.05) / (la.min(lb) + 0.05)
}

/// Linear mix: `t == 0` keeps `a`, `t == 1` returns `b`.
fn mix(a: Rgb, b: Rgb, t: f32) -> Rgb {
    let t = t.clamp(0.0, 1.0);
    let channel = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * t).round() as u8;
    (channel(a.0, b.0), channel(a.1, b.1), channel(a.2, b.2))
}

fn shade(c: Rgb, factor: f32) -> Rgb {
    let channel = |v: u8| ((v as f32) * factor).round().clamp(0.0, 255.0) as u8;
    (channel(c.0), channel(c.1), channel(c.2))
}

/// Pushes `fg` towards black or white until it has `min` contrast on `bg`.
/// Used so derived text colours stay readable whatever the palette contains.
fn ensure_contrast(fg: Rgb, bg: Rgb, min: f32) -> Rgb {
    if contrast(fg, bg) >= min {
        return fg;
    }
    let target: Rgb = if luminance(bg) > 0.35 { (0, 0, 0) } else { (255, 255, 255) };
    let (mut low, mut high) = (0.0f32, 1.0f32);
    for _ in 0..12 {
        let mid = (low + high) / 2.0;
        if contrast(mix(fg, target, mid), bg) >= min {
            high = mid;
        } else {
            low = mid;
        }
    }
    mix(fg, target, high)
}

fn brighter(a: Option<Rgb>, b: Option<Rgb>) -> Option<Rgb> {
    match (a, b) {
        (Some(x), Some(y)) => Some(if luminance(x) >= luminance(y) { x } else { y }),
        (Some(x), None) | (None, Some(x)) => Some(x),
        (None, None) => None,
    }
}

/// Full Material-3-like scheme derived from a wallpaper palette. Every
/// foreground is contrast-checked against the surface it sits on, so a palette
/// with a dark `color7` (matugen's pywalfox output uses a surface tone there)
/// cannot produce dark-on-dark text again.
fn derive_scheme(background: Rgb, text: Rgb, primary: Rgb, secondary: Rgb, tertiary: Rgb) -> serde_json::Map<String, serde_json::Value> {
    let text = ensure_contrast(text, background, 7.0);
    let primary = ensure_contrast(primary, background, 3.0);
    let secondary = ensure_contrast(secondary, background, 3.0);
    let tertiary = ensure_contrast(tertiary, background, 3.0);

    let surface_container_lowest = shade(background, 0.86);
    let surface_container_low = mix(background, text, 0.05);
    let surface_container = mix(background, text, 0.08);
    let surface_container_high = mix(background, text, 0.13);
    let surface_container_highest = mix(background, text, 0.19);

    let primary_container = mix(primary, background, 0.62);
    let secondary_container = mix(secondary, background, 0.68);
    let tertiary_container = mix(tertiary, background, 0.68);

    let mut out = serde_json::Map::new();
    let mut put = |key: &str, value: Rgb| {
        out.insert(key.to_string(), serde_json::json!(to_hex(value)));
    };

    put("background", background);
    put("surface", background);
    put("surface_container_lowest", surface_container_lowest);
    put("surface_container_low", surface_container_low);
    put("surface_container", surface_container);
    put("surface_container_high", surface_container_high);
    put("surface_container_highest", surface_container_highest);

    put("primary", primary);
    put("on_primary", ensure_contrast(background, primary, 4.5));
    put("primary_container", primary_container);
    put("on_primary_container", ensure_contrast(primary, primary_container, 4.5));
    put("inverse_primary", ensure_contrast(primary, (250, 248, 244), 3.0));

    put("secondary_container", secondary_container);
    put("on_secondary_container", ensure_contrast(secondary, secondary_container, 4.5));
    put("tertiary_container", tertiary_container);

    put("on_background", text);
    put("on_surface", text);
    put("on_surface_variant", ensure_contrast(mix(text, background, 0.72), background, 4.5));
    put("outline", ensure_contrast(mix(text, background, 0.55), background, 3.0));
    put("outline_variant", mix(background, text, 0.22));

    out
}

pub fn normalize_wallpaper_colors(content: &str) -> String {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(content) else {
        return content.to_string();
    };

    // A real scheme (matugen/quickshell): use it verbatim, but only when the
    // two colours the UI depends on are actually valid.
    let scheme_value = |key: &str| val.get(key).and_then(|v| v.as_str()).and_then(parse_hex);
    let scheme_background = scheme_value("background").or_else(|| scheme_value("surface"));
    if let Some(background) = scheme_background {
        if scheme_value("primary").is_some() {
            return content.to_string();
        }
        // Background but no usable accent: rebuild the missing roles instead of
        // handing QML an empty colour.
        let text = scheme_value("on_surface")
            .or_else(|| scheme_value("on_background"))
            .unwrap_or((0xe4, 0xe2, 0xde));
        let primary = (0x95, 0xcd, 0xf7);
        let secondary = scheme_value("secondary").unwrap_or(primary);
        let tertiary = scheme_value("tertiary").unwrap_or(secondary);
        let out = derive_scheme(background, text, primary, secondary, tertiary);
        return serde_json::to_string(&out).unwrap_or_else(|_| content.to_string());
    }

    let Some(colors) = val.get("colors").and_then(|v| v.as_object()) else {
        return content.to_string();
    };

    let color = |key: &str| colors.get(key).and_then(|v| v.as_str()).and_then(parse_hex);
    let special = |key: &str| {
        val.get("special")
            .and_then(|s| s.get(key))
            .and_then(|v| v.as_str())
            .and_then(parse_hex)
    };

    let background = special("background")
        .or_else(|| color("color0"))
        .or_else(|| color("color8"))
        .unwrap_or((0x12, 0x12, 0x14));

    // pywal puts the normal foreground in color7 and the bright one in color15.
    // Some generators (matugen's pywalfox template) instead put a *surface*
    // tone in color7, so only trust color7 when it is actually readable and
    // fall back to color15 otherwise.
    let normal_text = color("color7");
    let text = special("foreground")
        .or_else(|| match normal_text {
            Some(c) if contrast(c, background) >= 4.5 => Some(c),
            _ => brighter(normal_text, color("color15")),
        })
        .unwrap_or((0xe4, 0xe2, 0xde));

    let primary = color("color4")
        .or_else(|| color("color12"))
        .or_else(|| color("color6"))
        .or_else(|| color("color10"))
        .or_else(|| color("color3"))
        .or_else(|| color("color2"))
        .or_else(|| color("color5"))
        .unwrap_or((0x95, 0xcd, 0xf7));

    let secondary = color("color6")
        .or_else(|| color("color2"))
        .or_else(|| color("color13"))
        .or_else(|| color("color5"))
        .or_else(|| color("color12"))
        .unwrap_or(primary);

    let tertiary = color("color5")
        .or_else(|| color("color13"))
        .or_else(|| color("color1"))
        .or_else(|| color("color9"))
        .unwrap_or(secondary);

    let out = derive_scheme(background, text, primary, secondary, tertiary);
    serde_json::to_string(&out).unwrap_or_else(|_| content.to_string())
}

/// Returns (source_path, content, mtime_secs) for the first readable color source.
pub fn read_wallpaper_colors_source() -> Option<(String, String, u64)> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        format!("{}/.local/state/quickshell/user/generated/colors.json", home),
        format!("{}/.cache/wal/colors.json", home),
        format!("{}/.cache/matugen/colors.json", home),
        format!("{}/.config/matugen/colors.json", home),
        format!("{}/.cache/DankMaterialShell/dms-colors.json", home),
        format!("{}/.cache/current_wallpaper_palette.json", home),
    ];

    for path_str in candidates {
        let path = Path::new(&path_str);
        let Ok(raw_content) = fs::read_to_string(path) else { continue };
        let is_object = serde_json::from_str::<serde_json::Value>(&raw_content)
            .ok()
            .map(|v| v.is_object() && v.as_object().map(|o| !o.is_empty()).unwrap_or(false))
            .unwrap_or(false);
        if !is_object {
            continue;
        }
        let content = normalize_wallpaper_colors(&raw_content);
        let mtime = fs::metadata(path)
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        return Some((path_str, content, mtime));
    }
    None
}

pub fn read_wallpaper_colors() -> String {
    read_wallpaper_colors_source()
        .map(|(_, content, _)| content)
        .unwrap_or_else(|| "{}".to_string())
}


pub fn detect_device_type() -> &'static str {
    if let Ok(chassis) = fs::read_to_string("/sys/class/dmi/id/chassis_type") {
        match chassis.trim() {
            "8" | "9" | "10" | "11" | "14" | "30" | "31" | "32" => return "laptop",
            _ => {}
        }
    }
    if Path::new("/sys/class/power_supply/BAT0").exists() || Path::new("/sys/class/power_supply/BAT1").exists() {
        return "laptop";
    }
    "desktop"
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    // The palette matugen writes for pywalfox: ANSI slots are mostly empty and
    // color7 holds a surface tone (this is what made Loaf's wallpaper mode
    // unreadable).
    const PYWALFOX: &str = r##"{
        "wallpaper": "/tmp/w.png",
        "alpha": "100",
        "colors": {
            "color0": "#101417", "color1": "", "color2": "", "color3": "#95cdf7",
            "color4": "", "color5": "#b7c9d9", "color6": "", "color7": "#313539",
            "color8": "", "color9": "", "color10": "#95cdf7", "color11": "",
            "color12": "", "color13": "#b7c9d9", "color14": "", "color15": "#e0e3e8"
        }
    }"##;

    fn scheme(input: &str) -> Value {
        serde_json::from_str(&normalize_wallpaper_colors(input)).expect("normalised scheme must be JSON")
    }

    fn colour(value: &Value, key: &str) -> Rgb {
        parse_hex(value[key].as_str().unwrap_or_else(|| panic!("missing {key}")))
            .unwrap_or_else(|| panic!("{key} is not a colour"))
    }

    #[test]
    fn pywalfox_empty_slots_produce_readable_text() {
        let out = scheme(PYWALFOX);
        let background = colour(&out, "background");

        assert_eq!(to_hex(background), "#101417");
        // color7 is a dark surface in this format; color15 must win instead.
        assert_eq!(to_hex(colour(&out, "on_surface")), "#e0e3e8");
        assert!(contrast(colour(&out, "on_surface"), background) >= 7.0);
        assert!(contrast(colour(&out, "on_surface_variant"), background) >= 4.5);
        // Empty ANSI slots must never leak through.
        assert_eq!(to_hex(colour(&out, "primary")), "#95cdf7");
        for key in [
            "surface_container_lowest",
            "surface_container_low",
            "surface_container",
            "surface_container_high",
            "surface_container_highest",
            "primary_container",
            "secondary_container",
            "tertiary_container",
            "outline",
            "outline_variant",
        ] {
            assert!(out[key].as_str().is_some(), "{key} missing");
            assert!(parse_hex(out[key].as_str().unwrap()).is_some(), "{key} invalid");
        }
    }

    #[test]
    fn standard_pywal_keeps_its_colours() {
        let out = scheme(
            r##"{"colors": {
                "color0": "#1e1e2e", "color4": "#89b4fa", "color5": "#f5c2e7",
                "color7": "#cdd6f4", "color8": "#585b70", "color15": "#ffffff"
            }}"##,
        );
        let background = colour(&out, "background");
        assert_eq!(to_hex(colour(&out, "primary")), "#89b4fa");
        assert_eq!(to_hex(colour(&out, "on_surface")), "#cdd6f4");
        assert!(contrast(colour(&out, "on_surface"), background) >= 7.0);
    }

    #[test]
    fn full_scheme_is_passed_through_untouched() {
        let input = r##"{"background":"#101417","primary":"#95cdf7","on_surface":"#e0e3e8"}"##;
        assert_eq!(normalize_wallpaper_colors(input), input);
    }

    #[test]
    fn scheme_with_blank_primary_is_not_trusted() {
        let out = scheme(r##"{"background":"#101417","primary":"","on_surface":"#e0e3e8"}"##);
        assert!(parse_hex(out["primary"].as_str().unwrap()).is_some());
        assert!(contrast(colour(&out, "on_surface"), colour(&out, "background")) >= 7.0);
    }

    #[test]
    fn empty_palette_falls_back_to_defaults() {
        let out = scheme(r##"{"colors":{}}"##);
        assert!(contrast(colour(&out, "on_surface"), colour(&out, "background")) >= 7.0);
    }
}
