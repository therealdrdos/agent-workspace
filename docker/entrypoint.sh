#!/bin/sh
# UID/GID mapping for Linux to prevent root-owned files in /workspace

set -e

DEFAULT_UID=1000
DEFAULT_GID=1000

TARGET_UID="${HOST_UID:-$DEFAULT_UID}"
TARGET_GID="${HOST_GID:-$DEFAULT_GID}"

if [ "$(id -u)" = "0" ]; then
    if [ "$TARGET_GID" != "$DEFAULT_GID" ]; then
        if getent group "$TARGET_GID" >/dev/null 2>&1; then
            existing_group=$(getent group "$TARGET_GID" | cut -d: -f1)
            if [ "$existing_group" != "dev" ]; then
                groupmod -g 65534 "$existing_group" 2>/dev/null || true
            fi
        fi
        groupmod -g "$TARGET_GID" dev 2>/dev/null || true
    fi

    if [ "$TARGET_UID" != "$DEFAULT_UID" ]; then
        if getent passwd "$TARGET_UID" >/dev/null 2>&1; then
            existing_user=$(getent passwd "$TARGET_UID" | cut -d: -f1)
            if [ "$existing_user" != "dev" ]; then
                usermod -u 65534 "$existing_user" 2>/dev/null || true
            fi
        fi
        usermod -u "$TARGET_UID" dev 2>/dev/null || true
    fi

    chown -R dev:dev /home/dev 2>/dev/null || true

    # runuser preserves arguments without shell quoting issues
    cd /workspace
    exec runuser -u dev -- "$@"
else
    exec "$@"
fi
