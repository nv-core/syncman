#!/usr/bin/env bash
# installer for syncman — nova convention: ./install.sh install|update|uninstall
# User scope ONLY: syncman manages per-user systemd services and per-user data.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-install}"

[[ "${NOVA_SCOPE:-user}" == "user" ]] || { echo "error: syncman is user-only (SCOPE=user)" >&2; exit 1; }

PREFIX="${NOVA_PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/syncman"

say() { printf ':: %s\n' "$*"; }

# GUI parts are skipped on headless machines; nova exports NOVA_GUI=0/1,
# standalone installs fall back to checking for the GTK4 stack
want_gui() {
    [[ ${NOVA_GUI:-} == 0 ]] && return 1
    [[ -n ${NOVA_GUI:-} ]] && return 0
    [[ -e /usr/lib64/girepository-1.0/Gtk-4.0.typelib ||
       -e /usr/lib/girepository-1.0/Gtk-4.0.typelib ]]
}

do_install() {
    say "installing syncman + syncjob to $BIN"
    install -Dm755 "$SRC/bin/syncman" "$BIN/syncman"
    install -Dm755 "$SRC/bin/syncjob" "$BIN/syncjob"

    if want_gui; then
        say "installing syncman-panel + desktop entry"
        install -Dm755 "$SRC/gui/syncman-panel" "$BIN/syncman-panel"
        mkdir -p "$APPS"
        sed "s|^Exec=.*|Exec=$BIN/syncman-panel|" "$SRC/data/syncman-panel.desktop" \
            > "$APPS/org.novanetwork.Syncman.desktop"
    else
        say "no GTK4 stack (or NOVA_GUI=0) — skipping panel"
    fi

    say "installing service template"
    mkdir -p "$UNIT_DIR"
    # point the template at the actual install prefix
    sed "s|^ExecStart=.*|ExecStart=$BIN/syncjob %i|" "$SRC/data/syncjob@.service" \
        > "$UNIT_DIR/syncjob@.service"
    systemctl --user daemon-reload

    mkdir -p "$CONF_DIR/jobs"
    [[ -f "$CONF_DIR/syncman.conf" ]] || cat > "$CONF_DIR/syncman.conf" <<'EOF'
# syncman configuration
# seconds between sync passes:
INTERVAL=30
# where the .job files live (point at a Nextcloud-synced folder to share
# job definitions across machines):
#JOBS_DIR=~/Nextcloud/syncman-jobs
EOF
    say "done — try: syncman add <name>  |  syncman list  |  syncman-panel"
}

do_update() {
    do_install
    # running jobs keep the old worker process until restarted
    systemctl --user try-restart 'syncjob@*.service' 2>/dev/null || true
    say "restarted running sync jobs"
}

do_uninstall() {
    say "stopping all sync jobs"
    local u
    for u in $(systemctl --user list-units 'syncjob@*.service' --plain --no-legend 2>/dev/null | awk '{print $1}'); do
        systemctl --user disable --now "$u" 2>/dev/null || true
    done
    rm -f "$BIN/syncman" "$BIN/syncjob" "$BIN/syncman-panel" \
          "$APPS/org.novanetwork.Syncman.desktop" "$UNIT_DIR/syncjob@.service"
    systemctl --user daemon-reload
    say "kept: $CONF_DIR (config + job definitions) — remove manually if wanted"
}

case "$ACTION" in
    install)   do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
    *) echo "usage: $0 install|update|uninstall" >&2; exit 1 ;;
esac
