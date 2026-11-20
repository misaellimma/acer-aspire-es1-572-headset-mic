# Diagnóstico

## Sintoma

- O fone do headset funciona.
- O microfone do headset não aparece nas entradas ou aparece mudo.
- O mesmo headset funciona no Windows, no mesmo notebook.

## O que o codec mostra

O ALC233 deste notebook tem os pinos externos de microfone desabilitados por
padrão pelo BIOS:

```text
Node 0x19 [Pin Complex] wcaps 0x40048b: Stereo Amp-In   (headset mic externo)
  Pin Default 0x411111f0: [N/A] Speaker at Ext Rear
    Misc = NO_PRESENCE

Node 0x1a [Pin Complex] wcaps 0x40048b: Stereo Amp-In   (segundo mic externo)
  Pin Default 0x411111f0: [N/A] Speaker at Ext Rear
    Misc = NO_PRESENCE

Node 0x1b [Pin Complex] wcaps 0x40058f: Stereo Amp-In Amp-Out   (mic interno)
  Pin Default 0x90a70120: [Fixed] Mic at Int N/A

Node 0x21 [Pin Complex] wcaps 0x40058d: Stereo Amp-Out   (saída de fone)
  Pin Default 0x0321101f: [Jack] HP Out at Ext Left
```

`0x411111f0` significa "não aplicável, sem presença": o BIOS não declara o jack
como microfone. Sem um fixup, o driver `snd-hda-intel` não cria a entrada de
captação para o headset.

## Como confirmar

```bash
grep -E 'Codec:|Vendor Id|Subsystem Id' /proc/asound/card*/codec#*
```

Esperado: `Realtek ALC233`, `0x10ec0235`, `0x10251085`.

```bash
sudo dmesg | grep -i alc233
```

Sem a correção, não aparece a linha:

```text
snd_hda_codec_alc269 hdaudioC0D0: ALC233: picked fixup alc233-asus (model specified)
```

E o `pactl` não lista `analog-input-headset-mic`:

```bash
LC_ALL=C pactl list sources | grep -E 'analog-input|Active Port'
```

## O que o Windows faz diferente

O driver da Realtek no Windows aplica uma sequência de coeficientes de vendor
no codec (widget `0x20`) que o Linux, por padrão, não conhece. Um deles é o
coeficiente `0x45`, que precisa valer `0x5089` para o sinal do microfone do
headset chegar ao ADC. Sem isso, a porta pode até existir, mas a gravação fica
muda.

## Evidência medida neste notebook

| Estado | Resultado da gravação |
|---|---|
| Porta criada, sem coeficiente | pico ~ `-52 dB` (silêncio) |
| Com `model=alc233-asus` + coeficiente | média `-21,7 dB`, pico `0,0 dB` |

Os dumps completos estão em
[`../samples/codec-antes.txt`](../samples/codec-antes.txt) e
[`../samples/codec-depois.txt`](../samples/codec-depois.txt).

> O `Pin Default` do pino `0x19` continua mostrando `0x411111f0` no
> `/proc/asound/card0/codec#0` mesmo depois da correção. Isso é normal: o
> fixup do driver sobrescreve a configuração em memória, mas não reescreve o
> valor do BIOS exibido no proc. O que importa é a porta "Microfone de
> headset" existir e captar.
