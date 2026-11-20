# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.
O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o projeto usa [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2026-11-20

### Adicionado

- Fix do microfone de headset (P3 TRRS) para o Acer Aspire ES1-572 com
  Realtek ALC233 (SSID `1025:1085`).
- `install.sh`, `uninstall.sh` e `check.sh` com backup e rollback.
- Serviço systemd que aplica o coeficiente `0x45=0x5089` no boot,
  aguardando o device node `/dev/snd/hwC0D0`.
- Hook de `systemd-sleep` que reaplica o coeficiente após suspensão.
- Documentação de diagnóstico, solução, troubleshooting e hardware.
- Dumps sanitizados do codec antes e depois da correção.

### Testado em

- Linux Mint 22.3
- Kernel `7.0.0-43-generic`
- PipeWire 1.0.5
- alsa-tools 1.2.11
