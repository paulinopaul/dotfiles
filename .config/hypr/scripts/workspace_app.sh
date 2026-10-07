#!/bin/bash
TARGET_WORKSPACE=$1
TARGET_APP=$2

# Obtener el nombre del escritorio actual
CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.name')

if [ "$CURRENT_WORKSPACE" == "$TARGET_WORKSPACE" ]; then
    # Si ya estamos en el escritorio destino, regresamos al anterior (toggle)
    hyprctl dispatch workspace previous
else
    # Si no estamos en el escritorio destino, vamos hacia allá
    hyprctl dispatch workspace name:$TARGET_WORKSPACE
    
    # Esperar un milisegundo para que Hyprland registre el cambio
    sleep 0.1
    
    # Contar ventanas en el escritorio destino
    CLIENTS=$(hyprctl clients -j | jq "[.[] | select(.workspace.name == \"$TARGET_WORKSPACE\")] | length")
    
    if [ -z "$CLIENTS" ] || [ "$CLIENTS" -eq 0 ]; then
        echo "El escritorio está vacío, abriendo $TARGET_APP..."
        hyprctl dispatch exec $TARGET_APP
    fi
fi
