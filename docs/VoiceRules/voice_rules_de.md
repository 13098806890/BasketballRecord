# German Voice Rules Analysis

## ASR Locale
- `de-DE`

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `zwei` / `2` / `zwei punkte` | stat.two | |
| `drei` / `3` / `drei punkte` / `dreier` | stat.three | "Dreier" is very common |
| `layup` | stat.layup | |
| `mitteldistanz` / `mittlerer` | stat.midRange | middle distance |
| `korb` / `korb nähe` | stat.paint | "basket" / near basket |
| `freiwurf` | stat.freeThrow | free throw |
| `bonus` / `and one` | stat.bonus | |

## Made / Missed States

| Spoken | Type |
|---|---|
| `getroffen` / `drin` / `gut` / `reingeht` / `rein` | made |
| `verfehlt` / `daneben` / `blockiert` / `nicht` / `vorbei` | missed |

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `foul` / `foul` | stat.foul | |
| `rebound` / `abpraller` | stat.rebound | |
| `assist` / `vorlage` | stat.assist | |
| `block` / `block` | stat.block | |
| `steal` / `diebstahl` | stat.steal | |
| `turnover` / `ballverlust` / `übertreten` / `schrittfehler` | stat.turnover | step violation |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `start` / `anpfiff` / `erste viertel` | event.period | |
| `pause` / `auszeit` | event.pause | timeout |
| `weiter` / `weiterspielen` | event.pause | continue |
| `ende` / `spielende` / `schluss` | event.game_end | |

## Substitution Keywords
`wechsel` / `auswechslung` / `ersetzen` / `rein` / `raus`

Number format: Supported via generic extractNumber (standalone digits).

## Fuzzy Map
Empty.

## Recommendations
1. Add `dreier`, `dreipunkt` for three
2. Add `rein` (in) to made states
3. Add `schrittfehler` (traveling), `ballverlust` (turnover) to stat events
4. Keep game_end
