# Motor RSVP

## Ticker vs Timer

Usa `Ticker` (nao `Timer.periodic`). Vantagens:
- Sincronizado com refresh rate da tela (60fps)
- Automaticamente pausado quando app vai para background
- Precisao superior para 600+ WPM (~100ms por palavra)

## Ciclo principal

```
_onTick(elapsed):
  if elapsed >= _nextWordAt:
    _advanceWord()        // muda para proxima palavra
    _wordsInSession++     // conta para ramp-up
    _scheduleNext()       // calcula quando exibir a proxima

_scheduleNext():
  effectiveWpm = _effectiveWpm()          // com ramp-up
  baseMs = 60000 / effectiveWpm
  multiplier = smartTiming ? word.timingMultiplier : 1.0
  _nextWordAt = _elapsed + baseMs * multiplier
```

## ORP (Optimal Recognition Point)

Arquivo: `lib/core/utils/orp_calculator.dart`

Posicao da letra de foco dentro da palavra (~30% do inicio). Lookup table para 1-13 chars, formula `floor(len * 0.35)` para maiores. Unicode-aware (acentos PT-BR).

| Comprimento | ORP Index | Exemplo |
|---|---|---|
| 1 | 0 | **e** |
| 2-3 | 0 | **o**f |
| 4-5 | 1 | w**o**rld |
| 6-8 | 2 | le**i**tura |
| 9-11 | 3 | apr**e**sentar |
| 12-13 | 4 | apre**s**entacao |
| 14+ | floor(len * 0.35) | — |

## Word Timing

Arquivo: `lib/core/utils/word_timing.dart`

Multiplicadores sobre `60000ms / WPM`:

| Contexto | Multiplicador |
|---|---|
| Palavra curta (<=3) | 0.9x |
| Palavra longa (>6) | +0.1x por char extra |
| `.` `!` `?` | 2.0x |
| `,` `;` | 1.5x |
| `:` | 1.8x |
| `...` | 2.5x |
| Inicio paragrafo | 1.5x |
| Inicio capitulo | 3.0x |

Clamp final: 0.5x — 5.0x. Toggle `smartTiming` desativa os multiplicadores.

## Ramp-Up

Opcional (toggle nas configs, default ON). Ao dar play:
- Comeca em `rampUpStartFraction` (70%) do WPM alvo
- Acelera linearmente ao longo de `rampUpWords` (30) palavras
- Reseta a cada play

```
effectiveWpm = startWpm + (targetWpm - startWpm) * (wordsInSession / rampUpWords)
```

Constantes em `AppConstants`.

## Auto-Scale de palavras longas

No `RsvpWordDisplay`, se a palavra nao cabe na largura disponivel com a fonte configurada, a fonte e reduzida de 2 em 2 (minimo 16px) ate caber. Isso evita corte em palavras longas do portugues.

## Modos de leitura

3 modos no enum `ReaderMode`:

- **`rsvp`**: palavra unica com ORP. Ativo durante play.
- **`scroll`**: texto completo com highlight (pill arredondada com glow sutil). Ativo ao pausar ou ao abrir livro. Suporta tap-to-seek em qualquer palavra.
- **`ereader`**: texto completo sem highlight, sem controles. Leitura tradicional (ebook). Toggleavel por icone no top bar.

Transicoes:
- Play/pause: alterna `rsvp` ↔ `scroll`. AnimatedSwitcher com fade 200ms.
- Toggle ereader (via top bar): `engine.toggleEreaderMode()`. Ao entrar, pausa o ticker e salva progresso. Ao sair, volta para `scroll`.
- `RsvpControls` so e renderizado quando `mode != ereader`.

### Velocity-based scroll tracking

O `ContextScrollView` rastreia velocidade do scroll via `ScrollUpdateNotification.scrollDelta` e suaviza com EMA (`0.7 * anterior + 0.3 * novo`). Throttle de 80ms entre updates. Granularidade depende de `|velocity|`:

| Velocidade | Stepping |
|---|---|
| `< 0.3` | dead zone (ignora) |
| `0.3 - 8` | palavra por palavra |
| `8 - 25` | frase por frase (`.` `!` `?`) |
| `> 25` | paragrafo por paragrafo |

Boundaries de paragrafo/frase pre-computadas em `_paragraphBoundaries` e `_sentenceBoundaries` na construcao da lista (binary search no lookup). Catch-up: se o highlight sai da viewport, snapa para o paragrafo no centro (40% da altura).

O scroll view usa `ValueNotifier<int>` local para o highlight (nao Riverpod) — evita rebuild cascade durante scroll. Sync com engine acontece so no `ScrollDirection.idle`.

## Focus line

Linha horizontal opcional abaixo da palavra no modo RSVP. Configurada por dois flags em `DisplaySettings`:

- `showFocusLine` (default `true`): liga/desliga a linha
- `focusLineShowsProgress` (default `true`): track + parte preenchida (cor `orpColor`) proporcional a `globalWordIndex / totalWords`

Quando `focusLineShowsProgress = false`, a linha e renderizada solida em `wordColor.withAlpha(60)` — apenas ancora visual para o olhar.

A linha vai de borda a borda da tela (`left: 0, right: 0`). Por isso o `RsvpWordDisplay` aplica internamente toda a margem horizontal para a palavra (`margin = 32`) — o widget pai NAO deve adicionar Padding lateral, ou a linha ficaria com gap visivel das laterais.
