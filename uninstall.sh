#!/usr/bin/env bash
#
# Desinstalador do fix de microfone de headset do Acer Aspire ES1-572.
#
set -euo pipefail

SERVICE_NAME="acer-alc233-headset-mic.service"
MODPROBE_CONF="/etc/modprobe.d/99-acer-es1-572-headset.conf"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
SLEEP_HOOK="/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh"
BACKUP_ROOT="/var/backups/acer-alc233-headset-mic"

RESTORE=0
RESTORE_DIR=""

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ok]    %s\n' "$*"; }
die()  { printf '[erro]  %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Uso: sudo ./uninstall.sh [opcoes]

Opcoes:
      --restore     Restaura o backup mais recente, se existir.
      --from DIR    Restaura um backup especifico.
  -h, --help        Mostrar esta ajuda.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --restore) RESTORE=1; shift ;;
        --from)
            [ $# -ge 2 ] || die "--from exige um diretorio."
            RESTORE=1
            RESTORE_DIR="$2"
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) die "Opcao desconhecida: $1 (use --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "Rode como root: sudo ./uninstall.sh"

systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true

if [ "$RESTORE" -eq 1 ]; then
    if [ -z "$RESTORE_DIR" ]; then
        RESTORE_DIR="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
    fi
    [ -n "$RESTORE_DIR" ] && [ -d "$RESTORE_DIR" ] || die "Nenhum backup encontrado em $BACKUP_ROOT."
    info "Restaurando backup de: $RESTORE_DIR"
    for target in "$MODPROBE_CONF" "$SERVICE_FILE" "$SLEEP_HOOK"; do
        src="$RESTORE_DIR$target"
        if [ -e "$src" ]; then
            install -D -m "$(stat -c %a "$src")" "$src" "$target"
            ok "Restaurado: $target"
        else
            rm -f "$target"
            ok "Mantido removido (nao existia no backup): $target"
        fi
    done
else
    rm -f "$MODPROBE_CONF" "$SERVICE_FILE" "$SLEEP_HOOK"
    ok "Arquivos removidos."
fi

systemctl daemon-reload

if [ "$RESTORE" -eq 1 ] && [ -e "$SERVICE_FILE" ]; then
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
    info "Servico do backup habilitado novamente."
fi

if command -v update-initramfs >/dev/null 2>&1; then
    info "Atualizando initramfs..."
    update-initramfs -u
fi

printf '\n'
ok "Desinstalacao concluida."
printf 'Reinicie para voltar ao estado anterior: sudo reboot\n'
