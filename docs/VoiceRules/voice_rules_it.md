# Italian Voice Rules Analysis

## ASR Locale
- `it-IT`

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `due` / `due punti` / `2` | stat.two | |
| `tre` / `tre punti` / `3` | stat.three | |
| `layup` | stat.layup | English loanword used in Italian basketball |
| `media` / `media distanza` | stat.midRange | |
| `dentro` / `pitturato` | stat.paint | "pitturato" = painted area |
| `tiro libero` / `libero` | stat.freeThrow | |
| `bonus` / `e uno` | stat.bonus | |

## Made / Missed States

| Spoken | Type |
|---|---|
| `segnato` / `dentro` / `buono` / `fatto` | made |
| `sbagliato` / `fuori` / `bloccato` / `mancato` | missed |

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `fallo` | stat.foul | |
| `rimbalzo` / `rimbalzo offensivo` / `rimbalzo difensivo` | stat.rebound | |
| `assist` | stat.assist | |
| `stoppata` | stat.block | |
| `palla rubata` | stat.steal | |
| `perse` / `passi` / `doppio dribbling` | stat.turnover | "passi" = traveling, "doppio dribbling" = double dribble |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `inizio` / `primo quarto` | event.period | |
| `pausa` / `timeout` | event.pause | |
| `continuare` / `riprendere` | event.pause | |
| `fine` / `fine partita` | event.game_end | |

## Substitution Keywords

`cambio` / `sostituzione` / `sostituisci` / `entra`

Number formats supported via `extractNumber`:
- `#5` / `numero 5`
- `5` alone (standalone digit)

## Fuzzy Map
Italian — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `dentro` as made state vs `dentro` as paint keyword — shot matching runs first (determines shot type), then player resolution runs on left/right text tokens; "dentro" in "dentro pitturato" would match paint first via shot keyword matching
2. `fine` alone is short — ensure longer phrases like "fine partita" are tried first
