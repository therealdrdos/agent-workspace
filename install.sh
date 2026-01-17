#!/bin/sh
# Installer for agent-workspace wrapper and config

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER_SRC="$REPO_DIR/agent-workspace.wrapper"
CONF_SRC="$REPO_DIR/agent-w.conf.example"

FORCE=0
AUTO=0
NO_PRUNE=0
MODE=""

for arg in "$@"; do
    case "$arg" in
        --run)      MODE="run" ;;
        --uninstall) MODE="uninstall" ;;
        --force)    FORCE=1 ;;
        -y)         AUTO=1 ;;
        --no-prune) NO_PRUNE=1 ;;
        --help|-h)  MODE="" ;;
        *)
            printf 'Unknown option: %s\n\n' "$arg" >&2
            MODE=""
            ;;
    esac
done

BIN_DIR="${HOME}/.local/bin"
WRAPPER_DEST="$BIN_DIR/agent-workspace"

if [ -n "$XDG_CONFIG_HOME" ]; then
    CONF_DIR="$XDG_CONFIG_HOME/agent-workspace"
    CONF_DEST="$CONF_DIR/agent-w.conf"
else
    CONF_DIR=""
    CONF_DEST="$HOME/.agent-w.conf"
fi

[ -r "$WRAPPER_SRC" ] || { printf 'Error: missing wrapper: %s\n' "$WRAPPER_SRC" >&2; exit 1; }
[ -r "$CONF_SRC" ] || { printf 'Error: missing config: %s\n' "$CONF_SRC" >&2; exit 1; }

usage() {
    cat <<EOF
Usage:
  install.sh --run [-y] [--force]    Install wrapper and config
  install.sh --uninstall [--no-prune] Remove everything
  install.sh --help                  Show this help

Options:
  -y         Use defaults, no prompts
  --force    Overwrite existing config
  --no-prune Skip docker system prune
EOF
}

prompt() {
    printf '%s\nDefault: %s\n> ' "$1" "$2" >&2
    read -r input
    printf '%s' "${input:-$2}"
}

check_mounts() {
    for mount in $1; do
        case "$mount" in
            *:*) ;;
            *) printf 'Error: invalid mount: %s\n' "$mount" >&2; exit 1 ;;
        esac
    done
}

need_tty() {
    [ -t 0 ] || { printf 'Error: requires TTY\n' >&2; exit 1; }
}

do_install() {
    # shellcheck source=/dev/null
    . "$CONF_SRC"

    printf 'agent-workspace installer\n\n'

    if [ "$AUTO" -eq 0 ]; then
        need_tty

        AGENT_WORKSPACE_HOME="$(prompt 'Repo path (AGENT_WORKSPACE_HOME)' "$AGENT_WORKSPACE_HOME")"
        printf '\n'
        WRAPPER_DEST="$(prompt 'Wrapper install path' "$WRAPPER_DEST")"
        printf '\n'
        IMAGE_NAME="$(prompt 'Docker image name' "$IMAGE_NAME")"
        printf '\n'
        CONTAINER_NAME="$(prompt 'Docker container name' "$CONTAINER_NAME")"
        printf '\n'

        printf 'Port bind address\n  1) 127.0.0.1 (default)\n  2) 0.0.0.0\n> '
        read -r input
        case "$input" in
            2) PORT_BIND_ADDRESS="0.0.0.0" ;;
            *) PORT_BIND_ADDRESS="127.0.0.1" ;;
        esac
        printf '\n'

        PORTS="$(prompt 'Ports (space-separated)' "$PORTS")"
        printf '\n'
        VOLUME_MOUNTS="$(prompt 'Volume mounts (name:/path)' "$VOLUME_MOUNTS")"
        printf '\n'
    fi

    [ -z "$AGENT_WORKSPACE_HOME" ] && { printf 'Error: AGENT_WORKSPACE_HOME empty\n' >&2; exit 1; }
    [ -z "$IMAGE_NAME" ] && { printf 'Error: IMAGE_NAME empty\n' >&2; exit 1; }
    [ -z "$CONTAINER_NAME" ] && { printf 'Error: CONTAINER_NAME empty\n' >&2; exit 1; }
    check_mounts "$VOLUME_MOUNTS"

    [ -x "$AGENT_WORKSPACE_HOME/agent-workspace" ] || {
        printf 'Error: not found: %s/agent-workspace\n' "$AGENT_WORKSPACE_HOME" >&2
        exit 1
    }

    mkdir -p "$(dirname "$WRAPPER_DEST")"
    cp "$WRAPPER_SRC" "$WRAPPER_DEST"
    chmod +x "$WRAPPER_DEST"

    [ -n "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

    if [ -e "$CONF_DEST" ] && [ "$FORCE" -eq 0 ]; then
        printf 'Config exists: %s (use --force to overwrite)\n' "$CONF_DEST" >&2
    else
        cat > "$CONF_DEST" <<EOF
# agent-workspace config

AGENT_WORKSPACE_HOME="$AGENT_WORKSPACE_HOME"
IMAGE_NAME="$IMAGE_NAME"
CONTAINER_NAME="$CONTAINER_NAME"
PORT_BIND_ADDRESS="$PORT_BIND_ADDRESS"
PORTS="$PORTS"
VOLUME_MOUNTS="$VOLUME_MOUNTS"
EOF
    fi

    wrapper_dir=$(dirname "$WRAPPER_DEST")
    case ":$PATH:" in
        *":$wrapper_dir:"*) ;;
        *) printf 'Warning: %s not in PATH\n' "$wrapper_dir" >&2 ;;
    esac

    printf 'Installed: %s\nConfig: %s\n' "$WRAPPER_DEST" "$CONF_DEST"
}

do_uninstall() {
    [ -r "$CONF_DEST" ] || { printf 'Error: config not found: %s\n' "$CONF_DEST" >&2; exit 1; }

    # shellcheck source=/dev/null
    . "$CONF_DEST"

    [ -z "$AGENT_WORKSPACE_HOME" ] && { printf 'Error: AGENT_WORKSPACE_HOME not set\n' >&2; exit 1; }

    [ -x "$AGENT_WORKSPACE_HOME/agent-workspace" ] && "$AGENT_WORKSPACE_HOME/agent-workspace" stop || true

    for mount in $VOLUME_MOUNTS; do
        case "$mount" in
            *:*)
                vol=${mount%%:*}
                [ -n "$vol" ] && docker volume rm "$vol" >/dev/null 2>&1 || true
                ;;
        esac
    done

    [ "$NO_PRUNE" -eq 0 ] && docker system prune -a

    wrapper_path=$(command -v agent-workspace 2>/dev/null || true)
    if [ -n "$wrapper_path" ] && [ -f "$wrapper_path" ]; then
        grep -q "agent-workspace wrapper" "$wrapper_path" && rm -f "$wrapper_path"
    fi

    [ -f "$WRAPPER_DEST" ] && rm -f "$WRAPPER_DEST"
    [ -f "$CONF_DEST" ] && rm -f "$CONF_DEST"

    printf 'Uninstalled.\n'
}

[ -z "$MODE" ] && { usage; exit 0; }

case "$MODE" in
    run)       do_install ;;
    uninstall) do_uninstall ;;
esac
