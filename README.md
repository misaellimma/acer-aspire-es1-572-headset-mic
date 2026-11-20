# Microfone de headset no Acer Aspire ES1-572 (Linux)

Correção para o **microfone do headset P3 combo (TRRS, 4 polos)** não funcionar
no **Acer Aspire ES1-572** com **Realtek ALC233** no Linux.

O áudio do fone funciona, mas o microfone não aparece nas entradas ou aparece
mudo. No Windows o mesmo headset funciona, porque o driver da Realtek aplica
ajustes de vendor que o Linux não aplica sozinho.

> **TL;DR (English):** fixes the combo-jack headset microphone on the Acer
> Aspire ES1-572 (Realtek ALC233, SSID `1025:1085`). Tested on Linux Mint 22.3,
> kernel `7.0.0-43-generic`. Run `sudo ./install.sh` and reboot.

## Compatibilidade

| Item | Valor |
|---|---|
| Notebook | Acer Aspire ES1-572 |
| Placa-mãe | `T-Rex_SK`, BIOS V1.09 (04/12/2016) |
| Codec | Realtek ALC233 (`10ec0235`) |
| SSID | `1025:1085` |
| Sistemas testados | Linux Mint 22.3 (base Ubuntu 24.04) |
| Kernel testado | `7.0.0-43-generic` |
| Áudio | PipeWire 1.0.5 / WirePlumber |

> Este repositório é específico para **este modelo**. Em outro Acer com ALC233,
> o pino ou o coeficiente podem ser diferentes. Veja
> [`docs/troubleshooting.md`](docs/troubleshooting.md) antes de adaptar.

## Instalação

```bash
git clone https://github.com/misaellimma/acer-aspire-es1-572-headset-mic.git
cd acer-aspire-es1-572-headset-mic
less install.sh          # vale a pena ler antes de rodar como root
sudo ./install.sh
sudo reboot
```

O instalador:

- confere se o codec é o ALC233 com SSID `1025:1085`;
- instala o `alsa-tools` (fornece o `hda-verb`) se necessário;
- faz backup dos arquivos existentes em `/var/backups/acer-alc233-headset-mic/`;
- copia a configuração e habilita o serviço no boot;
- atualiza o initramfs;
- **não reinicia** sozinho.

## Como testar

1. Plugue o headset no jack combo.
2. Abra **Som** → **Entrada** e escolha **Microfone de headset**.
3. Rode:

```bash
./check.sh
./check.sh --record
```

O primeiro comando verifica codec, driver, serviço e portas. O segundo grava
5 segundos da entrada padrão e mede o nível com o `ffmpeg` (se instalado),
salvando o teste em `/tmp/acer-headset-mic-test.wav`.

Teste manual equivalente:

```bash
timeout -s INT 8s parecord --channels=1 --rate=48000 --format=s16le \
  --file-format=wav /tmp/teste-mic.wav
ffmpeg -hide_banner -i /tmp/teste-mic.wav -af volumedetect -f null -
```

Um microfone funcionando costuma dar pico acima de `-20 dB`. Sem a correção,
o pico fica perto de `-50 dB` (silêncio).

## O que é alterado

| Arquivo | Função |
|---|---|
| `/etc/modprobe.d/99-acer-es1-572-headset.conf` | aplica `model=alc233-asus`, que reativa o pino `0x19` como microfone de headset |
| `/etc/systemd/system/acer-alc233-headset-mic.service` | aplica o coeficiente `0x45=0x5089` no widget `0x20` no boot |
| `/usr/lib/systemd/system-sleep/acer-alc233-headset-mic.sh` | reaplica o coeficiente após suspensão/hibernação |

O serviço espera até 30 s por `/dev/snd/hwC0D0`, porque no boot ele pode
iniciar antes de o device node do codec existir.

## Se não funcionar

- Confira se o headset é **TRRS de 4 polos** (P3 com microfone). Headsets de
  3 polos não têm microfone.
- Veja [`docs/troubleshooting.md`](docs/troubleshooting.md) para os casos:
  porta não aparece, porta muda, serviço falha no boot, distorção e fallback
  com HDAJackRetask ou adaptador USB.
- Rode `./check.sh` e abra uma issue com a saída.

## Desinstalar

```bash
sudo ./uninstall.sh            # remove a correção
sudo ./uninstall.sh --restore  # remove e restaura o backup mais recente
sudo reboot
```

## Documentação

- [`docs/diagnostico.md`](docs/diagnostico.md) — por que o pino fica desligado.
- [`docs/solucao.md`](docs/solucao.md) — o que o `model` e o coeficiente fazem.
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — problemas comuns.
- [`docs/hardware.md`](docs/hardware.md) — detalhes do hardware testado.
- [`samples/`](samples/) — dumps do codec antes e depois.

## Licença

MIT. Veja [LICENSE](LICENSE).

Este projeto não tem relação com a Acer ou a Realtek. Use por sua conta e risco.
