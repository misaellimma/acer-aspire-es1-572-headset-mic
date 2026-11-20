#!/usr/bin/env bash
#
# Instalador do fix de microfone de headset para o Acer Aspire ES1-572
# (Realtek ALC233, SSID 1025:1085).
#
# Uso: sudo ./install.sh [--yes] [--no-deps] [--force]
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

SERVICE_NAME="acer-alc233-headset-mic.service"
MODPROBE_CONF="/etc/modprobe.d/99-acer-es1-572-headset.conf"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
SLEEP_HOOK="/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh"
BACKUP_ROOT="/var/backups/acer-alc233-headset-mic"

VENDOR_ID="0x10ec0235"
SUBSYSTEM_ID="0x10251085"

ASSUME_YES=0
INSTALL_DEPS=1
FORCE=0

info() { printf '[info]  %s\n' "$*"; }
ok()   { printf '[ok]    %s\n' "$*"; }
warn() { printf '[aviso] %s\n' "$*" >&2; }
die()  { printf '[erro]  %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Uso: sudo ./install.sh [opcoes]

Opcoes:
  -y, --yes       Nao pedir confirmacao para instalar o alsa-tools.
      --no-deps   Nao instalar dependencias (exige hda-verb ja instalado).
      --force     Continuar mesmo se o codec esperado nao for detectado.
  -h, --help      Mostrar esta ajuda.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes)  ASSUME_YES=1 ;;
        --no-deps) INSTALL_DEPS=0 ;;
        --force)   FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Opcao desconhecida: $arg (use --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "Rode como root: sudo ./install.sh"
command -v systemctl >/dev/null 2>&1 || die "systemd nao encontrado."

for required in \
    "$FILES_DIR/etc/modprobe.d/99-acer-es1-572-headset.conf" \
    "$FILES_DIR/etc/systemd/system/$SERVICE_NAME" \
    "$FILES_DIR/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh"; do
    [ -f "$required" ] || die "Arquivo do repositorio ausente: $required"
done

find_codec() {
    local f
    for f in /proc/asound/card*/codec#*; do
        [ -e "$f" ] || continue
        if grep -q "Vendor Id: $VENDOR_ID" "$f" 2>/dev/null &&
           grep -q "Subsystem Id: $SUBSYSTEM_ID" "$f" 2>/dev/null; then
            printf '%s\n' "$f"
            return 0
        fi
    done
    return 1
}

CODEC_FILE="$(find_codec || true)"
if [ -n "$CODEC_FILE" ]; then
    ok "Codec compativel encontrado: $CODEC_FILE (ALC233, SSID 1025:1085)."
elif [ "$FORCE" -eq 1 ]; then
    warn "Codec ALC233 (SSID 1025:1085) nao encontrado; seguindo por causa de --force."
else
    die "Este fix e especifico para o Realtek ALC233 com SSID 1025:1085 (Acer Aspire ES1-572). Codec nao encontrado. Use --force somente se souber o que esta fazendo."
fi

if ! command -v hda-verb >/dev/null 2>&1; then
    if [ "$INSTALL_DEPS" -eq 0 ]; then
        die "hda-verb nao encontrado. Instale o pacote alsa-tools."
    fi
    command -v apt-get >/dev/null 2>&1 ||
        die "hda-verb nao encontrado e apt-get indisponivel. Instale o alsa-tools manualmente."
    if [ "$ASSUME_YES" -eq 0 ]; then
        if [ -t 0 ]; then
            printf 'O pacote alsa-tools (hda-verb) nao esta instalado. Instalar agora? [S/n] '
            read -r reply
            case "$reply" in
                [nN]*) die "Instale o alsa-tools e rode novamente." ;;
            esac
        else
            die "alsa-tools ausente. Rode com --yes ou instale manualmente."
        fi
    fi
    info "Instalando alsa-tools..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y alsa-tools; then
        die "Falha ao instalar o alsa-tools. Rode 'sudo apt update' e tente novamente."
    fi
fi

command -v hda-verb >/dev/null 2>&1 || die "hda-verb continua indisponivel apos a instalacao."

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
mkdir -p "$BACKUP_DIR"

backup_file() {
    local src="$1" dst
    [ -e "$src" ] || return 0
    dst="$BACKUP_DIR$src"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    info "Backup: $src -> $dst"
}

backup_file "$MODPROBE_CONF"
backup_file "$SERVICE_FILE"
backup_file "$SLEEP_HOOK"

info "Instalando arquivos..."
install -D -m 0644 "$FILES_DIR/etc/modprobe.d/99-acer-es1-572-headset.conf" "$MODPROBE_CONF"
install -D -m 0644 "$FILES_DIR/etc/systemd/system/$SERVICE_NAME" "$SERVICE_FILE"
install -D -m 0755 "$FILES_DIR/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh" "$SLEEP_HOOK"
ok "Arquivos instalados."

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null
ok "Servico habilitado no boot."

if [ -e /dev/snd/hwC0D0 ]; then
    if systemctl restart "$SERVICE_NAME"; then
        ok "Coeficiente aplicado neste boot."
    else
        warn "O servico nao iniciou agora. Veja: journalctl -u $SERVICE_NAME"
    fi
else
    warn "/dev/snd/hwC0D0 ainda nao existe; o coeficiente sera aplicado no proximo boot."
fi

if command -v update-initramfs >/dev/null 2>&1; then
    info "Atualizando initramfs..."
    update-initramfs -u
else
    warn "update-initramfs nao encontrado; atualize o initramfs do seu sistema manualmente."
fi

DMESG_OUT="$(dmesg 2>/dev/null || true)"
case "$DMESG_OUT" in
    *"picked fixup alc233-asus"*) FIXUP_ACTIVE=1 ;;
    *) FIXUP_ACTIVE=0 ;;
esac

printf '\n'
ok "Instalacao concluida. Backup em: $BACKUP_DIR"
printf '\n'
if [ "$FIXUP_ACTIVE" -eq 1 ]; then
    printf 'O fixup ja esta ativo neste boot. Plugue o headset e teste:\n'
    printf '  ./check.sh --record\n'
else
    printf 'Reinicie o notebook para ativar o model=alc233-asus:\n'
    printf '  sudo reboot\n'
    printf '\nDepois do boot, plugue o headset e rode:\n'
    printf '  ./check.sh --record\n'
fi
printf '\nPara reverter: sudo ./uninstall.sh\n'
