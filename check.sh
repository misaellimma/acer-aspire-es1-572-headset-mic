#!/usr/bin/env bash
#
# Verifica se o fix do microfone de headset esta ativo no Acer Aspire ES1-572.
#
# Uso: ./check.sh [--record]
#
set -uo pipefail

SERVICE_NAME="acer-alc233-headset-mic.service"
VENDOR_ID="0x10ec0235"
SUBSYSTEM_ID="0x10251085"
RECORD=0
FAILS=0

ok()   { printf '[ok]    %s\n' "$*"; }
warn() { printf '[aviso] %s\n' "$*"; }
fail() { printf '[falha] %s\n' "$*"; FAILS=$((FAILS + 1)); }

usage() {
    cat <<'EOF'
Uso: ./check.sh [--record]

Opcoes:
  --record   Grava 5 segundos da entrada padrao e mede o nivel (requer
             parecord/arecord; a medicao usa ffmpeg se estiver instalado).
  -h, --help Mostrar esta ajuda.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --record) RECORD=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Opcao desconhecida: %s (use --help)\n' "$arg" >&2; exit 2 ;;
    esac
done

printf '== Verificacao do microfone de headset (Acer Aspire ES1-572) ==\n\n'

# 1. Codec esperado
CODEC_FILE=""
for f in /proc/asound/card*/codec#*; do
    [ -e "$f" ] || continue
    if grep -q "Vendor Id: $VENDOR_ID" "$f" 2>/dev/null &&
       grep -q "Subsystem Id: $SUBSYSTEM_ID" "$f" 2>/dev/null; then
        CODEC_FILE="$f"
        break
    fi
done
if [ -n "$CODEC_FILE" ]; then
    ok "Codec ALC233 (SSID 1025:1085) encontrado em $CODEC_FILE."
else
    fail "Codec ALC233 com SSID 1025:1085 nao encontrado. Este fix nao se aplica a este hardware."
fi

# 2. Fixup do driver neste boot
KLOG="$(journalctl -k -b --no-pager 2>/dev/null || dmesg 2>/dev/null || true)"
case "$KLOG" in
    *"picked fixup alc233-asus"*)
        ok "Driver aplicou o fixup alc233-asus neste boot."
        ;;
    *)
        fail "Fixup alc233-asus nao aparece no log do kernel. Confira /etc/modprobe.d/99-acer-es1-572-headset.conf e reinicie."
        ;;
esac

# 3. Servico systemd
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    ok "Servico habilitado no boot."
else
    fail "Servico nao esta habilitado: sudo systemctl enable $SERVICE_NAME"
fi

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    ok "Servico ativo (coeficiente aplicado)."
else
    fail "Servico inativo. Veja: systemctl status $SERVICE_NAME"
fi

# 4. Portas no PipeWire/PulseAudio
if command -v pactl >/dev/null 2>&1; then
    SOURCES="$(LC_ALL=C pactl list sources 2>/dev/null || true)"
    if grep -q 'analog-input-headset-mic' <<<"$SOURCES"; then
        ok "Porta analog-input-headset-mic existe."
    else
        fail "Porta analog-input-headset-mic nao existe."
    fi

    if grep -q 'Active Port: analog-input-headset-mic' <<<"$SOURCES"; then
        ok "Porta do microfone de headset esta ativa."
    else
        fail "Porta do headset nao esta ativa. Plugue o headset e, em Som > Entrada, escolha \"Microfone de headset\"."
    fi
else
    warn "pactl nao encontrado; nao foi possivel checar as portas."
fi

# 5. Entrada selecionada no ALSA
if command -v amixer >/dev/null 2>&1; then
    INPUT_SRC="$(LC_ALL=C amixer -c 0 sget 'Input Source' 2>/dev/null || true)"
    if grep -q "Item0: 'Headset Mic'" <<<"$INPUT_SRC"; then
        ok "Entrada ALSA selecionada: Headset Mic."
    else
        fail "Input Source do ALSA nao esta em Headset Mic. Plugue o headset e selecione a entrada."
    fi
else
    warn "amixer nao encontrado (pacote alsa-utils)."
fi

# 6. Teste de gravacao opcional
if [ "$RECORD" -eq 1 ]; then
    OUT="${TMPDIR:-/tmp}/acer-headset-mic-test.wav"
    printf '\nGravando 5 segundos em %s\nFale algo em voz normal...\n' "$OUT"

    if command -v parecord >/dev/null 2>&1; then
        timeout -s INT 5 parecord --channels=1 --rate=48000 --format=s16le \
            --file-format=wav "$OUT" || true
    elif command -v arecord >/dev/null 2>&1; then
        timeout -s INT 5 arecord -q -f S16_LE -r 48000 -c 1 "$OUT" || true
    else
        fail "Nem parecord nem arecord encontrados."
    fi

    if [ -s "$OUT" ]; then
        if command -v ffmpeg >/dev/null 2>&1; then
            MAX="$(ffmpeg -hide_banner -i "$OUT" -af volumedetect -f null - 2>&1 |
                   sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p' | tail -n 1)"
            if [ -n "$MAX" ] && awk -v m="$MAX" 'BEGIN { exit !(m > -40) }'; then
                ok "Gravacao captou audio (pico: ${MAX} dB). Arquivo: $OUT"
            else
                fail "Gravacao praticamente muda (pico: ${MAX:-?} dB). Arquivo: $OUT"
            fi
        else
            warn "ffmpeg nao encontrado; ouça a gravacao em $OUT."
        fi
    else
        fail "A gravacao nao foi criada ou esta vazia."
    fi
fi

printf '\n'
if [ "$FAILS" -eq 0 ]; then
    printf 'Tudo certo: nenhuma falha encontrada.\n'
    exit 0
fi
printf '%d falha(s) encontrada(s). Veja docs/troubleshooting.md.\n' "$FAILS"
exit 1
