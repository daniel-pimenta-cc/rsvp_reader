# Arquitetura

## Padrao

Feature-based Clean Architecture com camadas internas por feature:
- `domain/entities/` — modelos puros (freezed ou plain Dart)
- `data/` — services, repositories impl
- `presentation/` — providers (Riverpod), screens, widgets

## Design System

Paleta editorial com tons quentes em dois modos (light e dark). Accent laranja #E55324 preservado em ambos.

**Tokens** em `lib/core/theme/`:
- `app_colors.dart` — `AppPalette.light` / `AppPalette.dark` (paletas completas com `toColorScheme()`) + `AppColors` para back-compat.
- `app_theme.dart` — `AppTheme.build(brightness:)` gera `ThemeData` completo cobrindo AppBar, Card, Button (filled/text/outlined/icon), Slider, BottomSheet, Dialog, Input, SnackBar, Divider, ListTile, FAB, TabBar, pageTransitions. Aplica `AppTypography.build(colorScheme)`.
- `app_typography.dart` — Lora (serif) em display/headline/title; Inter (sans) em body/label. `sectionHeader()` para divisorias uppercase tracked.
- `app_spacing.dart` — escala xs(4)/sm(8)/md(12)/base(16)/lg(24)/xl(32)/xxl(48).
- `app_radius.dart` — sm(6)/md(10)/lg(16)/xl(24) + `BorderRadius` const helpers + `borderTopXl`.
- `app_elevations.dart` — `AppShadows.level1..4` adaptados por brightness (dark mais profundo).
- `app_motion.dart` — `AppDurations` (fast/base/slow/page) + `AppCurves` (standard/emphasized/decelerate).
- `responsive.dart` — `Breakpoints` (compact 600 / medium 840 / expanded 1200), `DeviceType` enum, extensions `context.isTablet`/`isLandscape`/`deviceType`, helpers `gridCrossAxisCount()` + `gridAspectRatio()`.

**Regra de uso de cores**:
- Biblioteca, chrome, dialogs: `Theme.of(context).colorScheme.*`
- Dentro do reader e painel DisplaySettings: `DisplaySettings.wordColor` / `.backgroundColor` etc. (preview ao vivo)
- Nunca `AppColors.*` diretamente em widgets novos (back-compat only)

**Tema light/dark**: `ThemeModeNotifier` persiste em SharedPreferences. Ao trocar brightness efetivo, chama `DisplaySettingsNotifier.applyBrightness(newBrightness)` que inverte wordColor + backgroundColor para paleta correspondente. ORP e highlight ficam intactos.

## Features e responsabilidades

### book_library
Tela principal com master-detail responsivo. `LibraryScreen` decide layout:
- **Compact / portrait**: Scaffold com TabBarView fullscreen, navegacao por `context.push('/reader/:id')`.
- **Tablet landscape**: `Row` com lista (440px) + `VerticalDivider` + reader/placeholder. `selectedBookIdProvider` controla qual livro esta aberto no painel direito sem trocar rota.

Widgets extraidos:
- `LibraryList` — grid categorizado (In Progress / Not Started / Read) com `SliverGrid` adaptativo (2/3/4 colunas). Pull-to-refresh quando sync configurado.
- `BookCard` — capa ou gradient fallback, titulo, subtitulo, `ReadingProgressBar`, scale-on-press com haptic, highlight quando selecionado em master-detail.
- `LibraryFab` — FAB com estado busy/idle, acao muda por tab (EPUB file picker / article URL dialog).
- `LibraryAppBarBottom` — TabBar + `LibraryImportProgressBar` condicional.
- `LibrarySkeleton` — grid de `SkeletonBookCard` com shimmer durante loading.
- `LibraryEmptyState` — icone circular + titulo serif + subtitulo + CTA opcional.
- `LibrarySectionHeader` — label uppercase tracked + badge de contagem.
- `ReaderPlaceholder` — painel vazio em tablet ("Pick a book to begin").

Sub-modulo `data/services/book_persistence.dart` contem `persistParsedBook` — helper compartilhado entre `epub_import` e `article_import`. **Todo import passa por aqui**.

### epub_import
Pipeline: EPUB bytes → `epub_pro` → capitulos → `HtmlStripper` → `TextTokenizer` → `List<WordToken>` → `ParsedBook` → `persistParsedBook`.

### article_import
Pipeline: URL → `http.get` → HTML → `ReadabilityExtractor` → `HtmlStripper` → `TextTokenizer` → `ParsedBook` (1 capitulo) → `persistParsedBook(source: BookSource.article)`. Detalhes em [article-import.md](article-import.md).

### library_sync
Sincroniza metadata da biblioteca, `reading_progress` e `DisplaySettings` atraves de uma pasta "RSVP Reader" criada pelo app no Google Drive do usuario (scope `drive.file` — so enxerga arquivos que o app criou). Backend unico via `DriveSyncFolderGateway` (implementa `SyncFolderGateway`); `DriveAuthNotifier` cuida de sign-in/sign-out e de gerar o `http.Client` autenticado. `SyncConfig.driveFolderId` cacheia o id da pasta root. **Filtra `source='epub'`** — artigos sao sempre locais. Android-only.

### rsvp_reader
Feature central. Widgets organizados em arquivos focados:

**Screen:**
- `RsvpReaderScreen` — host dos 3 modos. Aceita `onClose` callback para master-detail. Em tablet landscape, renderiza `ReaderSidePanel` ao lado do body quando ativo.

**Motor:**
- `RsvpEngineNotifier` — Ticker-based. Play/pause/seek/speed/ramp-up e `ReaderMode`. Salva progresso no pause.

**Display RSVP:**
- `RsvpWordDisplay` — RichText com ORP anchor. Auto-scale para palavras longas. Margens e font scale responsivos via `ResponsiveDefaults`.

**Modo contexto:**
- `ContextScrollView` — lista virtualizada de capitulos + paragrafos. Highlight via ValueNotifier local, velocity-based stepping, sync com engine no scroll end. `ConstrainedBox(maxWidth: 720)` em telas largas. `showHighlight: false` serve modo ereader.

**Controles (dock):**
- `RsvpControls` — compositor. `AnimatedSize` na coluna para crescer quando WPM drawer abre.
- `ControlsShell` — superficie translucida com backdrop blur + borda superior.
- `ControlsMetaRow` — titulo do capitulo + tempo restante (tabular figures).
- `ControlsProgressRow` — percentual + navegacao de capitulos.
- `ControlsTransportRow` — play 64px com `AnimatedSwitcher` (scale+fade), skips 48px, `WpmCapsule`. Layout: `LayoutBuilder` com breakpoint 520px — `Stack` (inline, WPM a direita) em telas largas, `Column` (empilhado) em telas estreitas.
- `SeekSlider` — slider com marcadores de capitulo (visual-only via `IgnorePointer`), value indicator com titulo do capitulo.

**WPM selector (compartilhado):**
- `WpmSelector` — all-in-one: capsule + AnimatedSize drawer. Usado em Settings.
- `WpmCapsule` — pill com minus / label clicavel / plus. Label tap abre drawer.
- `WpmPresetRow` — horizontal scrollable de chips. Presets gerados dinamicamente (atual ± incrementos de 50, clamped min/max). Auto-scroll centra chip selecionado na abertura.
- Usado nos controles (capsule + drawer separados) e em settings (WpmSelector all-in-one).

**Settings do reader:**
- `DisplaySettingsPanel` — coluna unica com TODAS as configs. Aceita `bookId` opcional para live preview via engine.
- `display_settings_widgets.dart` (`part of`) — componentes: `_SectionHeader`, `_SettingRow`, `_SwitchRow`, `_PlusMinusControl`, `_ColorRow`, `_FontSelector`.
- `ReaderSettingsSheet` — DraggableScrollableSheet envolvendo DisplaySettingsPanel.
- `ChapterListSheet` — lista de capitulos para navegacao.
- `ReaderSidePanel` — painel lateral direito em tablet landscape (settings ou chapters), controlado por `readerSidePanelProvider`.

### settings
Tela full-screen: secao Appearance (`SegmentedButton<ThemeMode>`) + `DisplaySettingsPanel()` + `SyncSettingsSection` + About. Background e cores vem de `DisplaySettings` (preview ao vivo), exceto Appearance que usa theme global.

### reading_stats
Telemetria local + tres surfaces de apresentacao:

- **`ReadingStatsScreen` (`/stats`)** — TabBar Weekly (7d) / Monthly (30d). Cards de summary, stacked bar "words per day" (cor por livro), bar "time per day", line "wpm trend" (fl_chart). Book breakdown ordenado por tempo. Layout 2-col em tablet landscape.
- **`MonthlyRecapScreen` (`/stats/recap`)** — preview do `MonthlyRecapCard` 9:16 + botao Share. Card com secao "Finalizados" destacada + "Em leitura" abaixo, rodape com totais.
- **`BookCompletionScreen` (`/books/:id/completion`)** — disparada automaticamente pelo reader ao chegar no fim de um livro (via `RsvpState.finishTicket`). Star picker 0-5 (persiste em `books.rating`), bloco de stats detalhadas, toggle "Incluir stats na imagem", `BookCompletionCard` 9:16 compartilhavel.

Agregacoes puras (`buildSnapshot`, `buildMonthlyRecap`, `buildCompletionSummary`) ficam nos providers junto com o `StreamProvider.family` / `FutureProvider.family`. **Share cards usam paleta fixa (independente de tema)** pra consistencia do PNG exportado. Detalhes em [reading-stats.md](reading-stats.md).

## Share sheet e integracao top-level

Dois componentes vivem acima de `MaterialApp.router` em `lib/app.dart`:

- **ShareIntentHandler**: escuta `ReceiveSharingIntent`, filtra URLs, dispara `ArticleImportNotifier.importFromUrl`. Android so.
- **_ArticleImportCoordinator**: `ref.listen(articleImportProvider)` no nivel do app. Snackbar durante fetch/process, navega para reader no done.

## State Management

**Riverpod 2 sem code generation**.

Providers principais:
- `appDatabaseProvider` — instancia do Drift DB, overridden no main
- `booksDaoProvider`, `readingProgressDaoProvider`, `readingSessionDaoProvider`, `cachedTokensDaoProvider`, `syncImportFailuresDaoProvider` — DAOs
- `rsvpEngineProvider(bookId)` — StateNotifierProvider.family, motor RSVP por livro. Grava `reading_session` row em cada flush e emite `finishTicket` incrementado no fim-do-livro organico.
- `displaySettingsProvider` — DisplaySettings persistidas via SharedPreferences
- `themeModeProvider` — ThemeMode (system/light/dark) persistido, inverte cores do reader ao trocar brightness
- `selectedBookIdProvider` — StateProvider<String?> para master-detail em tablet landscape
- `readerSidePanelProvider` — StateProvider<ReaderSidePanelMode> para painel lateral do reader
- `bookLibraryProvider` — StreamProvider com lista de livros
- `categorizedLibraryProvider(LibraryKind)` — FutureProvider.family que filtra e agrupa por progresso
- `epubImportProvider`, `articleImportProvider` — StateNotifiers para fluxos de import
- `librarySyncProvider` — StateNotifier orquestrando push/pull/auto-import
- `driveAuthProvider` — StateNotifier do sign-in do Google Drive (email conectado, busy, erro)
- `driveSyncFolderGatewayProvider` — `DriveSyncFolderGateway` com fabrica de `http.Client` autenticado
- `statsSnapshotProvider(StatsRange)` — StreamProvider.family que agrega sessions por dia/livro
- `monthlyRecapProvider(RecapMonth)` — FutureProvider.family que classifica livros em finished/reading no mes
- `bookCompletionProvider(bookId)` — StreamProvider.family com stats agregadas do livro (tempo, palavras, sessoes, avgWpm, rating)

## Database (Drift/SQLite)

Schema version **6**. Tabelas:
- `BooksTable` — metadata: id, title, author, filePath, coverImage, totalWords, chapterCount, importedAt, lastReadAt, syncFileName, **source** (BookSource.epub|article), **sourceUrl**, **siteName**, **rating** (nullable int 0-5, v6).
- `ReadingProgressTable` — posicao por livro (bookId PK, chapterIndex, wordIndex, wpm, updatedAt).
- `ReadingSessionTable` (v5) — uma row por trecho continuo de `isPlaying=true`. Campos: id, bookId, startedAt, endedAt, durationMs, wordsRead, startWordIndex, endWordIndex, avgWpm. Sem FK em `bookId` (historico sobrevive a delete). Indices em `startedAt` e `bookId`.
- `CachedTokensTable` — tokens pre-processados por capitulo (bookId, chapterIndex, chapterTitle, tokensJson, wordCount, paragraphCount).
- `SyncImportFailuresTable` — EPUBs do Drive que falharam ao ser auto-importados.

`BookSource` (`lib/database/tables/book_source.dart`) sao constantes de string (nao enum Dart).

**Migracoes**: cada bump incrementa `schemaVersion` e adiciona um bloco `if (from < N)` na `MigrationStrategy`. Os bumps foram: v2 syncFileName em books, v3 sync_import_failures table, v4 article source fields em books, v5 reading_session + indices, v6 rating em books.

## Fluxo de dados

```
Import EPUB:    EPUB file   → epub_pro → HtmlStripper → TextTokenizer → ParsedBook ─┐
Import Article: URL → http → readability → HtmlStripper → TextTokenizer → ParsedBook ─┤
                                                                                      ├─→ persistParsedBook → SQLite
Share sheet:    Android intent → ShareIntentHandler → ArticleImportNotifier          ─┘

Leitura:        SQLite cache → Chapter[] → RsvpEngine (Ticker) → RsvpWordDisplay / ContextScrollView
Config:         SharedPreferences ↔ DisplaySettingsNotifier ↔ RsvpEngine.displaySettings
Theme:          ThemeModeNotifier ↔ DisplaySettingsNotifier.applyBrightness() → reader palette swap
Sync (EPUB):    SQLite (source=epub) ↔ library.json manifest + books/ em RSVP Reader/ no Drive
Telemetria:     RsvpEngine._flushSession() em pause/end/ereader/dispose → reading_session row
Stats:          reading_session[] → buildSnapshot / buildMonthlyRecap / buildCompletionSummary → UI + PNG
Completion:     engine end-of-book (_advanceWord) → finishTicket++ → ref.listen → context.push(/completion)
```

## Rotas (go_router)

```
/                          LibraryScreen (com icone stats no AppBar)
/reader/:bookId            RsvpReaderScreen (fullscreenDialog)
/settings                  SettingsScreen
/stats                     ReadingStatsScreen (TabBar weekly/monthly)
/stats/recap               MonthlyRecapScreen (recap do mes corrente)
/books/:bookId/completion  BookCompletionScreen (star rating + share card)
```

## i18n

ARB files em `lib/l10n/` (app_en.arb, app_pt.arb). Gerados em `lib/l10n/generated/`. Import: `import '...l10n/generated/app_localizations.dart'`. Usar `AppLocalizations.of(context)!`.
