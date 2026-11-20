# Solução

A correção tem duas partes independentes:

1. `model=alc233-asus` — faz o driver reconhecer o jack combo como headset.
2. Coeficiente `0x45=0x5089` — faz o sinal do microfone chegar ao ADC.

## 1. Fixup do driver

Arquivo `/etc/modprobe.d/99-acer-es1-572-headset.conf`:

```ini
options snd-hda-intel model=alc233-asus
```

O parâmetro `model` seleciona um *fixup* da tabela do kernel
(`sound/pci/hda/patch_realtek.c`) para o ALC233 de notebooks Asus/Acer. Esse
fixup:

- reconfigura o NID `0x19` como microfone de headset;
- cria a porta `analog-input-headset-mic` no PipeWire/PulseAudio;
- habilita a detecção de jack (plug/unplug).

No boot, o log confirma:

```text
snd_hda_codec_alc269 hdaudioC0D0: ALC233: picked fixup alc233-asus (model specified)
```

O parâmetro só vale para o próximo boot depois de gravado em
`/etc/modprobe.d/`; por isso o instalador pede para reiniciar.

## 2. Coeficiente de vendor

O widget `0x20` do ALC233 é um nó de processamento com coeficientes vendor.
O coeficiente `0x45` controla o roteamento analógico do microfone. O valor
esperado neste notebook é `0x5089`.

Aplicação manual:

```bash
sudo hda-verb /dev/snd/hwC0D0 0x20 SET_COEF_INDEX 0x45
sudo hda-verb /dev/snd/hwC0D0 0x20 SET_PROC_COEF 0x5089
```

Em ambos os comandos o `hda-verb` imprime `value = 0x0`, que é o retorno
esperado.

## Persistência

O coeficiente é volátil: some no reboot e após suspensão. Por isso:

- **No boot:** `acer-alc233-headset-mic.service` (oneshot) espera
  `/dev/snd/hwC0D0` existir e aplica os dois `hda-verb`.
- **Após suspender:** `/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh`
  roda no evento `post` e reaplica.

O `ExecStartPre` existe porque, no boot, o serviço pode ser iniciado antes de
o device node do codec aparecer. Sem a espera, o `hda-verb` falha com
`open: No such file or directory`.

## Por que `/dev/snd/hwC0D0`

Neste notebook o ALC233 é a placa 0 (`card0`) e o codec 0 (`codec#0`), então o
device de controle HDA é `/dev/snd/hwC0D0`. Se você adicionar uma placa USB que
passe a ser a `card0`, o caminho pode mudar; nesse caso ajuste o serviço e o
hook.

## Ordem de aplicação

1. O BIOS liga o notebook e o `snd-hda-intel` carrega com `model=alc233-asus`.
2. O driver cria a porta de microfone de headset.
3. O systemd inicia o serviço e aplica o coeficiente.
4. O PipeWire/WirePlumber expõe a fonte e a porta.
