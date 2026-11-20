# Hardware testado

| Item | Valor |
|---|---|
| Modelo | Acer Aspire ES1-572 |
| Placa-mãe | `T-Rex_SK` |
| BIOS | V1.09 (04/12/2016) |
| Codec | Realtek ALC233 |
| Vendor ID | `0x10ec0235` |
| Subsystem ID | `0x10251085` |
| Jack | combo P3 TRRS (4 polos) |
| Distribuição | Linux Mint 22.3 |
| Kernel | `7.0.0-43-generic` |
| PipeWire | 1.0.5 |
| alsa-tools | 1.2.11 |

## Mapa de pinos do ALC233

| NID | Função | Pin Default |
|---|---|---|
| `0x14` | saída de alto-falantes | line out |
| `0x19` | microfone do headset (desabilitado pelo BIOS) | `0x411111f0` |
| `0x1a` | segundo microfone externo (desabilitado) | `0x411111f0` |
| `0x1b` | microfone interno | `0x90a70120` |
| `0x21` | saída de fone | `0x0321101f` |
| `0x20` | widget de processamento (coeficientes vendor) | — |

## O que foi validado

- Microfone do headset: captação confirmada após reboot, sem comandos manuais
  (média `-21,7 dB`, pico `0,0 dB`).
- Porta do microfone interno: continua disponível para seleção.
- Serviço systemd: `active (exited)`, com os dois `hda-verb` retornando
  `status=0/SUCCESS`.
- Hook de suspensão: implementado, mas **não testado** neste hardware até a
  publicação desta versão.

## Não validado

- Outras revisões de BIOS/modelo ES1-572.
- Outros codecs ALC233 com SSID diferente.
- Áudio HDMI (fora do escopo).
