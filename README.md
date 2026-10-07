# Dotfiles de Sistema (Hyprland & Caelestia)

Repositorio modular centralizado para la configuración del entorno de escritorio basado en Arch Linux (Hyprland) y el shell Caelestia.

## Arquitectura
La configuración sigue el Principio de Responsabilidad Única aislando los módulos en un solo repositorio unificado (`~/dotfiles`). 
Se utilizan enlaces simbólicos (symlinks) desde el repositorio hasta las ubicaciones esperadas por el sistema (`~/.config/`).

- `.config/hypr/`: Configuración del gestor de ventanas (Wayland compositors), terminal por defecto (`ghostty`) y demonio de fondos (`hyprpaper`).
- `.config/caelestia/`: Configuración personalizada del shell y variables del entorno.

## Dependencias
- Git
- SSH (Autenticación para GitHub)
- Hyprland
- Ghostty (Terminal emulator por defecto)
- Hyprpaper (Demonio de wallpaper Wayland)
- Quickshell (Cocoa Shell)

## Despliegue Local (Restauración)
En caso de reinstalación del sistema, ejecutar los siguientes comandos para restaurar los enlaces simbólicos de forma segura:

```bash
# Clonar el repositorio
git clone git@github.com:pauloryuu/dotfiles.git ~/dotfiles

# Crear enlaces simbólicos
ln -s ~/dotfiles/.config/hypr ~/.config/hypr
ln -s ~/dotfiles/.config/caelestia ~/.config/caelestia
```

## Estado de Auditoría (Post-Mortem)
Implementación inicial: Configuración extraída de entornos locales vivos (en `.config`) y centralizada exitosamente, eliminando acoplamientos del entorno raíz.
