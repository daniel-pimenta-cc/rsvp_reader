# RSVP Reader

Leitor de livros (EPUB) e artigos web em Flutter com RSVP (Rapid Serial Visual Presentation), para Android/iOS/tablet.

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

**Stack:** Flutter 3.x | Riverpod 2 (sem codegen) | Drift/SQLite | SharedPreferences | epub_pro | go_router | http | receive_sharing_intent | google_sign_in + googleapis (Drive v3) | google_fonts (Lora + Inter)

## Estrutura de pastas

```
lib/
  core/
    theme/        # design system editorial
      app_colors    — AppPalette dual (light/dark), AppColors (back-compat)
      app_theme     — AppTheme.build(brightness:) com 14+ component themes
      app_typography — Lora (serif headlines) + Inter (sans body) + tabular figures
      app_spacing   — escala 4/8/12/16/24/32/48
      app_radius    — sm(6)/md(10)/lg(16)/xl(24) + BorderRadius helpers
      app_elevations — BoxShadow por brightness (level1..4)
      app_motion    — duracoes (fast/base/slow/page) + curvas (standard/emphasized/decelerate)
      responsive    — Breakpoints (compact/medium/expanded), DeviceType enum,
                      extensions context.isTablet/isLandscape/deviceType,
                      gridCrossAxisCount(), gridAspectRatio()
    routing/      # app_router (go_router), selected_book_provider (master-detail)
    constants/    # app_constants, responsive_defaults (font scale + margins por device)
    widgets/      # section_card, skeleton_loader (shimmer com AnimationController compartilhado)
    utils/        # orp_calculator, word_timing, html_stripper, text_tokenizer,
                  # readability_extractor, url_utils, sync_file_name, font_mapper
    di/           # provider overrides (appDatabaseProvider etc.)
    share/        # share_intent_handler (Android share target)
  database/       # Drift: app_database, tables/ (books, reading_progress,
                  # cached_tokens, sync_import_failures, book_source constants), daos/
  features/
    book_library/
      presentation/
        screens/    library_screen (master-detail host, tabs, listeners)
        widgets/    book_card, library_list, library_fab, library_appbar_bottom,
                    library_skeleton, library_empty_state, library_section_header,
                    reading_progress_bar, reader_placeholder
        providers/  book_library_provider (categorized stream)
      data/         book_persistence (persistParsedBook)
    epub_import/     # parsing EPUB -> WordToken, cache de tokens no DB
    article_import/  # fetch URL -> readability -> WordToken, cache de tokens no DB
    library_sync/    # sync de biblioteca (EPUB) + progresso + settings via Google Drive
                     # (drive.file scope, pasta "RSVP Reader" no Drive do usuario)
    rsvp_reader/
      domain/entities/  rsvp_state, display_settings, word_token, chapter
      presentation/
        screens/    rsvp_reader_screen (modes, top bar, side panel host)
        widgets/    rsvp_word_display, context_scroll_view,
                    rsvp_controls (dock compositor),
                    controls_shell, controls_meta_row, controls_progress_row,
                    controls_transport_row, seek_slider,
                    wpm_selector (capsule + preset drawer compartilhado),
                    display_settings_panel + display_settings_widgets (part),
                    reader_settings_sheet, chapter_list_sheet, reader_side_panel
        providers/  rsvp_engine_provider, display_settings_provider,
                    reader_side_panel_provider
    settings/
      presentation/
        screens/    settings_screen (Appearance + DisplaySettingsPanel + Sync + About)
        providers/  theme_mode_provider (system/light/dark, persiste + inverte cores)
  l10n/         # ARB files (en, pt) + generated/
```

## Conceitos-chave

- **WordToken**: unidade fundamental — cada palavra pre-processada com ORP index e timing multiplier no momento do import. O motor RSVP nao faz nenhum calculo no hot loop.
- **ORP (Optimal Recognition Point)**: letra de foco a ~30% da palavra, destacada em cor accent. Ver [docs/rsvp-engine.md](docs/rsvp-engine.md).
- **Duas fontes de conteudo, uma pipeline** (`BookSource`):
  - `epub`: arquivo EPUB importado (file picker ou Drive sync).
  - `article`: artigo web importado por URL (dialog manual ou share sheet).
  - Ambos viram `ParsedBook` -> `persistParsedBook` -> `books` + `cached_tokens`. Leitura, progresso e engine RSVP sao identicos. Ver [docs/article-import.md](docs/article-import.md).
- **Tres modos de leitura** (`ReaderMode`):
  - `rsvp`: palavra unica com ORP — ativo durante play
  - `scroll`: texto completo com highlight da palavra atual — pausado, com controles
  - `ereader`: texto completo sem highlight, sem controles — leitura tradicional
  - Toggle entre rsvp/scroll e ereader via icone no top bar; dentro de rsvp/scroll, play/pause alterna entre eles.
- **DisplaySettings**: todas as configs visuais e de leitura (cores, fontes, posicoes, toggles, focus line) persistidas via SharedPreferences. Painel unico (`DisplaySettingsPanel`) usado tanto no bottom sheet do leitor quanto na tela full-screen de Settings — fonte unica de verdade para adicionar opcoes.
- **Tema light + dark**: paleta editorial com tons quentes ("ink on paper" / "paper"), accent laranja #E55324 preservado em ambos. Toggle em Settings via `SegmentedButton` (system/light/dark), persistido em `themeModeProvider`. Ao trocar de brightness, `ThemeModeNotifier` chama `DisplaySettingsNotifier.applyBrightness()` que inverte automaticamente wordColor e backgroundColor para a paleta correspondente — ORP e highlight ficam preservados.
- **Tipografia editorial**: Lora (serif) em display/headline/title; Inter (sans) em body/label. Font families para RSVP incluem monos (Roboto Mono, JetBrains Mono, Fira Code, Source Code Pro) + serifs (Lora, Source Serif 4). Mapeamento centralizado em `lib/core/utils/font_mapper.dart`.
- **Responsivo + master-detail**: breakpoints em `responsive.dart` (compact <600 / medium 600-840 / expanded >840). Grid adaptativo 2/3/4 colunas. Em tablet landscape, `LibraryScreen` renderiza split-view: lista a esquerda (440px) + reader/placeholder a direita — `selectedBookIdProvider` controla qual livro esta aberto sem trocar rota. Settings e chapter list do reader viram painel lateral (`ReaderSidePanel` + `readerSidePanelProvider`) em tablet landscape; bottom sheet em mobile/portrait. Context scroll view limita largura a 720px em telas largas (readable line-length editorial).
- **WPM selector compartilhado**: `WpmSelector` (all-in-one) usado em settings; `WpmCapsule` + `WpmPresetRow` usados separadamente nos controles. Preset drawer gera valores dinamicamente (atual ± incrementos de 50, clamped min/max), auto-centraliza o chip selecionado no scroll. Capsule com +/- faz ajuste fino de 25.
- **Biblioteca com tabs**: `LibraryScreen` separa "Livros" (source=epub) de "Artigos" (source=article) via `TabBar`. O FAB (`LibraryFab`) muda de acao conforme a tab ativa.

## Regras

- Todas as strings de UI devem usar i18n (ARB files em `lib/l10n/`). Nunca hardcodar texto PT ou EN.
- **Cores no leitor e painel de DisplaySettings vem de `DisplaySettings`, nunca de `Theme.of(context)`** — para permitir preview "ao vivo". A unica excecao e a secao Appearance em `settings_screen.dart` (toggle de ThemeMode), que usa o theme global.
- **Cores na biblioteca e chrome do app** (AppBar, cards, FAB, empty states, dialogs) vem de `Theme.of(context).colorScheme`, nunca de `AppColors.*` diretamente.
- Para adicionar/remover uma opcao de display ou leitura: editar `display_settings_panel.dart` (afeta automaticamente o bottom sheet no leitor E a tela full-screen de settings). Adicionar tambem o campo em `DisplaySettings` + `copyWith` + load/save no `DisplaySettingsNotifier`.
- Apos alterar tables do Drift ou classes com `@freezed`: rodar `build_runner`.
- Apos alterar ARB files: rodar `flutter gen-l10n` (l10n.yaml ja configurado).
- **Persistir livros/artigos**: sempre via `persistParsedBook` (em `lib/features/book_library/data/services/book_persistence.dart`). Nunca duplicar o fluxo insert-book + fan-out de tokens.
- **Comparar `source`**: usar as constantes de `BookSource` (`lib/database/tables/book_source.dart`), nunca literais `'epub'`/`'article'`.
- **URLs**: usar `UrlUtils.extractHttpUrl` / `parseWithHttpsFallback` em `lib/core/utils/url_utils.dart` — nao reimplementar parsing ad-hoc.
- **Font mapping**: usar `mapFontFamily()` de `lib/core/utils/font_mapper.dart` — nao reimplementar switch de nomes em cada widget.
- **Sync via Google Drive**: `DriveSyncFolderGateway` implementa `SyncFolderGateway` usando googleapis com scope `drive.file` (so enxerga arquivos que o proprio app criou). Auth via `google_sign_in` em `DriveAuthNotifier` — silent sign-in no startup, connect explicito em Settings. Root folder "RSVP Reader" criada sob demanda; id cacheado em `SyncConfig.driveFolderId`. Android-only.
- **Sync de biblioteca so inclui EPUB**: `LibrarySyncService` filtra `source=='epub'`. Artigos sao sempre locais.
- Testes unitarios dos core utils sao prioridade (ORP, timing, tokenizer, HTML stripper, readability). HTML stripper deve cobrir tags `_skipTags` para evitar regressao de CSS/JS vazando no texto.
- **Arquivos pequenos**: widgets extraidos em arquivos focados (1 responsabilidade). Controles do reader: `rsvp_controls.dart` compoe; subwidgets em `controls_*.dart` + `seek_slider.dart`. Biblioteca: `library_screen.dart` compoe; subwidgets em `library_*.dart`.

## Docs detalhados

- [docs/architecture.md](docs/architecture.md) — arquitetura, fluxo de dados, providers
- [docs/rsvp-engine.md](docs/rsvp-engine.md) — motor RSVP, ORP, timing, ramp-up
- [docs/article-import.md](docs/article-import.md) — pipeline de artigos web, readability, share sheet
- [docs/share-extension-ios.md](docs/share-extension-ios.md) — setup do share extension iOS (Xcode)
- [tasks.md](tasks.md) — bugs e features pendentes
