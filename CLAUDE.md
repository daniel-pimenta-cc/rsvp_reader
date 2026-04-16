# RSVP Reader

Leitor de livros (EPUB) e artigos web em Flutter com RSVP (Rapid Serial Visual Presentation), para Android/iOS.

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

**Stack:** Flutter 3.x | Riverpod 2 (sem codegen) | Drift/SQLite | SharedPreferences | epub_pro | go_router | http | receive_sharing_intent

## Estrutura de pastas

```
lib/
  core/
    theme/        # app_colors (paleta dual light+dark), app_theme (brightness-aware),
                  # app_spacing, app_radius, app_elevations, app_motion,
                  # app_typography (Lora serif + Inter sans), responsive (breakpoints)
    routing/      # app_router, selected_book_provider (master-detail)
    constants/    # app_constants, responsive_defaults (font scale por device)
    widgets/      # section_card, skeleton_loader (reusáveis globais)
    di/
    utils/        # orp_calculator, word_timing, html_stripper, text_tokenizer,
                  # readability_extractor, url_utils, sync_file_name
    share/        # share_intent_handler (Android share target)
  database/       # Drift: app_database, tables/ (books, reading_progress,
                  # cached_tokens, sync_import_failures, book_source constants), daos/
  features/
    book_library/    # tela principal com tabs Books/Articles, grid, import, actions
    epub_import/     # parsing EPUB -> WordToken, cache de tokens no DB
    article_import/  # fetch URL -> readability -> WordToken, cache de tokens no DB
    library_sync/    # sync de biblioteca (EPUB) para pasta escolhida pelo usuario
    rsvp_reader/     # motor RSVP (Ticker), display RSVP, modo scroll, controles, settings do leitor
    settings/        # tela de configuracoes globais
  l10n/         # ARB files (en, pt) + generated/
```

## Conceitos-chave

- **WordToken**: unidade fundamental — cada palavra pre-processada com ORP index e timing multiplier no momento do import. O motor RSVP nao faz nenhum calculo no hot loop.
- **ORP (Optimal Recognition Point)**: letra de foco a ~30% da palavra, destacada em vermelho. Ver [docs/rsvp-engine.md](docs/rsvp-engine.md).
- **Duas fontes de conteudo, uma pipeline** (`BookSource`):
  - `epub`: arquivo EPUB importado (file picker ou sync folder).
  - `article`: artigo web importado por URL (dialog manual ou share sheet).
  - Ambos viram `ParsedBook` -> `persistParsedBook` -> `books` + `cached_tokens`. Leitura, progresso e engine RSVP sao identicos. Ver [docs/article-import.md](docs/article-import.md).
- **Tres modos de leitura** (`ReaderMode`):
  - `rsvp`: palavra unica com ORP — ativo durante play
  - `scroll`: texto completo com highlight da palavra atual — pausado, com controles
  - `ereader`: texto completo sem highlight, sem controles — leitura tradicional
  - Toggle entre rsvp/scroll e ereader via icone no top bar; dentro de rsvp/scroll, play/pause alterna entre eles.
- **DisplaySettings**: todas as configs visuais e de leitura (cores, fontes, posicoes, toggles, focus line) persistidas via SharedPreferences. Painel unico (`DisplaySettingsPanel`) usado tanto no bottom sheet do leitor quanto na tela full-screen de Settings — fonte unica de verdade para adicionar opcoes.
- **Biblioteca com tabs**: `LibraryScreen` separa "Livros" (source=epub) de "Artigos" (source=article) via `TabBar`. O FAB muda de acao conforme a tab ativa.
- **Tema light + dark** com accent laranja #E55324 preservado: paleta editorial ("ink on paper" / "paper"). Toggle em Settings (system/light/dark), persistido via `themeModeProvider`. Tipografia: Lora (serif) em títulos, Inter (sans) em body. Tokens em `lib/core/theme/` (spacing/radius/elevations/motion).
- **Responsivo + master-detail**: breakpoints em `lib/core/theme/responsive.dart` (compact <600 / medium 600-840 / expanded >840). Grid adaptativo 2/3/4 colunas. Em tablet landscape, `LibraryScreen` renderiza split-view: lista à esquerda (440px) + reader/placeholder à direita — `selectedBookIdProvider` controla qual livro está aberto sem trocar rota. Settings e chapter list do reader viram painel lateral (`ReaderSidePanel`) em tablet landscape; bottom sheet em mobile/portrait.

## Regras

- Todas as strings de UI devem usar i18n (ARB files em `lib/l10n/`). Nunca hardcodar texto PT ou EN.
- Cores e tamanhos no leitor (e nas telas de settings) vem de `DisplaySettings`, nunca de constantes do theme — telas de configuracao usam as cores escolhidas pelo usuario para preview "ao vivo".
- Para adicionar/remover uma opcao de display ou leitura: editar `display_settings_panel.dart` (afeta automaticamente o bottom sheet no leitor E a tela full-screen de settings). Adicionar tambem o campo em `DisplaySettings` + `copyWith` + load/save no `DisplaySettingsNotifier`.
- Apos alterar tables do Drift ou classes com `@freezed`: rodar `build_runner`.
- Apos alterar ARB files: rodar `flutter gen-l10n` (l10n.yaml ja configurado).
- **Persistir livros/artigos**: sempre via `persistParsedBook` (em `lib/features/book_library/data/services/book_persistence.dart`). Nunca duplicar o fluxo insert-book + fan-out de tokens.
- **Comparar `source`**: usar as constantes de `BookSource` (`lib/database/tables/book_source.dart`), nunca literais `'epub'`/`'article'`.
- **URLs**: usar `UrlUtils.extractHttpUrl` / `parseWithHttpsFallback` em `lib/core/utils/url_utils.dart` — nao reimplementar parsing ad-hoc.
- **Sync de biblioteca so inclui EPUB**: `LibrarySyncService` filtra `source=='epub'`. Artigos sao sempre locais (manifesto de sync e formato EPUB).
- Testes unitarios dos core utils sao prioridade (ORP, timing, tokenizer, HTML stripper, readability). HTML stripper deve cobrir tags `_skipTags` para evitar regressao de CSS/JS vazando no texto.

## Docs detalhados

- [docs/architecture.md](docs/architecture.md) — arquitetura, fluxo de dados, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md) — motor RSVP, ORP, timing, ramp-up
- [docs/article-import.md](docs/article-import.md) — pipeline de artigos web, readability, share sheet
- [docs/share-extension-ios.md](docs/share-extension-ios.md) — setup do share extension iOS (Xcode)
- [tasks.md](tasks.md) — bugs e features pendentes
