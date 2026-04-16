# Arquitetura

## Padrao

Feature-based Clean Architecture com camadas internas por feature:
- `domain/entities/` — modelos puros (freezed ou plain Dart)
- `data/` — services, repositories impl
- `presentation/` — providers (Riverpod), screens, widgets

## Features e responsabilidades

### book_library
Tela principal. `TabBar` com duas tabs: **Books** (source=epub) e **Articles** (source=article). Grid de livros importados com capa, titulo, progresso. FAB muda conforme a tab ativa (file picker para EPUB, URL dialog para artigo). Stream reativo do DB (`watchAllBooks`).

Sub-modulo `data/services/book_persistence.dart` contem `persistParsedBook` — helper compartilhado entre `epub_import` e `article_import` que insere a row em `books` + faz fan-out dos tokens por capitulo em `cached_tokens`. **Todo import passa por aqui**; nunca reimplementar esse fluxo.

### epub_import
Pipeline: EPUB bytes → `epub_pro` → capitulos → `HtmlStripper` → `TextTokenizer` → `List<WordToken>` → `ParsedBook` → `persistParsedBook`.

### article_import
Pipeline: URL → `http.get` → HTML → `ReadabilityExtractor` → `HtmlStripper` → `TextTokenizer` → `ParsedBook` (1 capitulo) → `persistParsedBook(source: BookSource.article)`. Detalhes em [article-import.md](article-import.md).

### library_sync
Sincroniza a biblioteca para uma pasta escolhida pelo usuario (local ou backed por Drive/Dropbox/etc via SAF no Android). **Filtra `source='epub'`** — artigos sao sempre locais porque o manifesto de sync e formato EPUB e nao ha arquivo de artigo para subir.

### rsvp_reader
Feature central. Contem:
- **RsvpEngineNotifier** (`rsvp_engine_provider.dart`): motor Ticker-based. Controla play/pause/seek/speed/ramp-up e o `ReaderMode` (rsvp/scroll/ereader). `enterEreaderMode`/`exitEreaderMode`/`toggleEreaderMode` alternam o terceiro modo. Salva progresso no pause e ao entrar no ereader.
- **RsvpWordDisplay** (`rsvp_word_display.dart`): renderiza palavra com ORP via RichText + TextSpan. Auto-scale para palavras longas. Posicao horizontal/vertical configuravel. Renderiza opcionalmente uma **focus line** abaixo da palavra (full width, edge-to-edge) — modo focus puro ou focus + barra de progresso.
- **ContextScrollView** (`context_scroll_view.dart`): modo scroll. Lista virtualizada de todos os capitulos (headers + paragrafos). Highlight da palavra atual via "pill" arredondada com glow sutil. Scroll atualiza posicao via ValueNotifier local (nao Riverpod) e usa **velocity-based stepping**: word/sentence/paragraph dependendo da velocidade do scroll. Sync com engine so no scroll end. Aceita `showHighlight: false` para servir tambem ao modo ereader (sem pill, sem tap-to-seek).
- **RsvpControls** (`rsvp_controls.dart`): play/pause, skip, seek slider com **marcadores de capitulo** (visual-only via IgnorePointer) e value indicator mostrando titulo do capitulo durante drag, WPM +/-, link para lista de capitulos. Escondido em modo ereader. Titulo do capitulo acima da seek bar vem com `Expanded + ellipsis` (artigos costumam ter titulos longos).
- **DisplaySettingsPanel** (`display_settings_panel.dart`): widget compartilhado com TODAS as configuracoes de display/leitura. Aceita `bookId` opcional — se presente, atualiza o engine ao vivo. Fonte unica de verdade.
- **ReaderSettingsSheet** (`reader_settings_sheet.dart`): bottom sheet (DraggableScrollableSheet) que envolve `DisplaySettingsPanel(bookId: ...)`.
- **ChapterListSheet** (`chapter_list_sheet.dart`): bottom sheet com lista de capitulos para navegacao.

### settings
Tela full-screen que envolve `DisplaySettingsPanel()` (sem bookId) + secao About. Visualmente identica ao bottom sheet do leitor (mesmas cores do `DisplaySettings`, mesmos componentes).

## Share sheet e integracao top-level

Dois componentes vivem acima de `MaterialApp.router` em `lib/app.dart` para funcionar de qualquer rota:

- **ShareIntentHandler** (`lib/core/share/share_intent_handler.dart`): escuta `ReceiveSharingIntent` (cold + warm start), filtra para URLs http(s) via `UrlUtils.extractHttpUrl`, dispara `ArticleImportNotifier.importFromUrl`. Android so — iOS requer target Xcode manual (ver [share-extension-ios.md](share-extension-ios.md)).
- **_ArticleImportCoordinator**: `ref.listen(articleImportProvider)` no nivel do app. Mostra snackbar persistente durante `fetching`/`processing`, navega para `/reader/:id` no `done`, snackbar de erro no `error`. Usa `rootMessengerKey` (GlobalKey<ScaffoldMessengerState>) para alcancar o `ScaffoldMessenger` de acima do `MaterialApp`.

Por que acima do `MaterialApp`: o share pode chegar quando o usuario esta em qualquer tela (reader, settings, ou nem abriu o app). Ter o listener no root garante navegacao consistente em todos os casos. `LibraryScreen` ainda tem listener para o fluxo EPUB (porque esse import so e iniciado dali).

## State Management

**Riverpod 2 sem code generation** (evita conflito source_gen com drift_dev).

Providers principais:
- `appDatabaseProvider` — instancia do Drift DB, overridden no main
- `booksDaoProvider`, `readingProgressDaoProvider`, `cachedTokensDaoProvider`, `syncImportFailuresDaoProvider` — DAOs
- `rsvpEngineProvider(bookId)` — StateNotifierProvider.family, motor RSVP por livro
- `displaySettingsProvider` — DisplaySettings persistidas via SharedPreferences
- `bookLibraryProvider` — StreamProvider com lista de livros (todos os sources)
- `categorizedLibraryProvider(LibraryKind)` — FutureProvider.family que filtra por source (books/articles) e agrupa por progresso (in-progress / not-started / read)
- `epubImportProvider`, `articleImportProvider` — StateNotifiers para os dois fluxos de import
- `articleExtractionServiceProvider` — singleton com `http.Client`, `onDispose` fecha o client
- `librarySyncProvider` — StateNotifier orquestrando push/pull/auto-import do sync folder

## Database (Drift/SQLite)

Schema version **4**. Tabelas:
- `BooksTable` — metadata. Colunas: `id`, `title`, `author`, `filePath`, `coverImage`, `totalWords`, `chapterCount`, `importedAt`, `lastReadAt`, `syncFileName`, **`source`** (BookSource.epub | article), **`sourceUrl`** (nullable, para articles), **`siteName`** (nullable, para articles).
- `ReadingProgressTable` — posicao por livro (bookId PK, chapterIndex, wordIndex, wpm, updatedAt).
- `CachedTokensTable` — tokens pre-processados por capitulo (bookId, chapterIndex, chapterTitle, tokensJson, wordCount, paragraphCount).
- `SyncImportFailuresTable` — registros de EPUBs que falharam ao ser auto-importados do sync folder.

Tokens sao serializados como JSON no SQLite. ~2-3MB para livro de 100K palavras. Artigos geralmente < 50KB.

`BookSource` (`lib/database/tables/book_source.dart`) sao constantes de string (nao enum Dart) para mapear direto para a coluna text sem converter.

Migrations em `app_database.dart`:
- v1 → v2: `syncFileName` em books
- v2 → v3: `sync_import_failures` table
- v3 → v4: `source` + `sourceUrl` + `siteName` em books

## Fluxo de dados

```
Import EPUB:    EPUB file   → epub_pro → HtmlStripper → TextTokenizer → ParsedBook ─┐
Import Article: URL → http → readability → HtmlStripper → TextTokenizer → ParsedBook ─┤
                                                                                      ├─→ persistParsedBook → SQLite cache
Share sheet:    Android intent → ShareIntentHandler → ArticleImportNotifier          ─┘

Leitura:        SQLite cache → Chapter[] → RsvpEngine (Ticker) → RsvpWordDisplay / ContextScrollView
Config:         SharedPreferences ↔ DisplaySettingsNotifier ↔ RsvpEngine.displaySettings
Sync (EPUB so): SQLite (source=epub) ↔ library.json manifest + books/ na pasta escolhida
```

## i18n

ARB files em `lib/l10n/` (app_en.arb, app_pt.arb). Gerados em `lib/l10n/generated/` (nao versionado — rodar `flutter gen-l10n` apos clone). Import: `import '...l10n/generated/app_localizations.dart'`. Usar `AppLocalizations.of(context)!`.
