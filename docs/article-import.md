# Import de artigos web

Permite ler qualquer artigo da web em RSVP. O usuario cola uma URL no
dialog da tab "Articles" da biblioteca, ou compartilha uma URL do
navegador via share sheet do Android — nos dois caminhos o app baixa
a pagina, extrai o corpo do artigo, e cria um "livro sintetico" de 1
capitulo que flui pelo mesmo pipeline de leitura usado pelos EPUBs.

## Motivacao

- O fluxo de RSVP (palavra-a-palavra com ORP) funciona bem pra texto
  longo de qualquer origem, nao so livros.
- Artigos web sao leituras curtas e descartaveis — ter eles numa tab
  separada evita poluir a lista de livros do usuario.
- Reaproveitar o pipeline existente (`WordToken`, cache de tokens, engine
  RSVP, modos de leitura) custa quase nada.

## Arquitetura

```
URL
  ↓
[http.get com timeout 20s + UA desktop]
  ↓
HTML bytes → utf8.decode(bodyBytes, allowMalformed: true)
  ↓
[ReadabilityExtractor.extract]
  ├─ _stripNoise: remove script/style/nav/aside/footer/header/form/...
  ├─ metadata: og:title, meta[name=author], og:site_name, h1, <title>
  └─ _findBestCandidate:
       1. se existir UM unico <article> ou <main> com >200 chars → vence
       2. senao, se existir [role="main"] com >200 chars → vence
       3. senao, scoring em div/section/article:
            score += 1 por <p> com >25 chars
            score += N virgulas por paragrafo
            score += len/100 (clamped 0-3)
            score += 25 se class/id match em "article|body|content|entry|main|page|post|story|text|blog"
            score -= 25 se class/id match em "comment|meta|footer|sidebar|sponsor|ad|share|nav|menu|..."
            score *= (1 - link_density)   # penaliza navs
  ↓
content HTML (inner do vencedor)
  ↓
HtmlStripper.strip  → texto limpo com paragrafos
  ↓
TextTokenizer.tokenize(chapterIndex: 0, globalOffset: 0) → WordToken[]
  ↓
ParsedBook(title, byline, 1 Chapter, totalWords)
  ↓
persistParsedBook(source: BookSource.article, sourceUrl, siteName, filePath: '')
  ↓
SQLite: books row + cached_tokens (1 chapter)
```

## Componentes

### `lib/core/utils/readability_extractor.dart`

Port Dart puro (sem deps nativas) do algoritmo do Mozilla Readability,
simplificado. Entrada: HTML string. Saida: `ExtractedArticle {title?, byline?, siteName?, contentHtml}`.

Heuristicas:
- `_stripTags`: tags que sao sempre ruido (script, style, nav, aside,
  footer, header, form, button, iframe, svg, etc.).
- Tambem remove elementos com class/id matching `_negativePatterns`
  SE o elemento nao tem descendentes `<p>` (evita comer sidebars com
  pull quotes reais).
- `_positivePatterns` / `_negativePatterns`: classes/ids que dao +25
  / -25 de score por match (case-insensitive).
- Link density penalty: `score *= (1 - total_link_text_len / total_text_len)` —
  blocos que sao mostly links (navs sobreviventes) sao zerados.

Testes em `test/core/utils/readability_extractor_test.dart` cobrem
8 casos (artigo unico, metadata, scoring div vs sidebar, script/style
strip, fallback, comment penalty).

### `lib/features/article_import/data/services/article_extraction_service.dart`

Orquestra HTTP + extract. Expoe:
- `extractFromUrl(String url) → ArticleExtractionResult` — faz o fetch
  e chama `extractFromHtml`.
- `extractFromHtml(String html, {required String url}) → ArticleExtractionResult` —
  pure, sem rede. Util pra testes e para quando o share sheet entrega
  HTML ao inves de URL.

Hardening:
- Timeout de 20s no `http.get`.
- `User-Agent` desktop para evitar redirecionamento para mobile landings
  que frequentemente tem menos conteudo.
- `utf8.decode(bodyBytes, allowMalformed: true)` — muitos sites servem
  UTF-8 mas declaram charset errado; confiar no header produz mojibake.

### `lib/features/article_import/presentation/providers/article_import_provider.dart`

`ArticleImportNotifier` (StateNotifier) com estados
`idle | fetching | processing | done | error`. `importFromUrl(String)`
executa o pipeline inteiro e deixa o estado em `done` com
`importedBookId`. O coordinator no `app.dart` observa e navega.

### `lib/features/article_import/presentation/widgets/import_article_dialog.dart`

Dialog com um `TextField` de URL. Pre-enche automaticamente se o
clipboard tiver uma URL http(s). Submit chama
`ArticleImportNotifier.importFromUrl`.

### `lib/core/share/share_intent_handler.dart`

Widget que envolve `MaterialApp` e escuta `ReceiveSharingIntent`
(cold start via `getInitialMedia` + warm start via `getMediaStream`).
Filtra para `SharedMediaType.url` ou `.text` com uma URL http(s)
dentro (via `UrlUtils.extractHttpUrl`, que tolera "Titulo\nhttps://…"
que alguns navegadores mandam). Dispara `ArticleImportNotifier.importFromUrl`.

### `_ArticleImportCoordinator` em `lib/app.dart`

`ref.listen(articleImportProvider)` no nivel do app. Mostra snackbar
persistente de progresso (fetching / processing), navega para
`/reader/:id` no done, snackbar de erro no error. Usa `rootMessengerKey`
para acessar o `ScaffoldMessenger` de acima do `MaterialApp`.

## Schema

Article rows em `books` carregam:
- `source = 'article'` (BookSource.article)
- `sourceUrl = 'https://…'` — URL original
- `siteName = 'Example News'` — se a pagina tinha `og:site_name`
- `filePath = ''` — sem arquivo no disco (sentinel)
- `coverImage = null`

`BookCard` usa `siteName` (ou o host da URL) como subtitulo, em vez
de `author`.

## Sync

`LibrarySyncService` filtra `source='epub'` em `_buildLocalSnapshot` —
artigos nao participam do sync via Google Drive. Motivos:
- Nao ha arquivo de artigo no disco para subir.
- O manifesto `library.json` descreve metadata de livros EPUB.
- Artigos sao leituras curtas, sincroniza-los traz pouco beneficio.

Se no futuro virar desejavel, seria preciso estender o schema do
manifesto para carregar o HTML extraido (ou a URL + tokens) e adicionar
uma secao `articles` paralela a `books`.

## Share sheet iOS

Android funciona hoje via `intent-filter` em `AndroidManifest.xml`. iOS
precisa de um Share Extension target criado no Xcode num Mac — passos
em [share-extension-ios.md](share-extension-ios.md).

## Entry points de import (resumo)

| Origem              | Entry point                             | Plataforma |
|---------------------|------------------------------------------|------------|
| File picker EPUB    | FAB na tab Books                         | todas      |
| Google Drive sync   | Auto-import em `LibrarySyncService`      | Android    |
| URL dialog          | FAB na tab Articles                      | todas      |
| Share sheet         | `ShareIntentHandler` via intent-filter   | Android    |
| Share extension     | `ShareIntentHandler` via app group       | iOS (TODO) |
