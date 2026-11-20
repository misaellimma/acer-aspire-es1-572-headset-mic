# Troubleshooting

## A porta "Microfone de headset" não aparece

1. Confirme o arquivo e o boot:

```bash
cat /etc/modprobe.d/99-acer-es1-572-headset.conf
sudo dmesg | grep -i 'picked fixup alc233-asus'
```

2. Se a linha não aparecer, reinicie. O parâmetro não é aplicado a quente.
3. Confirme com qual modelo o módulo está carregado:

```bash
cat /sys/module/snd_hda_intel/parameters/model
```

4. Se você usa outro kernel e o fixup `alc233-asus` não existir, veja o
   fallback com HDAJackRetask abaixo.

## A porta aparece, mas a gravação fica muda

1. Veja o serviço:

```bash
systemctl status acer-alc233-headset-mic.service
journalctl -u acer-alc233-headset-mic.service -b
```

2. Aplique o coeficiente manualmente e grave de novo:

```bash
sudo hda-verb /dev/snd/hwC0D0 0x20 SET_COEF_INDEX 0x45
sudo hda-verb /dev/snd/hwC0D0 0x20 SET_PROC_COEF 0x5089
./check.sh --record
```

3. Confirme a entrada selecionada:

```bash
LC_ALL=C amixer -c0 sget 'Input Source'
LC_ALL=C pactl list sources | grep -E 'analog-input|Active Port'
```

4. Verifique se a captura não está mutada ou em volume zero:

```bash
alsamixer -c0
```

Pressione `F4` para ver os controles de captura, selecione `Headset Mic` com
`F4`/setas e aumente o `Capture`. O `Headset Mic` de playback em `0% [off]` é
apenas monitoramento e não impede a captação.

## O serviço falha no boot

Sintoma no `journalctl`:

```text
hda-verb[...]: open: No such file or directory
```

Causa: o serviço rodou antes de `/dev/snd/hwC0D0` existir. A versão deste repo
já tem um `ExecStartPre` que espera até 30 s. Se ainda falhar:

```bash
systemctl status acer-alc233-headset-mic.service --no-pager
journalctl -u acer-alc233-headset-mic.service -b --no-pager
```

Se o codec estiver em outra placa (por exemplo `hwC1D0`):

```bash
ls /dev/snd/hwC*
```

Ajuste `ExecStartPre`, `ExecStart` e o hook de sleep para o caminho correto.

## A voz distorce ou fica muito alta

O `Headset Mic Boost` vem no máximo (30 dB). Reduza:

```bash
sudo amixer -c0 sset 'Headset Mic Boost' 2
```

Se necessário, reduza também o `Capture`:

```bash
alsamixer -c0
```

## O som do fone/alto-falantes parou de funcionar

O fix mexe no mapeamento do jack. Confira as saídas:

```bash
LC_ALL=C pactl list sinks | grep -E 'Name:|Active Port'
```

Se necessário, selecione a saída correta em **Som** → **Saída**. Para reverter
tudo:

```bash
sudo ./uninstall.sh --restore
sudo reboot
```

## Atualizei o kernel e parou de funcionar

O coeficiente é específico do codec, não do kernel, mas o fixup `alc233-asus`
pode mudar entre versões. Rode `./check.sh` e confira:

```bash
sudo dmesg | grep -i alc233
```

Se o fixup não aparecer, abra uma issue com a saída do check e a versão do
kernel.

## Fallback: HDAJackRetask

Se o `model=alc233-asus` não funcionar no seu kernel/versão, é possível forçar
o pino manualmente:

```bash
sudo apt install alsa-tools-gui
hda-jack-retask
```

- Marque `Show unconnected pins`.
- No pino `0x19`, escolha `Microphone` (ou `Headset Mic`, se disponível).
- Em `0x1a`, tente o mesmo se necessário.
- Aplique e teste; se funcionar, use `Install boot override`.

O coeficiente `0x45=0x5089` ainda pode ser necessário. Nesse caso, mantenha o
serviço deste repositório.

## Fallback: adaptador USB

A solução mais simples e independente do notebook é um adaptador USB de áudio
com entrada de microfone (ou um headset USB). O Linux reconhece como placa
separada e não depende do codec ALC233.

## Ainda não funcionou?

Rode:

```bash
./check.sh > /tmp/check-audio.txt 2>&1
```

E abra uma issue com o arquivo, o modelo do notebook e a versão do kernel.
