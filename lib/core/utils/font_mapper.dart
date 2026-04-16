/// Maps the persisted font-family identifier (camelCase, no spaces) to the
/// name expected by the `google_fonts` package. Centralised here so the
/// three places that resolve font families (RSVP word display, context scroll
/// view, display-settings preview) stay in sync.
String mapFontFamily(String family) {
  switch (family) {
    case 'RobotoMono':
      return 'Roboto Mono';
    case 'JetBrainsMono':
      return 'JetBrains Mono';
    case 'FiraCode':
      return 'Fira Code';
    case 'SourceCodePro':
      return 'Source Code Pro';
    case 'Lora':
      return 'Lora';
    case 'SourceSerif4':
      return 'Source Serif 4';
    default:
      return 'Roboto Mono';
  }
}
