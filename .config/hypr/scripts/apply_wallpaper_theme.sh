#!/usr/bin/env bash
# apply_wallpaper_theme.sh — Detecta el wallpaper activo, extrae su paleta cromática y la aplica a Hyprland.
#
# Uso:
#   apply_wallpaper_theme.sh [ruta_imagen]
#
# Comportamiento:
#   1. Detecta la ruta del wallpaper actual (argumento, hyprpaper.conf o current_wallpaper.txt).
#   2. Extrae la paleta cromática representativa (accent, muted, dim) vía Python / Pillow.
#   3. Genera ~/.config/hypr/theme.conf para persistencia en reinicios / recargas.
#   4. Aplica el color del marco activo en vivo a través del socket IPC (hyprctl).
#   5. Sincroniza la caché de tema de Cocoa si está presente.

set -euo pipefail

HYPR_DIR="$HOME/.config/hypr"
SCRIPTS_DIR="$HYPR_DIR/scripts"
THEME_CONF="$HYPR_DIR/theme.conf"
HYPRPAPER_CONF="$HYPR_DIR/hyprpaper.conf"
COCOA_DIR="$HOME/.config/quickshell/cocoa"
COCOA_THEME="$COCOA_DIR/theme/current_theme.json"
COCOA_WALL_TXT="$COCOA_DIR/theme/current_wallpaper.txt"

log() { echo "[hypr-theme] $(date +%H:%M:%S) — $*"; }

WALL="${1:-}"

# ── 1. Detección de wallpaper ─────────────────────────────────────────────────
if [[ -z "$WALL" ]]; then
    if [[ -f "$HYPRPAPER_CONF" ]]; then
        # Buscar ruta en preload o path dentro de hyprpaper.conf
        DETECTED=$(grep -E "^\s*preload\s*=" "$HYPRPAPER_CONF" | head -n1 | awk '{print $NF}' || true)
        if [[ -z "$DETECTED" ]]; then
            DETECTED=$(grep -E "^\s*path\s*=" "$HYPRPAPER_CONF" | head -n1 | awk '{print $NF}' || true)
        fi
        WALL="$DETECTED"
    fi
fi

if [[ -z "$WALL" && -f "$COCOA_WALL_TXT" ]]; then
    WALL=$(cat "$COCOA_WALL_TXT" | tr -d '[:space:]')
fi

# Fallback si aún no hay wallpaper
if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    for fallback in "$HOME/Pictures/Wallpapers/w5.jpg" "$HOME/Pictures/Wallpapers"/*; do
        if [[ -f "$fallback" ]]; then
            WALL="$fallback"
            break
        fi
    done
fi

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    echo "ERROR: No se encontró ningún wallpaper válido para extraer colores." >&2
    exit 1
fi

log "Wallpaper objetivo: $WALL"

# ── 2. Extracción de color vía Python ──────────────────────────────────────────
PALETTE=$(python3 - <<EOF
import sys, os, json
from pathlib import Path

wall_path = "$WALL"
cocoa_extractor = Path.home() / ".config/quickshell/cocoa/scripts/extract_colors.py"

theme = None
if cocoa_extractor.is_file():
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("extract_colors", cocoa_extractor)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        theme = mod.extract_theme(wall_path)
    except Exception as e:
        theme = None

if theme is None:
    try:
        from PIL import Image
        import colorsys
        img = Image.open(wall_path).convert("RGB").resize((120, 120))
        palette = img.quantize(colors=12, method=Image.Quantize.MEDIANCUT).getpalette()
        # Buscar color más vivo
        candidates = []
        for i in range(12):
            r, g, b = palette[i*3], palette[i*3+1], palette[i*3+2]
            h, l, s = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
            if l >= 0.15 and s >= 0.05:
                candidates.append((h, s, l))
        if candidates:
            best = max(candidates, key=lambda c: c[1] * (c[2]**0.5))
            h, s, l = best
        else:
            h, s, l = 0.0, 0.0, 0.8
        # clamp display safe
        s = max(0.20, min(0.55, s))
        l = max(0.65, min(0.85, l))
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        hex_acc = f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"
        theme = {
            "text": "#ffffff",
            "accent": hex_acc,
            "textMuted": hex_acc,
            "textDim": "#555555"
        }
    except Exception as e:
        theme = {
            "text": "#ffffff",
            "accent": "#d1e7ae",
            "textMuted": "#adc686",
            "textDim": "#737f60"
        }

accent = theme.get("accent", "#d1e7ae").lstrip("#")
muted = theme.get("textMuted", "#adc686").lstrip("#")
dim = theme.get("textDim", "#737f60").lstrip("#")

print(f"{accent} {muted} {dim}")
EOF
)

read -r ACCENT MUTED DIM <<< "$PALETTE"

log "Colores extraídos — Accent: #$ACCENT, Muted: #$MUTED, Dim: #$DIM"

# ── 3. Escribir configuración persistente de Hyprland ────────────────────────
mkdir -p "$HYPR_DIR"
cat <<EOF > "$THEME_CONF"
# --- Dynamic Hyprland Theme (Auto-generated from wallpaper) ---
# Generado automáticamente por apply_wallpaper_theme.sh
# No editar directamente; este archivo se regenera al cambiar de fondo de pantalla.

\$wallpaper_accent = rgb($ACCENT)
\$wallpaper_accent_alpha = rgba(${ACCENT}ff)
\$wallpaper_muted = rgb($MUTED)
\$wallpaper_dim = rgb($DIM)
\$wallpaper_inactive = rgba(33333388)

general {
    col.active_border = \$wallpaper_accent
    col.inactive_border = \$wallpaper_inactive
}
EOF

log "Archivo de configuración actualizado: $THEME_CONF"

# ── 4. Aplicar en vivo vía IPC de Hyprland ─────────────────────────────────────
if command -v hyprctl &>/dev/null; then
    if hyprctl monitors &>/dev/null; then
        hyprctl keyword general:col.active_border "rgb($ACCENT)" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(33333388)" >/dev/null 2>&1 || true
        log "Colores aplicados en vivo vía hyprctl keyword."
    fi
fi

# ── 5. Mantener sincronizado Cocoa si corresponde ─────────────────────────────
if [[ -d "$COCOA_DIR/theme" ]]; then
    echo "$WALL" > "$COCOA_WALL_TXT" 2>/dev/null || true
    if [[ -f "$COCOA_DIR/scripts/extract_colors.py" ]]; then
        python3 "$COCOA_DIR/scripts/extract_colors.py" "$WALL" "$COCOA_THEME" >/dev/null 2>&1 || true
    fi
fi

# ── 6. Mantener sincronizado Ghostty con el tema activo ───────────────────────
if [[ -f "$COCOA_DIR/scripts/ghostty_sync.py" ]]; then
    python3 "$COCOA_DIR/scripts/ghostty_sync.py" || true
fi

log "Sincronización de tema completada exitosamente."
