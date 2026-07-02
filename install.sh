#!/usr/bin/env bash
# =============================================================================
# install.sh — installer for konsole-tab-title
# Detects your shell, copies the right plugin file, and patches your rc file.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

info()    { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
warn()    { printf "  ${YELLOW}!${RESET}  %s\n" "$*"; }
error()   { printf "  ${RED}✖${RESET}  %s\n" "$*" >&2; }
section() { printf "\n${BOLD}%s${RESET}\n" "$*"; }
rule()    { printf '%0.s─' {1..60}; printf '\n'; }

# ---------------------------------------------------------------------------
# Locate source files (directory this script lives in)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Detect shell
# ---------------------------------------------------------------------------
section "Shell detection"

DETECTED_SHELL="$(basename "${SHELL:-}")"

if [[ -z "$DETECTED_SHELL" ]]; then
    error "Could not read \$SHELL. Please set it and re-run."
    exit 1
fi

printf "  Detected login shell: ${BOLD}%s${RESET}\n" "$DETECTED_SHELL"
printf "  Is this correct? [Y/n] "
read -r CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    printf "\n  Which shell are you using? (zsh / bash / fish): "
    read -r DETECTED_SHELL
    DETECTED_SHELL="${DETECTED_SHELL// /}"
fi

case "$DETECTED_SHELL" in
    zsh|bash|fish) ;;
    *)
        error "Unsupported shell: '$DETECTED_SHELL'. Only zsh, bash, and fish are supported."
        exit 1 ;;
esac

info "Using shell: $DETECTED_SHELL"

# ---------------------------------------------------------------------------
# 2. Copy plugin file + edit rc
# ---------------------------------------------------------------------------
section "Installing plugin"

PLUGIN_SRC="$SCRIPT_DIR/konsole-tab-title.${DETECTED_SHELL}"
INSTALL_DIR="$HOME/.config/konsole-tab-title"
PLUGIN_DEST="$INSTALL_DIR/konsole-tab-title.${DETECTED_SHELL}"

if [[ ! -f "$PLUGIN_SRC" ]]; then
    error "Plugin file not found: $PLUGIN_SRC"
    error "Make sure install.sh is in the same directory as the plugin files."
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$PLUGIN_SRC" "$PLUGIN_DEST"
chmod 644 "$PLUGIN_DEST"
info "Copied plugin to $PLUGIN_DEST"

case "$DETECTED_SHELL" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        SOURCE_LINE="source \"$PLUGIN_DEST\""
        ;;
    bash)
        RC_FILE="$HOME/.bashrc"
        SOURCE_LINE="source \"$PLUGIN_DEST\""
        ;;
    fish)
        FISH_CONF_D="$HOME/.config/fish/conf.d"
        FISH_LINK="$FISH_CONF_D/konsole-tab-title.fish"
        mkdir -p "$FISH_CONF_D"
        # Fish auto-sources everything in conf.d — a symlink is cleaner than
        # editing config.fish because the file manages its own lifecycle.
        if [[ -L "$FISH_LINK" || -f "$FISH_LINK" ]]; then
            rm "$FISH_LINK"
        fi
        ln -s "$PLUGIN_DEST" "$FISH_LINK"
        info "Symlinked into $FISH_LINK (auto-sourced by fish)"
        RC_FILE=""
        SOURCE_LINE=""
        ;;
esac

if [[ -n "$RC_FILE" ]]; then
    if grep -qF "$SOURCE_LINE" "$RC_FILE" 2>/dev/null; then
        warn "Source line already present in $RC_FILE — skipping."
    else
        printf '\n# konsole-tab-title\n%s\n' "$SOURCE_LINE" >> "$RC_FILE"
        info "Appended source line to $RC_FILE"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Terminal-specific OSC configuration
# ---------------------------------------------------------------------------
section "Terminal configuration"
rule

cat << 'MSG'

  If you use any of the following terminals, you're all set — they
  respect OSC escape sequences by default and need no configuration:

    Kitty · Alacritty · WezTerm · foot · GNOME Terminal
    Tilix · xterm · st · Hyper · Windows Terminal · iTerm2

  If you use one of the terminals below, follow the relevant steps:

MSG

printf "  ${BOLD}Konsole${RESET}\n"
cat << 'MSG'
    Settings → Edit Current Profile → Tabs
    In the "Tab title format" field, set the value to:  %w
    Click OK / Apply.

MSG

printf "  ${BOLD}tmux${RESET} (if you run your shell inside tmux)\n"
cat << 'MSG'
    Add to ~/.tmux.conf:
      set -g set-titles on
      set -g set-titles-string "#T"
    Then reload: tmux source-file ~/.tmux.conf

MSG

printf "  ${BOLD}GNU Screen${RESET}\n"
cat << 'MSG'
    Add to ~/.screenrc:
      termcapinfo xterm* 'ts=\E]2;:fs=\007:ds=\E]2;\007'

MSG

rule

# ---------------------------------------------------------------------------
# 4. Remind to restart
# ---------------------------------------------------------------------------
section "Done!"

case "$DETECTED_SHELL" in
    fish) printf "  Start a new fish session (or run: source %s)\n\n" "$FISH_LINK" ;;
    *)    printf "  Restart your terminal or run: source %s\n\n" "$RC_FILE" ;;
esac
