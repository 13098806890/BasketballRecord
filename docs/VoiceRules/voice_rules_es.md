# Spanish Voice Rules Analysis

## ASR Locale
- `es-ES`; `es-MX`/`es-AR` would share nearly identical rules

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `dos` / `dos puntos` / `2` | stat.two | |
| `tres` / `tres puntos` / `3` | stat.three | |
| `bandeja` | stat.layup | |
| `media` / `media distancia` | stat.midRange | |
| `pintura` / `interior` | stat.paint | |
| `tiro libre` / `libre` | stat.freeThrow | |
| `bonus` / `y uno` | stat.bonus | |

## Made / Missed States

| Spoken | Type |
|---|---|
| `encestado` / `dentro` / `bueno` / `canasta` | made |
| `fallado` / `fuera` / `bloqueado` / `perdido` | missed |

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `falta` | stat.foul | |
| `rebote` / `rebote ofensivo` / `rebote defensivo` | stat.rebound | |
| `asistencia` | stat.assist | |
| `bloqueo` | stat.block | |
| `robo` | stat.steal | |
| `perdida` / `pasos` / `doble dribble` | stat.turnover | "pasos" = traveling |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `inicio` / `primer cuarto` | event.period | |
| `pausa` / `tiempo muerto` | event.pause | |
| `continuar` / `reanudar` | event.pause | |
| `final` / `fin del partido` | event.game_end | |

## Substitution Keywords

`cambio` / `sustitución` / `reemplazo` / `sustituye`

Number formats supported via `extractNumber`:
- `#5` / `número 5`
- `5` alone (standalone digit)

## Fuzzy Map
Spanish — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `media` as mid-range shot vs `media` as "half" — in basketball context, "media distancia" is common enough; standalone "media" might rarely be confused
2. `final` vs `fin del partido` — exact match first, partial match second; both resolve to game_end correctly
