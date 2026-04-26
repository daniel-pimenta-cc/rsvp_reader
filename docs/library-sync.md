# Library sync

EPUBs + reading progress + display settings sincronizados via Google Drive.
Disponivel em Android (via `google_sign_in` nativo) e Linux desktop (via
fluxo OAuth loopback — ver [linux-desktop.md](linux-desktop.md#google-drive-sync)).
Opt-in, scope `drive.file` (o app so enxerga arquivos que ele proprio criou).

A camada de auth é abstraída por `DriveAuthBackend`
(`lib/features/library_sync/data/auth/`), com duas implementações concretas:
`GoogleSignInDriveAuthBackend` (mobile) e `DesktopOAuthDriveAuthBackend`
(desktop). Tudo abaixo de `DriveAuthNotifier` — incluindo o gateway, o sync
service e o manifest — é idêntico entre as plataformas; só o `AuthClient`
muda de fornecedor.

## Visao geral

O sync usa uma pasta `RSVP Reader/` no Drive do usuario, com dois tipos de
arquivo:

```
RSVP Reader/
  library.json          ← manifest (metadata + progress + settings)
  books/
    <user-chosen>.epub  ← um EPUB por livro ativo
    <user-chosen>.epub
    ...
```

`library.json` e a fonte da verdade para metadata; os EPUBs sao so payload.
Um livro "existe" quando tem entrada na manifest E (opcionalmente) o EPUB
correspondente em `books/`.

Cada dispositivo roda o mesmo algoritmo de merge last-write-wins ao sincronizar:

1. **Pull** do manifest remoto + listagem de `books/`
2. **Snapshot** do estado local (livros + progress + settings)
3. **Merge** com regras determinísticas
4. **Apply** as mudancas no DB local
5. **Push** o manifest merged de volta + upload de EPUBs faltando

A sincronizacao de EPUBs e opcional (`SyncConfig.syncEpubs`). Sem ela, so
manifest (metadata + progress + settings) sobe/desce.

## Manifest (`library.json`)

Serializado em `lib/features/library_sync/domain/entities/sync_library.dart`.
Schema atual: v1.

```jsonc
{
  "schemaVersion": 1,
  "updatedAt": "2026-04-23T...Z",  // stamp do ultimo push (meta, nao usado em merge de campos)
  "updatedBy": "<deviceId>",        // idem
  "settings": {
    "values": { /* DisplaySettings serializado como Map<String,dynamic> */ },
    "updatedAt": "..."              // usado em merge LWW
  },
  "books": [
    {
      "id": "<uuid>",
      "title": "...",
      "author": "...",
      "totalWords": 12345,
      "chapterCount": 10,
      "importedAt": "...",
      "lastReadAt": "...",
      "hasEpubFile": true,
      "syncFileName": "user-visible.epub",
      "progress": { "chapterIndex": 3, "wordIndex": 512, "wpm": 425, "updatedAt": "..." },
      "deletedAt": null,            // quando != null, esta entrada e um tombstone
      "updatedAt": "..."            // usado em merge LWW para escolher "newer"
    }
  ]
}
```

## Regras de merge

Definidas em `mergeLibraries` / `mergeBook` / `mergeProgress` (puro, sem I/O,
coberto por testes em `test/features/library_sync/sync_library_test.dart`).

**Per-book** (`mergeBook(a, b)`):
- `updatedAt`: o maior dos dois (wins determina varios outros campos).
- Campos que seguem o "newer": `title`, `author`, `syncFileName` (com fallback
  pro older se newer for null).
- `importedAt`: o **menor** (preserva data de import original).
- `lastReadAt`: o **maior** (progresso nunca volta).
- `hasEpubFile`: `a.hasEpubFile || b.hasEpubFile`.
- `progress`: `mergeProgress` — dentro de 60s, prefere o `wordIndex` maior
  (resistencia a clock skew); alem disso, LWW.
- `deletedAt`: `_laterNullable` — **tombstone e monotonico**. Uma vez
  marcado deletado de um lado, merged fica tombstoned pra sempre. Nao ha
  "ressurreicao".

**Library (`mergeLibraries`)**:
- Uniao por `id`. Livros so no remoto entram como vieram; so no local idem.
- Settings: o com `updatedAt` mais recente vence.

## Tombstones

Quando o usuario deleta um livro (`deleteBookProvider`), alem de remover a
row local, disparamos um `pushTombstone`:

1. Le manifest atual.
2. Marca a entrada do livro com `deletedAt = now` (ou adiciona uma nova se
   nao existir).
3. Reescreve manifest.
4. Deleta o arquivo fisico em `books/`.

Outros dispositivos que sincronizarem depois veem a entrada tombstoned e
fazem `_deleteBookLocally` no proprio DB.

### Compactacao de tombstones zumbis

A manifest acumulava tombstones "zumbis": entradas com `deletedAt` cujo
`syncFileName` era o mesmo de um livro ativo em merged. Origem tipica:

1. Usuario deletou livro X em algum dispositivo → `deletedAt` + arquivo
   removido do Drive.
2. Se o `deleteFile` falhou por rede, arquivo ficou orfao no Drive.
3. Sync seguinte: `_autoImportOrphanFiles` viu o arquivo, nao encontrou na
   manifest como ativo (so tombstoned), importou como livro novo com
   **UUID novo** mas **mesmo syncFileName**.
4. Agora merged tem dois registros apontando pro mesmo filename: X-tombstone
   e Y-ativo.
5. `_uploadMissingEpubs` apagava o arquivo do tombstone (que era
   fisicamente o arquivo de Y), depois re-uploadava Y na proxima iteracao.
   Eterno flip-flop.

**Fix** (em `library_sync_service.sync()`): apos `mergeLibraries`, um step
de compactacao remove do manifest todo tombstone cujo `syncFileName` ja e
reivindicado por um livro ativo em merged. O ativo "herdou" a posse do
filename; o tombstone nao propaga nada util e so polui as comparacoes.

Tombstones **legitimos** (sem colisao de filename) ficam ate propagar pra
todos os devices. Nao ha GC por idade hoje — seria o proximo passo.

### Prevencao do re-import-como-orfao

`_autoImportOrphanFiles` ja trata `syncFileName` tombstonado na manifest
como "conhecido" (como se fosse ativo). Assim, um arquivo orfao com nome
igual a um tombstone nao vira um livro novo; o proximo `_uploadMissingEpubs`
respeita o tombstone e deleta o arquivo.

## Ordem da pipeline de sync

`LibrarySyncService.sync()`, em alto nivel:

```
┌ em paralelo ─────────────────────┐
│ 1a. isReadable(folder)           │
│ 1b. readText(library.json)       │   ← ~1.5s cada antes, agora ~max(1.5s)
│ 1c. listFiles(books/)            │
└──────────────────────────────────┘
2. autoImportOrphanFiles   ← so quando config.syncEpubs
3. buildLocalSnapshot
4. mergeLibraries + compactacao de zumbis
5. applyToLocal (progress + lastReadAt + tombstone deletes + placeholder imports)
6. writeManifest            ← SKIP se _libraryContentEquals(merged, remote)
7. uploadMissingEpubs       ← so quando config.syncEpubs
```

Todas as fases sao instrumentadas com `[sync] phase: Xms` em `debugPrint`
(e operacoes individuais do gateway como `[drive] writeBytes ...`). Filtre
no logcat com `grep '\[sync\]\|\[drive\]'`.

### Paralelizacao

As 3 leituras iniciais (isReadable, readManifest, listBooksDir) sao
independentes — disparadas juntas e aguardadas em sequencia de uso. Antes
era serial, pagando 3x a latencia.

### Skip do writeManifest

`_libraryContentEquals(merged, remote)` compara livros (ordenados por id,
JSON-encoded) e settings, **ignorando** `updatedAt`/`updatedBy` de manifest
(que mudam todo sync por natureza). Se identicos, o sync nao reescreve o
manifest — economiza ~2-3s por sync idle.

Quando nao bate, emite `[sync] diff: ...` com os JSONs divergentes —
facilita debug.

## Comparacao de DateTime

**Armadilha importante**: `DateTime.==` compara `(microsSinceEpoch, isUtc)`.
No nosso sync:

- Horarios **locais** vem do Drift, que por padrao armazena como unix
  seconds → reconstrui com `isUtc: false`.
- Horarios **remotos** vem do JSON manifest. `toJson` faz `toUtc()` antes
  do `toIso8601String()`, entao o parse resulta em `isUtc: true`.

Mesmo instante, `isUtc` diferente → `==` retorna `false`.

Em `_applyToLocal` isso causava um write pra cada livro todo sync (11
livros × ~60ms = 660ms jogados fora). **Use sempre `isAtSameMomentAs` para
comparar DateTimes que cruzam a fronteira local/remoto** — normaliza TZ.

O `_libraryContentEquals` nao sofre porque compara JSON encoding, que ja
passa por `toUtc()`.

## Cache de fileId (DriveSyncFolderGateway)

Qualquer operacao em um arquivo no Drive exige saber o `fileId`, e para
descobri-lo o gateway faz `api.files.list` filtrado por nome/pasta — uma
round-trip de ~500-700ms ("find" nos logs). Esse custo era pago antes de
cada `read`/`write`/`delete`.

`_fileIdCache` (keyed por `"<parentId>/<fileName>"`) e populado por:
- `_findFile` (quando precisa resolver na marra)
- `listFiles` (de gracca — a resposta ja traz id+name)
- branch "create" do `writeBytes` (acabou de criar, sabe o id)

Consumido por `readBytes`, `writeBytes`, `deleteFile` — se tiver cache,
pula o `_findFile`.

Invalidacao:
- `deleteFile` remove a entrada do cache.
- `clearCache()` dropa tudo (chamado no disconnect).
- **Nao** ha detection de renomeacao concorrente por outro device; na
  pratica o sync e efemero o suficiente pra isso nao ser problema.

## Orfaos na pasta `books/`

Se o usuario largar um EPUB direto na pasta do Drive (fora do app),
`_autoImportOrphanFiles` detecta no proximo sync:
- Filtra `.epub` (case-insensitive).
- Exclui filenames ja conhecidos (ativos + tombstones na manifest +
  `syncFileName`s locais).
- Exclui arquivos que falharam antes (`SyncImportFailuresDao` pra nao
  thrashar em EPUB corrompido).
- Import o resto como novos livros (UUID local novo), preservando o
  filename em `syncFileName` pra nao duplicar no proximo sync.

## Sync so de EPUB

`LibrarySyncService._buildLocalSnapshot` filtra `source == BookSource.epub`.
Artigos (`source == article`) sao **sempre locais**, nao participam do
sync. Razao: o manifest e um formato de biblioteca EPUB, e artigos
dependem de fetch de URL.

## Observabilidade

Quando o sync esta rodando, a UI mostra uma hairline de 2px logo abaixo
da TabBar da biblioteca (via `LibraryAppBarBottom` + `LibrarySyncState.stage
== SyncStage.syncing`). Durante auto-import de orfaos, a hairline e
substituida pela `LibraryImportProgressBar` mais detalhada.

Para diagnostico no dev, os logs `[sync]` / `[drive]` dao:
- Fase + duracao de cada etapa do pipeline.
- `writes: progress=N lastRead=N deletes=N imports=N` em `_applyToLocal`.
- `uploads=N deletes=N skippedTombstones=N` em `_uploadMissingEpubs`.
- `[sync] diff: ...` quando o skip do manifest falha.

## Arquivos chave

- `lib/features/library_sync/data/services/library_sync_service.dart` — o
  `sync()`, `pushTombstone()`, `_applyToLocal`, `_uploadMissingEpubs`,
  `_autoImportOrphanFiles`, `_libraryContentEquals`.
- `lib/features/library_sync/data/gateways/drive_sync_folder_gateway.dart`
  — wrapper da Drive API com caches (folder + file).
- `lib/features/library_sync/domain/entities/sync_library.dart` — schema
  + merge puro.
- `lib/features/library_sync/presentation/providers/library_sync_provider.dart`
  — notifier que debouncing pushes (2s), faz flush de pending deletes,
  serializa syncs concorrentes.
- `lib/features/library_sync/presentation/providers/drive_auth_provider.dart`
  — sign-in silencioso no startup, manipulacao de `http.Client`
  autenticado.
