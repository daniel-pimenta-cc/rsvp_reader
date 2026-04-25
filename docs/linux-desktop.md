# Linux desktop

Versão desktop GTK do RSVP Reader. Compartilha 100% do código Dart com Android/iOS — só o shell nativo (CMake + GTK em `linux/`) e alguns guards de plataforma são específicos.

## Pré-requisitos

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

(Em distros que ainda usam GCC 11, troque `libstdc++-12-dev` pelo equivalente.)

## Rodar e buildar

```bash
flutter run -d linux                  # debug
flutter build linux --release         # bundle em build/linux/x64/release/bundle/rsvp_reader
```

A janela abre em 1280×800 (mínimo 800×600). Título e tamanho são definidos em `linux/runner/my_application.cc`.

## Capacidades por plataforma

`lib/core/utils/platform_capabilities.dart` é a fonte única da verdade. Use os getters em vez de espalhar `Platform.isLinux` pelo código:

| Capability | Android | iOS | Linux |
|---|---|---|---|
| `supportsShareIntent` (receive_sharing_intent) | ✓ | ✓ | ✗ |
| `supportsDriveSync` (google_sign_in + Drive) | ✓ | ✗ | ✗ |
| `isDesktop` (DropTarget, atalhos) | ✗ | ✗ | ✓ |

Em Linux, a seção **Sync** das Settings não aparece e `_initialSync` em `main.dart` é pulado.

## Atalhos de teclado (reader)

Ativos só em desktop, ligados via `CallbackShortcuts` em `RsvpReaderScreen`:

| Tecla | Ação |
|---|---|
| `Space` | play/pause |
| `←` / `→` | volta/avança 1 palavra |
| `Shift+←` / `Shift+→` | volta/avança `AppConstants.skipWordCount` palavras |
| `↑` / `↓` | WPM ± `AppConstants.wpmStep` |
| `Esc` | volta pra biblioteca (ou fecha o split-view) |

## Drag-and-drop

`DesktopDropHandler` (em `lib/core/share/desktop_drop_handler.dart`) envolve toda a árvore via `MaterialApp.builder`. Aceita:

- **`.epub`**: chama `EpubImportNotifier.importFromPath`, passando pelo mesmo pipeline (`persistParsedBook`) do `file_picker`.
- **URL / texto contendo URL**: usa `UrlUtils.extractHttpUrl` e dispara `articleImportProvider.importFromUrl`. Mesmo pipeline da janela "Importar URL".

## Limitações conhecidas

- **Sync via Google Drive**: indisponível. Implementar exigirá fluxo OAuth loopback (servidor local em `localhost`) usando `googleapis_auth` direto, em vez do `google_sign_in`. Ficou pra um PR posterior.
- **Share-sheet do sistema**: `receive_sharing_intent` não tem binding Linux. Sem registro de URL/MIME handler — pra importar artigo, abra o app e use o dialog "Importar URL" (ou arraste a URL na janela).
- **Packaging**: ainda não há AppImage/Flatpak/Snap; o build produz só o bundle bruto em `build/linux/x64/release/bundle/`.
- **Storage**: `path_provider` resolve para `~/.local/share/rsvp_reader/` em Linux (XDG). O DB e os EPUBs ficam lá.
