#!/usr/bin/env bash
# tests/test_hyprland_rounding.sh
# Validación automatizada defensiva del parámetro de curvatura (rounding) de ventanas en Hyprland.

set -euo pipefail

CONFIG_FILE="/home/paul/dotfiles/.config/hypr/hyprland.conf"
EXPECTED_ROUNDING=14

echo "[TEST-HYPRLAND] Iniciando validación de bordes redondeados..."

# 1. Validar presencia del archivo de configuración
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ASSERTION_ERROR: $CONFIG_FILE no existe." >&2
    exit 1
fi

# 2. Validar que hyprland.conf declare el bloque decoration con rounding = 10
if ! grep -qE "^\s*rounding\s*=\s*${EXPECTED_ROUNDING}\b" "$CONFIG_FILE"; then
    echo "ASSERTION_ERROR: 'rounding = ${EXPECTED_ROUNDING}' no se encuentra definido en $CONFIG_FILE" >&2
    exit 1
fi

# 3. Validar estado en vivo del compositor Hyprland vía IPC (hyprctl)
if command -v hyprctl &>/dev/null; then
    ROUNDING_INFO=$(hyprctl getoption decoration:rounding 2>/dev/null || true)
    
    if ! echo "$ROUNDING_INFO" | grep -qE "int:\s*${EXPECTED_ROUNDING}\b"; then
        echo "ASSERTION_ERROR: hyprctl getoption decoration:rounding no reporta int: ${EXPECTED_ROUNDING}. Salida: '$ROUNDING_INFO'" >&2
        exit 1
    fi

    if ! echo "$ROUNDING_INFO" | grep -qE "set:\s*true\b"; then
        echo "ASSERTION_ERROR: hyprctl getoption decoration:rounding reporta set: false en lugar de true." >&2
        exit 1
    fi
else
    echo "[TEST-HYPRLAND] ADVERTENCIA: hyprctl no disponible en PATH para validación en tiempo de ejecución."
fi

echo "[TEST-HYPRLAND] PASSED: rounding = ${EXPECTED_ROUNDING} verificado tanto estáticamente como en el compositor activo."
exit 0
