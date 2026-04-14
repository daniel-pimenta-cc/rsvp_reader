# Arquitetura

## Padrao

Feature-based Clean Architecture com camadas internas por feature:
- `domain/entities/` — modelos puros (freezed ou plain Dart)
- `data/` — services, repositories impl
- `presentation/` — providers (Riverpod), screens, widgets

## Features e responsabilidades

### book_library
Tela principal. Grid de livros importados com capa, titulo, progresso. FAB para importar EPUB. Stream reativo do DB (`watchAllBooks`).

### epub_import
Pipeline: EPUB bytes → `epub_pro` → capitulos → `HtmlStripper` → `TextTokenizer` → `List<WordToken>` → cache no SQLite.

Cada `WordToken` ja tem `orpIndex` e `timingMultiplier` pre-calculados. Isso garante zero computacao no loop do RSVP.

`HtmlStripper` mantem 3 conjuntos de tags: `_blockTags` (geram quebra de paragrafo), `_breakTags` (`br`/`hr`, geram quebra de linha) e `_skipTags` (`style`, `script`, `noscript`, `head`, `meta`, `link`, `title`, `object`, `embed`, `svg`, `iframe`, `template` — subtree inteira ignorada para nao vazar CSS/JS no texto).

### rsvp_reader
Feature central. Contem:
- **RsvpEngineNotifier** (`rsvp_engine_provider.dart`): motor Ticker-based. Controla play/pause/seek/speed/ramp-up e o `ReaderMode` (rsvp/scroll/ereader). `enterEreaderMode`/`exitEreaderMode`/`toggleEreaderMode` alternam o terceiro modo. Salva progresso no pause e ao entrar no ereader.
- **RsvpWordDisplay** (`rsvp_word_display.dart`): renderiza palavra com ORP via RichText + TextSpan. Auto-scale para palavras longas. Posicao horizontal/vertical configuravel. Renderiza opcionalmente uma **focus line** abaixo da palavra (full width, edge-to-edge) — modo focus puro ou focus + barra de progresso.
- **ContextScrollView** (`context_scroll_view.dart`): modo scroll. Lista virtualizada de todos os capitulos (headers + paragrafos). Highlight da palavra atual via "pill" arredondada com glow sutil. Scroll atualiza posicao via ValueNotifier local (nao Riverpod) e usa **velocity-based stepping**: word/sentence/paragraph dependendo da velocidade do scroll. Sync com engine so no scroll end. Aceita `showHighlight: false` para servir tambem ao modo ereader (sem pill, sem tap-to-seek).
- **RsvpControls** (`rsvp_controls.dart`): play/pause, skip, seek slider com **marcadores de capitulo** (visual-only via IgnorePointer) e value indicator mostrando titulo do capitulo durante drag, WPM +/-, link para lista de capitulos. Escondido em modo ereader.
- **DisplaySettingsPanel** (`display_settings_panel.dart`): widget compartilhado com TODAS as configuracoes de display/leitura. Aceita `bookId` opcional — se presente, atualiza o engine ao vivo. Fonte unica de verdade.
- **ReaderSettingsSheet** (`reader_settings_sheet.dart`): bottom sheet (DraggableScrollableSheet) que envolve `DisplaySettingsPanel(bookId: ...)`.
- **ChapterListSheet** (`chapter_list_sheet.dart`): bottom sheet com lista de capitulos para navegacao.

### settings
Tela full-screen que envolve `DisplaySettingsPanel()` (sem bookId) + secao About. Visualmente identica ao bottom sheet do leitor (mesmas cores do `DisplaySettings`, mesmos componentes).

## State Management

**Riverpod 2 sem code generation** (evita conflito source_gen com drift_dev).

Providers principais:
- `appDatabaseProvider` — instancia do Drift DB, overridden no main
- `booksDaoProvider`, `readingProgressDaoProvider`, `cachedTokensDaoProvider` — DAOs
- `rsvpEngineProvider(bookId)` — StateNotifierProvider.family, motor RSVP por livro
- `displaySettingsProvider` — DisplaySettings persistidas via SharedPreferences
- `bookLibraryProvider` — StreamProvider com lista de livros
- `epubImportProvider` — StateNotifier para fluxo de import

## Database (Drift/SQLite)

3 tabelas:
- `BooksTable` — metadata (id, title, author, filePath, coverImage, totalWords, chapterCount, importedAt, lastReadAt)
- `ReadingProgressTable` — posicao por livro (bookId PK, chapterIndex, wordIndex, wpm, updatedAt)
- `CachedTokensTable` — tokens pre-processados por capitulo (bookId, chapterIndex, chapterTitle, tokensJson, wordCount, paragraphCount)

Tokens sao serializados como JSON no SQLite. ~2-3MB para livro de 100K palavras.

## Fluxo de dados

```
Import: EPUB file → epub_pro → HtmlStripper → TextTokenizer → WordToken[] → SQLite cache
Leitura: SQLite cache → Chapter[] → RsvpEngine (Ticker) → RsvpWordDisplay / ContextScrollView
Config:  SharedPreferences ↔ DisplaySettingsNotifier ↔ RsvpEngine.displaySettings
```

## i18n

ARB files em `lib/l10n/` (app_en.arb, app_pt.arb). Gerados em `lib/l10n/generated/`. Import: `import '...l10n/generated/app_localizations.dart'`. Usar `AppLocalizations.of(context)!`.
