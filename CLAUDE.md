# RSVP Reader

Leitor de EPUB para Android/iOS em Flutter com RSVP (Rapid Serial Visual Presentation).

## Comandos

```bash
flutter pub get                                    # instalar deps
dart run build_runner build --delete-conflicting-outputs  # gerar codigo (drift, freezed)
flutter gen-l10n                                   # gerar strings i18n
flutter analyze                                    # verificar erros
flutter test test/                                 # rodar testes (requer lld instalado)
flutter run                                        # rodar no device/emulador
```

## Arquitetura

Feature-based Clean Architecture com Riverpod. Ver [docs/architecture.md](docs/architecture.md).

**Stack:** Flutter 3.x | Riverpod 2 (sem codegen) | Drift/SQLite | SharedPreferences | epub_pro | go_router

## Estrutura de pastas

```
lib/
  core/         # theme, routing, utils (orp_calculator, word_timing, html_stripper, text_tokenizer), constants, DI
  database/     # Drift: app_database, tables/ (books, reading_progress, cached_tokens), daos/
  features/
    book_library/   # tela principal, grid de livros, import
    epub_import/    # parsing EPUB -> WordToken, cache de tokens no DB
    rsvp_reader/    # motor RSVP (Ticker), display RSVP, modo scroll, controles, settings do leitor
    settings/       # tela de configuracoes globais
  l10n/         # ARB files (en, pt) + generated/
```

## Conceitos-chave

- **WordToken**: unidade fundamental — cada palavra do livro pre-processada com ORP index e timing multiplier no momento do import. O motor RSVP nao faz nenhum calculo no hot loop.
- **ORP (Optimal Recognition Point)**: letra de foco a ~30% da palavra, destacada em vermelho. Ver [docs/rsvp-engine.md](docs/rsvp-engine.md).
- **Tres modos de leitura** (`ReaderMode`):
  - `rsvp`: palavra unica com ORP — ativo durante play
  - `scroll`: texto completo com highlight da palavra atual — pausado, com controles
  - `ereader`: texto completo sem highlight, sem controles — leitura tradicional
  - Toggle entre rsvp/scroll e ereader via icone no top bar; dentro de rsvp/scroll, play/pause alterna entre eles.
- **DisplaySettings**: todas as configs visuais e de leitura (cores, fontes, posicoes, toggles, focus line) persistidas via SharedPreferences. Painel unico (`DisplaySettingsPanel`) usado tanto no bottom sheet do leitor quanto na tela full-screen de Settings — fonte unica de verdade para adicionar opcoes.

## Regras

- Todas as strings de UI devem usar i18n (ARB files em `lib/l10n/`). Nunca hardcodar texto PT ou EN.
- Cores e tamanhos no leitor (e nas telas de settings) vem de `DisplaySettings`, nunca de constantes do theme — telas de configuracao usam as cores escolhidas pelo usuario para preview "ao vivo".
- Para adicionar/remover uma opcao de display ou leitura: editar `display_settings_panel.dart` (afeta automaticamente o bottom sheet no leitor E a tela full-screen de settings). Adicionar tambem o campo em `DisplaySettings` + `copyWith` + load/save no `DisplaySettingsNotifier`.
- Apos alterar tables do Drift ou classes com `@freezed`: rodar `build_runner`.
- Apos alterar ARB files: rodar `flutter gen-l10n` (l10n.yaml ja configurado).
- Testes unitarios dos core utils sao prioridade (ORP, timing, tokenizer, HTML stripper). HTML stripper deve cobrir tags `_skipTags` para evitar regressao de CSS/JS vazando no texto.

## Docs detalhados

- [docs/architecture.md](docs/architecture.md) — arquitetura, fluxo de dados, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md) — motor RSVP, ORP, timing, ramp-up
- [docs/tasks.md](tasks.md) — bugs e features pendentes
