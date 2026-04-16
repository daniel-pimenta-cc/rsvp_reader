// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'RSVP Reader';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Configurações';

  @override
  String get importBook => 'Importar Livro';

  @override
  String get emptyLibrary => 'Sua biblioteca está vazia';

  @override
  String get emptyLibrarySubtitle => 'Importe um EPUB para começar';

  @override
  String get deleteBook => 'Excluir Livro';

  @override
  String deleteBookConfirm(String title) {
    return 'Tem certeza que deseja excluir \"$title\"?';
  }

  @override
  String get markAsRead => 'Marcar como lido';

  @override
  String markedAsRead(String title) {
    return '\"$title\" marcado como lido';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get reading => 'Lendo';

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String wordsPerMinute(int wpm) {
    return '$wpm PPM';
  }

  @override
  String chapterOf(int current, int total) {
    return 'Capítulo $current de $total';
  }

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String minutesRemaining(int minutes) {
    return '~$minutes min';
  }

  @override
  String get settingsDisplay => 'Exibição';

  @override
  String get settingsFontSize => 'Tamanho da Fonte';

  @override
  String get settingsFontSizeRsvp => 'Fonte RSVP';

  @override
  String get settingsFontSizeContext => 'Fonte Leitura';

  @override
  String get settingsWordColor => 'Cor da Palavra';

  @override
  String get settingsOrpColor => 'Cor da Letra de Foco';

  @override
  String get settingsBackgroundColor => 'Cor de Fundo';

  @override
  String get settingsHighlightColor => 'Cor do Destaque';

  @override
  String get settingsVerticalPosition => 'Posição Vertical';

  @override
  String get settingsHorizontalPosition => 'Posição Horizontal';

  @override
  String get settingsFont => 'Fonte';

  @override
  String get settingsReading => 'Leitura';

  @override
  String get settingsDefaultSpeed => 'Velocidade Padrão';

  @override
  String get settingsSmartTiming => 'Timing Inteligente';

  @override
  String get settingsSmartTimingDesc =>
      'Ajusta a duração da palavra com base em pontuação e comprimento';

  @override
  String get settingsOrpHighlight => 'Letra de Foco';

  @override
  String get settingsOrpHighlightDesc =>
      'Destacar o ponto de reconhecimento ótimo em cada palavra';

  @override
  String get settingsRampUp => 'Aceleração Gradual';

  @override
  String get settingsRampUpDesc =>
      'Acelerar gradualmente até a velocidade alvo ao iniciar a leitura';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get themeModeSystem => 'Sistema';

  @override
  String get themeModeLight => 'Claro';

  @override
  String get themeModeDark => 'Escuro';

  @override
  String get readerPlaceholderTitle => 'Escolha um livro pra começar';

  @override
  String get readerPlaceholderSubtitle =>
      'Selecione da sua biblioteca à esquerda e ele abre aqui do lado.';

  @override
  String get importArticleClipboardHint => 'Colado da área de transferência';

  @override
  String get importing => 'Importando...';

  @override
  String get importError => 'Falha ao importar livro';

  @override
  String get importArticle => 'Importar artigo';

  @override
  String get importArticleUrlLabel => 'URL do artigo';

  @override
  String get importArticleUrlHint => 'https://exemplo.com/artigo';

  @override
  String get importArticleCta => 'Importar';

  @override
  String get importArticleError => 'Falha ao importar artigo';

  @override
  String get importArticleFetching => 'Baixando artigo…';

  @override
  String get libraryTabBooks => 'Livros';

  @override
  String get libraryTabArticles => 'Artigos';

  @override
  String get emptyArticles => 'Nenhum artigo ainda';

  @override
  String get emptyArticlesSubtitle =>
      'Cole uma URL pra ler qualquer artigo da web em RSVP';

  @override
  String get bookFinished => 'Você terminou o livro!';

  @override
  String get tapToPause => 'Toque para pausar';

  @override
  String get tapToResume => 'Toque para retomar';

  @override
  String get switchToEreaderMode => 'Modo leitura';

  @override
  String get switchToRsvpMode => 'Modo RSVP';

  @override
  String get settingsFocusLine => 'Linha de foco';

  @override
  String get settingsFocusLineDesc =>
      'Exibe uma linha fina abaixo da palavra para ancorar o olhar';

  @override
  String get settingsFocusLineProgress => 'Progresso na linha de foco';

  @override
  String get settingsFocusLineProgressDesc =>
      'Usa a linha de foco também para mostrar o progresso de leitura';

  @override
  String get librarySectionInProgress => 'Em progresso';

  @override
  String get librarySectionNotStarted => 'Não iniciados';

  @override
  String get librarySectionRead => 'Lidos';

  @override
  String get settingsSync => 'Sincronização da biblioteca';

  @override
  String get syncChooseFolder => 'Escolher pasta de sincronização';

  @override
  String get syncFolderLabel => 'Pasta';

  @override
  String get syncNoFolderSelected => 'Nenhuma pasta selecionada';

  @override
  String get syncEpubFiles => 'Sincronizar arquivos EPUB';

  @override
  String get syncEpubFilesDesc =>
      'Copia os arquivos EPUB para a pasta de sincronização, fazendo com que apareçam em outros dispositivos. Desligue para economizar espaço na nuvem.';

  @override
  String get syncAutoSync => 'Sincronização automática';

  @override
  String get syncAutoSyncDesc =>
      'Sincroniza automaticamente ao abrir o app e quando o progresso muda.';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get syncInProgress => 'Sincronizando…';

  @override
  String syncLastSyncedAt(String when) {
    return 'Última sincronização: $when';
  }

  @override
  String get syncNever => 'Nunca';

  @override
  String syncFailed(String error) {
    return 'Falha ao sincronizar: $error';
  }

  @override
  String get syncDisconnect => 'Desconectar pasta';

  @override
  String syncFailedImportsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos falharam ao importar',
      one: '1 arquivo falhou ao importar',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedImportsHelp =>
      'Esses arquivos estão sendo ignorados. Apague ou substitua eles na pasta de sincronização e toque em Tentar de novo.';

  @override
  String get syncRetry => 'Tentar de novo';

  @override
  String syncImportingProgress(int current, int total, String fileName) {
    return 'Importando $current de $total: $fileName';
  }

  @override
  String get syncHelp =>
      'Escolha uma pasta local no seu aparelho. O app salva sua biblioteca lá como arquivos JSON + EPUB. Pra sincronizar entre dispositivos, aponte um app de sincronização pra essa pasta — por exemplo Autosync ou FolderSync (Android) espelhando com Google Drive / Dropbox / OneDrive / MEGA, ou Syncthing pra sincronizar direto entre seus próprios dispositivos (peer-to-peer, sem nuvem no meio).';
}
