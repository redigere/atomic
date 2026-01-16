#!/usr/bin/env zsh
# @file set-cinnamon-look.sh
# @brief Configures KDE Plasma to look like Cinnamon desktop
# @description
#   Applies Cinnamon-style theming to KDE:
#   - Bottom panel (taskbar position)
#   - Window buttons on right (Close, Min, Max)
#   - Sharp/4px window corners
#   - Traditional application menu

set -euo pipefail

readonly SCRIPT_FILE="${0:A}"
readonly SCRIPT_DIR="${SCRIPT_FILE:h}"
source "$SCRIPT_DIR/../../../lib/common.sh"

readonly ORCHIS_REPO="https://github.com/vinceliuice/Orchis-theme.git"
readonly THEME_DIR="$HOME/.local/share/themes"
readonly GTK_THEME="Orchis-Dark"

# Corner radius for window decorations (Cinnamon-style: subtle)
readonly CORNER_RADIUS="4"

#######################################
# Installs the Orchis GTK theme from source (Standard variant).
#######################################
install-orchis() {
    log-info "Installing Orchis theme (Standard Dark)..."
    local work_dir
    work_dir="$(mktemp -d)"

    mkdir -p "$THEME_DIR"
    git clone --depth 1 "$ORCHIS_REPO" "$work_dir/orchis"
    pushd "$work_dir/orchis" > /dev/null

    # Install Dark variants with premium tweaks
    # We do NOT use 'compact' or patches here to keep it standard like Cinnamon
    ./install.sh -c dark --tweaks solid black primary

    popd > /dev/null
    rm -rf "$work_dir"
    log-success "Orchis theme installed"
}

#######################################
# Writes a KDE configuration value using kwriteconfig.
# Globals:
#   None
# Arguments:
#   $1 - Config file name
#   $2 - Group name
#   $3 - Key name
#   $4 - Value
#######################################
apply-kwrite() {
    local file="$1" group="$2" key="$3" value="$4"

    for tool in kwriteconfig6 kwriteconfig5; do
        if command -v "$tool" &>/dev/null; then
            "$tool" --file "$file" --group "$group" --key "$key" "$value"
            return
        fi
    done

    log-warn "No kwriteconfig tool found."
}

#######################################
# Reloads KWin configuration.
#######################################
reload-kwin() {
    for tool in qdbus6 qdbus qdbus-qt5; do
        if command -v "$tool" &>/dev/null; then
            "$tool" org.kde.KWin /KWin reconfigure 2>/dev/null || true
            return
        fi
    done
}

#######################################
# Reloads Plasma shell.
#######################################
reload-plasmashell() {
    for tool in qdbus6 qdbus qdbus-qt5; do
        if command -v "$tool" &>/dev/null; then
            "$tool" org.kde.plasmashell /PlasmaShell evaluateScript "loadTemplate('org.kde.plasma.desktop.defaultPanel')" 2>/dev/null || true
            return
        fi
    done
}

#######################################
# Configures window decoration for Cinnamon-style.
# - Window buttons on right (traditional order)
# - Sharp corners (4px radius or less)
#######################################
configure-window-decoration() {
    log-info "Configuring Cinnamon-style window decorations..."

    # Window buttons: right side (Cinnamon default)
    # M = Menu (optional), I = Minimize, A = Maximize, X = Close
    apply-kwrite "kwinrc" "org.kde.kdecoration2" "ButtonsOnLeft" "M"
    apply-kwrite "kwinrc" "org.kde.kdecoration2" "ButtonsOnRight" "IAX"

    # Use Breeze with customization for sharp corners
    apply-kwrite "kwinrc" "org.kde.kdecoration2" "library" "org.kde.breeze"
    apply-kwrite "kwinrc" "org.kde.kdecoration2" "theme" "Breeze"

    # Breeze specific: corner radius (only works in recent Plasma versions)
    apply-kwrite "breezerc" "Common" "CornerRadius" "$CORNER_RADIUS"
    apply-kwrite "breezerc" "Windeco" "CornerRadius" "$CORNER_RADIUS"

    # Disable window border glow for cleaner look
    apply-kwrite "breezerc" "Windeco" "DrawBackgroundGradient" "false"

    reload-kwin
    log-success "Window decorations configured (Cinnamon-style)"
}

#######################################
# Configures panel position (bottom, like Cinnamon).
# Note: Panel position is stored in plasma config files.
#######################################
configure-panel-position() {
    log-info "Panel position requires manual configuration or plasmashell reload..."
    log-info "Tip: Right-click panel → Panel Options → Panel Alignment → Bottom"

    # Panel configuration is complex in Plasma, usually done via plasmashellrc
    # We can set global preferences but panel layout needs plasmoid config

    log-success "Panel configured (move to bottom manually if not already)"
}

#######################################
# Applies Papirus icons and dark theme.
#######################################
configure-theme() {
    log-info "Applying Cinnamon-style theme..."

    apply-kwrite "kdeglobals" "Icons" "Theme" "Papirus-Dark"
    apply-kwrite "kdeglobals" "General" "ColorScheme" "BreezeDark"

    # Set GTK Theme to Orchis-Dark (for GTK apps running in Plasma)
    # We write to both GTK2 and GTK3 config locations
    if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        sed -i 's/^gtk-theme-name=.*/gtk-theme-name=Orchis-Dark/' "$HOME/.config/gtk-3.0/settings.ini" || echo "[Settings]\ngtk-theme-name=Orchis-Dark" >> "$HOME/.config/gtk-3.0/settings.ini"
    else
        mkdir -p "$HOME/.config/gtk-3.0"
        echo -e "[Settings]\ngtk-theme-name=Orchis-Dark" > "$HOME/.config/gtk-3.0/settings.ini"
    fi


    # Use default Breeze cursor
    apply-kwrite "kcminputrc" "Mouse" "cursorTheme" "breeze_cursors"

    log-success "Theme applied"
}

#######################################
# Configures task switcher for traditional alt-tab.
#######################################
configure-task-switcher() {
    log-info "Configuring traditional task switcher..."

    # Use thumbnail grid (similar to Cinnamon)
    apply-kwrite "kwinrc" "TabBox" "LayoutName" "thumbnail_grid"

    reload-kwin
    log-success "Task switcher configured"
}

#######################################
# Optimizes animations (faster, like Cinnamon).
#######################################
configure-animations() {
    log-info "Optimizing animations..."

    apply-kwrite "kdeglobals" "KDE" "AnimationDurationFactor" "0.5"
    apply-kwrite "kwinrc" "Compositing" "LatencyPolicy" "High"

    reload-kwin
    log-success "Animations optimized"
}

#######################################
# Main entry point.
#######################################
main() {
    ensure-user

    log-info "Applying Cinnamon-style look to KDE Plasma..."

    configure-window-decoration
    install-orchis
    configure-theme
    configure-task-switcher
    configure-animations
    configure-panel-position

    log-success "Cinnamon-style look applied!"
    log-info "Restart Plasma shell for full effect: kquitapp6 plasmashell && plasmashell &"
}

main "$@"
