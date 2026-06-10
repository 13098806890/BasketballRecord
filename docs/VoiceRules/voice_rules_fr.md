# French Voice Rules Analysis

## ASR Locale
- `fr-FR` — primary; `fr-CA`/`fr-BE` would share nearly identical rules

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `deux` / `deux points` / `2` | stat.two | |
| `trois` / `trois points` / `3` | stat.three | |
| `lay-up` / `couche` | stat.layup | "couche" is a common colloquial shortening |
| `mi-distance` / `moyenne distance` | stat.midRange | |
| `intérieur` | stat.paint | |
| `lancer franc` / `lancer` | stat.freeThrow | |
| `panier` | stat.two | General "basket" — treated as two by default |
| `bonus` / `et un` | stat.bonus | |

"panier" alone (without "deux" or "trois") defaults to two points.

## Made / Missed States

| Spoken | Type |
|---|---|
| `marqué` / `dedans` / `dans` / `bon` / `réussi` | made |
| `raté` / `dehors` / `loupé` / `contré` / `manqué` / `bloqué` | missed |

"oui" is ambiguous in ASR context — skip.

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `faute` | stat.foul | |
| `rebond` / `rebond offensif` / `rebond défensif` | stat.rebound | |
| `passe` / `passe décisive` | stat.assist | |
| `contre` | stat.block | |
| `interception` | stat.steal | |
| `perte de balle` / `marcher` / `marche` / `double dribble` | stat.turnover | "marcher" and "marche" both mean traveling |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `début` / `coup d'envoi` / `premier quart` / `premier quart-temps` | event.period | |
| `pause` / `arrêter` / `temps mort` | event.pause | |
| `continuer` / `reprise` / `reprendre` | event.pause | |
| `fin` / `fin du match` | event.game_end | |

## Substitution Keywords

`remplacement` / `changement` / `substitution` / `remplace`

Number formats supported via `extractNumber`:
- `#5` / `numéro 5` / `no.5`
- `5` alone (standalone digit)

## Fuzzy Map
French — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `panier` vs `lancer franc` — panier is generic (defaults to two), lancer franc is specific to free throws
2. `bonus` is a basketball loanword — no false matches in French
3. `fin` is short — ensure "fin du match" is tried first for exact match before generic "fin"
4. `contre` as block stat vs `contré` as missed state — "bloqué" is preferred for missed state to avoid overlap
