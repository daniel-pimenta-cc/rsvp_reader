# Tasks

## Bugs
- [x] Scroll travado no modo contexto — precisa rolar suave como manteiga
- [x] Ao pausar, o texto volta para o início ao invés de focar na palavra atual (resolvido junto com o fix do scroll)
- [x] Botão de configurações no leitor não abre nada
- [x] Tags de estilo do EPUB vazando no texto (CSS aparecendo entre capítulos com imagens) — `HtmlStripper._skipTags`

## Features
- [x] Ramp-up de velocidade — ao dar play, começar mais devagar e acelerar gradualmente até o WPM desejado ao invés de começar na velocidade máxima direto
- [x] Navegação por capítulos — ter uma forma clara de visualizar a lista de capítulos e navegar entre eles
- [x] Modo ereader — terceiro modo de leitura sem highlight nem controles (ebook tradicional)
- [x] Marcadores de capítulo no slider de progresso (com tooltip do título via value indicator)
- [x] Linha de foco abaixo da palavra (modo focus puro ou focus + progresso, configurável)

## Polish
- [x] Polir scroll do modo contexto — velocity-based stepping (word/sentence/paragraph), highlight em pill com glow sutil, dead zone para seleção fina
- [x] Preview de fonte no settings (cada item do dropdown renderizado na própria fonte + linha de amostra)
- [x] Consolidar telas de configuração (DisplaySettingsPanel compartilhado entre bottom sheet e tela full-screen)

## Pendente
- [ ] _(adicionar próximas features aqui)_
