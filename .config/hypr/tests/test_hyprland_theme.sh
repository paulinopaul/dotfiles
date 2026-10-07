#!/usr/bin/env bash
# tests/test_hyprland_theme.sh
# Validación automatizada del theming dinámico por wallpaper y sombras de ventanas en Hyprland.

set -euo pipefail

CONFIG_FILE="/home/paul/dotfiles/.config/hypr/hyprland.conf"
THEME_FILE="/home/paul/dotfiles/.config/hypr/theme.conf"
SCRIPT_FILE="/home/paul/dotfiles/.config/hypr/scripts/apply_wallpaper_theme.sh"

echo "[TEST-HYPRLAND-THEME] Iniciando validación de theming y sombras..."

# 1. Validar archivos requeridos
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ASSERTION_ERROR: $CONFIG_FILE no existe." >&2
    exit 1
fi

if [[ ! -f "$THEME_FILE" ]]; then
    echo "ASSERTION_ERROR: $THEME_FILE no existe." >&2
    exit 1
fi

if [[ ! -x "$SCRIPT_FILE" ]]; then
    echo "ASSERTION_ERROR: $SCRIPT_FILE no existe o no tiene permisos de ejecución." >&2
    exit 1
fi

# 2. Validar inclusión en hyprland.conf
if ! grep -q "source = ~/.config/hypr/theme.conf" "$CONFIG_FILE"; then
    echo "ASSERTION_ERROR: 'source = ~/.config/hypr/theme.conf' no se encuentra en $CONFIG_FILE" >&2
    exit 1
fi

if ! grep -qE "^\s*shadow\s*\{" "$CONFIG_FILE"; then
    echo "ASSERTION_ERROR: Bloque 'shadow' no declarado en $CONFIG_FILE" >&2
    exit 1
fi

if ! grep -qE "^\s*enabled\s*=\s*true" "$CONFIG_FILE"; then
    echo "ASSERTION_ERROR: 'shadow { enabled = true }' no declarado en $CONFIG_FILE" >&2
    exit 1
fi

# 3. Validar contenido de theme.conf
if ! grep -q "\$wallpaper_accent" "$THEME_FILE"; then
    echo "ASSERTION_ERROR: \$wallpaper_accent no definido en $THEME_FILE" >&2
    exit 1
fi

if ! grep -q "col.active_border" "$THEME_FILE"; then
    echo "ASSERTION_ERROR: col.active_border no definido en $THEME_FILE" >&2
    exit 1
fi

# 4. Validar estado en vivo del compositor vía IPC (hyprctl)
if command -v hyprctl &>/dev/null && hyprctl monitors &>/dev/null; then
    # Verificar borde activo (no debe ser el blanco por defecto ffffffff)
    ACTIVE_BORDER=$(hyprctl getoption general:col.active_border 2>/dev/null || true)
    if echo "$ACTIVE_BORDER" | grep -q "ffffffff 0deg"; then
        echo "ASSERTION_ERROR: col.active_border sigue en blanco por defecto (ffffffff)." >&2
        exit 1
    fi

    # Verificar que el borde activo fue configurado (set: true)
    if ! echo "$ACTIVE_BORDER" | grep -q "set: true"; then
        echo "ASSERTION_ERROR: col.active_border no está aplicado en el compositor activo." >&2
        exit 1
    fi

    # Verificar sombra ligera habilitada
    SHADOW_ENABLED=$(hyprctl getoption decoration:shadow:enabled 2>/dev/null || true)
    if ! echo "$SHADOW_ENABLED" | grep -qE "int:\s*1\b"; then
        echo "ASSERTION_ERROR: decoration:shadow:enabled no está activo en hyprctl." >&2
        exit 1
    fi

    echo "[TEST-HYPRLAND-THEME] Verificación en vivo en el compositor exitosa."
else
    echo "[TEST-HYPRLAND-THEME] ADVERTENCIA: Compositor no detectado o hyprctl no disponible."
fi

echo "[TEST-HYPRLAND-THEME] PASSED: Theming dinámico y sombras ligeras validados exitosamente."
exit 0
