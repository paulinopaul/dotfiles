#!/usr/bin/env bash
# tests/test_hyprland_keybinds.sh
# Validación automatizada defensiva de atajos direccionales en Hyprland.

set -euo pipefail

CONFIG_FILE="/home/paul/dotfiles/.config/hypr/hyprland.conf"

echo "[TEST-HYPRLAND-BINDS] Iniciando suite de validación TDD para atajos direccionales..."

# 1. Validación de existencia del archivo de configuración
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ASSERTION_ERROR: $CONFIG_FILE no existe." >&2
    exit 1
fi

# 2. Validación estática en hyprland.conf
python3 - << 'EOF'
import sys
import re
from pathlib import Path

config_path = Path("/home/paul/dotfiles/.config/hypr/hyprland.conf")
content = config_path.read_text(encoding="utf-8")

# Verificación de atajos para mover ventanas: SUPER SHIFT + flechas
required_move_binds = [
    ("left", "l"),
    ("right", "r"),
    ("up", "u"),
    ("down", "d")
]

for key, direction in required_move_binds:
    pattern = rf"^\s*bind\s*=\s*SUPER\s+SHIFT\s*,\s*{key}\s*,\s*movewindow\s*,\s*{direction}\b"
    if not re.search(pattern, content, re.MULTILINE):
        sys.stderr.write(f"ASSERTION_ERROR: Falta atajo estático 'bind = SUPER SHIFT, {key}, movewindow, {direction}' en hyprland.conf\n")
        sys.exit(1)

# Verificación de atajos para mover foco: SUPER + flechas
required_focus_binds = [
    ("left", "l"),
    ("right", "r"),
    ("up", "u"),
    ("down", "d")
]

for key, direction in required_focus_binds:
    pattern = rf"^\s*bind\s*=\s*SUPER\s*,\s*{key}\s*,\s*movefocus\s*,\s*{direction}\b"
    if not re.search(pattern, content, re.MULTILINE):
        sys.stderr.write(f"ASSERTION_ERROR: Falta atajo estático 'bind = SUPER, {key}, movefocus, {direction}' en hyprland.conf\n")
        sys.exit(1)

print("[TEST-HYPRLAND-BINDS] Validación estática en hyprland.conf superada con éxito.")
EOF

# 3. Validación dinámica en tiempo de ejecución mediante IPC hyprctl
if command -v hyprctl &>/dev/null; then
    echo "[TEST-HYPRLAND-BINDS] Consultando estado en vivo del compositor vía hyprctl binds -j..."
    python3 - << 'EOF'
import subprocess
import json
import sys

res = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True)
if res.returncode != 0:
    sys.stderr.write(f"ASSERTION_ERROR: Fallo al ejecutar hyprctl binds -j: {res.stderr}\n")
    sys.exit(1)

try:
    binds = json.loads(res.stdout)
except json.JSONDecodeError as e:
    sys.stderr.write(f"ASSERTION_ERROR: Salida de hyprctl no es JSON válido: {e}\n")
    sys.exit(1)

# modmask 65 = SUPER (64) + SHIFT (1)
# modmask 64 = SUPER (64)

directions = [
    ("left", "l"),
    ("right", "r"),
    ("up", "u"),
    ("down", "d")
]

for key, arg in directions:
    # 1. Validar movewindow con SUPER SHIFT (modmask 65)
    matched_move = any(
        b.get("modmask") == 65 and
        b.get("key") == key and
        b.get("dispatcher") == "movewindow" and
        b.get("arg") == arg
        for b in binds
    )
    if not matched_move:
        sys.stderr.write(f"ASSERTION_ERROR: Compositor activo no tiene registrado 'SUPER SHIFT, {key} -> movewindow {arg}' (modmask 65)\n")
        sys.exit(1)

    # 2. Validar movefocus con SUPER (modmask 64)
    matched_focus = any(
        b.get("modmask") == 64 and
        b.get("key") == key and
        b.get("dispatcher") == "movefocus" and
        b.get("arg") == arg
        for b in binds
    )
    if not matched_focus:
        sys.stderr.write(f"ASSERTION_ERROR: Compositor activo no tiene registrado 'SUPER, {key} -> movefocus {arg}' (modmask 64)\n")
        sys.exit(1)

print("[TEST-HYPRLAND-BINDS] Validación dinámica en vivo del compositor superada.")
EOF
else
    echo "[TEST-HYPRLAND-BINDS] ADVERTENCIA: hyprctl no disponible en PATH para validación dinámica."
fi

echo "[TEST-HYPRLAND-BINDS] PASSED: Todos los atajos direccionales verificados estática y dinámicamente."
exit 0
