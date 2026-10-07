#!/usr/bin/env bash
# start_shell.sh — Arranque robusto de Cocoa Shell (quickshell) y Hyprpaper en Hyprland
#
# Estrategia:
#   1. Espera a que el socket Wayland esté disponible (máx 10 s).
#   2. Espera a que el monitor eDP-1 aparezca en hyprctl (máx 15 s).
#   3. Asegura la ejecución desacoplada de hyprpaper cargando hyprpaper.conf explícitamente.
#   4. Lanza quickshell cocoa de forma desacoplada evitando falsos positivos con scripts auxiliares.

set -euo pipefail

WALL_CONF="$HOME/.config/hypr/hyprpaper.conf"

log() { echo "[start_shell] $(date +%H:%M:%S) — $*"; }

# ── 1. Esperar socket Wayland ─────────────────────────────────────────────────
log "Esperando socket Wayland..."
for i in $(seq 1 20); do
    if [ -S "${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-1" ] || \
       [ -S "${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-0" ]; then
        log "Socket Wayland disponible."
        break
    fi
    sleep 0.5
done

# ── 2. Esperar monitor eDP-1 en hyprctl ──────────────────────────────────────
log "Esperando monitor eDP-1..."
for i in $(seq 1 30); do
    if hyprctl monitors -j 2>/dev/null | grep -q '"eDP-1"'; then
        log "Monitor eDP-1 detectado."
        break
    fi
    sleep 0.5
done
sleep 0.5   # margen de estabilización

# ── 3. Asegurar ejecución de hyprpaper ────────────────────────────────────────
log "Verificando hyprpaper..."
if ! pgrep -x hyprpaper > /dev/null; then
    log "Lanzando hyprpaper con $WALL_CONF..."
    nohup hyprpaper -c "$WALL_CONF" >/dev/null 2>&1 &
    HP_PID=$!
    disown "$HP_PID" 2>/dev/null || true
    sleep 0.5
    if kill -0 "$HP_PID" 2>/dev/null; then
        log "hyprpaper iniciado correctamente (PID: $HP_PID)."
    else
        log "ADVERTENCIA: hyprpaper no pudo mantenerse en ejecución."
    fi
else
    log "hyprpaper ya está corriendo."
fi

# ── 3.5. Sincronizar tema de wallpaper con Hyprland ──────────────────────────
if [[ -x "$HOME/.config/hypr/scripts/apply_wallpaper_theme.sh" ]]; then
    log "Sincronizando colores de Hyprland con wallpaper..."
    "$HOME/.config/hypr/scripts/apply_wallpaper_theme.sh" || true
fi

# ── 4. Lanzar quickshell Cocoa (si no está ya corriendo) ─────────────────────
if ! pgrep -x quickshell > /dev/null && ! pgrep -f '(^|/)quickshell[[:space:]]+.*cocoa' > /dev/null; then
    log "Lanzando Cocoa Shell (quickshell)..."
    setsid -f quickshell -p "$HOME/.config/quickshell/cocoa" >/dev/null 2>&1
    sleep 1
    if pgrep -x quickshell > /dev/null || pgrep -f '(^|/)quickshell[[:space:]]+.*cocoa' > /dev/null; then
        log "Cocoa Shell iniciado correctamente."
    else
        log "ERROR: quickshell terminó inesperadamente. Revisar logs de QS."
    fi
else
    log "quickshell cocoa ya está corriendo."
fi

log "Arranque completo."
