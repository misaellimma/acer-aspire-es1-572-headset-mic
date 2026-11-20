#!/bin/sh
# Reaplica o coeficiente do microfone de headset ALC233 (Acer ES1-572)
# apos o retorno da suspensao/hibernacao.
#
# O kernel recebe os argumentos: $1 = pre|post e $2 = suspend|hibernate|...

[ "$1" = "post" ] || exit 0

i=0
while [ "$i" -lt 10 ]; do
    [ -e /dev/snd/hwC0D0 ] && break
    i=$((i + 1))
    sleep 1
done

[ -e /dev/snd/hwC0D0 ] || exit 0

sleep 1
/usr/bin/hda-verb /dev/snd/hwC0D0 0x20 SET_COEF_INDEX 0x45
/usr/bin/hda-verb /dev/snd/hwC0D0 0x20 SET_PROC_COEF 0x5089

exit 0
