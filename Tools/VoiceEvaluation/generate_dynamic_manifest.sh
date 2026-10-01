#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
base_manifest="${1:-$script_dir/manifest.tsv}"
output_manifest="${2:-$script_dir/manifest-with-dynamic.tsv}"
seed="${3:-$EPOCHSECONDS}"
locales=(zh-Hans zh-Hant-TW en de es fr it ja ko ru)
actions=(two-made two-missed three-made three-missed bonus-made bonus-missed free-throw-made free-throw-missed layup-made layup-missed mid-range-made mid-range-missed paint-made paint-missed putback-made putback-missed dunk-made dunk-missed foul rebound offensive-rebound defensive-rebound assist block steal turnover assist-two assist-three steal-turnover substitution start pause game-end undo redo)

number_phrase() {
    local locale="$1"
    local number="$2"
    case "$locale" in
        zh-Hans) print -r -- "${number}号" ;;
        zh-Hant-TW) print -r -- "${number}號" ;;
        ja) print -r -- "背番号${number}番の選手" ;;
        ko) print -r -- "등번호 ${number}번 선수" ;;
        en) print -r -- "number ${number}" ;;
        de) print -r -- "Nummer ${number}" ;;
        es) print -r -- "número ${number}" ;;
        fr) print -r -- "numéro ${number}" ;;
        it) print -r -- "numero ${number}" ;;
        ru) print -r -- "номер ${number}" ;;
        *) print -r -- "number ${number}" ;;
    esac
}

filler() {
    local locale="$1"
    local index="$2"
    case "$locale:$((index % 3))" in
        zh-Hans:0) print -r -- '现在' ;;
        zh-Hans:1) print -r -- '请记录' ;;
        zh-Hans:2) print -r -- '这次' ;;
        zh-Hant-TW:0) print -r -- '現在' ;;
        zh-Hant-TW:1) print -r -- '請記錄' ;;
        zh-Hant-TW:2) print -r -- '這次' ;;
        en:0) print -r -- 'please' ;;
        en:1) print -r -- 'now' ;;
        en:2) print -r -- 'this time' ;;
        de:0) print -r -- 'bitte' ;;
        de:1) print -r -- 'jetzt' ;;
        de:2) print -r -- 'im Spiel' ;;
        es:0) print -r -- 'ahora' ;;
        es:1) print -r -- 'por favor' ;;
        es:2) print -r -- 'en el partido' ;;
        fr:0) print -r -- 'maintenant' ;;
        fr:1) print -r -- 's’il te plaît' ;;
        fr:2) print -r -- 'dans le match' ;;
        it:0) print -r -- 'adesso' ;;
        it:1) print -r -- 'per favore' ;;
        it:2) print -r -- 'in partita' ;;
        ja:0) print -r -- 'お願いします' ;;
        ja:1) print -r -- '今' ;;
        ja:2) print -r -- '今回' ;;
        ko:0) print -r -- '해주세요' ;;
        ko:1) print -r -- '지금' ;;
        ko:2) print -r -- '이번에' ;;
        ru:0) print -r -- 'сейчас' ;;
        ru:1) print -r -- 'пожалуйста' ;;
        ru:2) print -r -- 'в этой атаке' ;;
        *) print -r -- '' ;;
    esac
}

row_for() {
    local locale="$1"
    local action="$2"
    local mode="$3"
    local key="$locale-$action"
    if [[ "$mode" == "number" ]]; then
        key="$key-number"
    fi
    awk -F '\t' -v key="$key" '$1 == key { print; exit }' "$base_manifest"
}

names_for() {
    local locale="$1"
    awk -F '\t' -v locale="$locale" '
        NR > 1 && $2 == locale {
            if ($9 != "" && !seen[$9]++) print $9
            if ($12 != "" && !seen[$12]++) print $12
        }
    ' "$base_manifest"
}

replace_name() {
    local value="$1"
    local old="$2"
    local new="$3"
    if [[ -n "$old" ]]; then
        value="${value//$old/$new}"
    fi
    print -r -- "$value"
}

mkdir -p "${output_manifest:h}"
head -n 1 "$base_manifest" > "$output_manifest"
tail -n +2 "$base_manifest" >> "$output_manifest"
RANDOM=$((seed % 32768))

for locale in $locales; do
    names=("${(@f)$(names_for "$locale")}")
    (( ${#names} >= 2 )) || continue
    for ((i = 1; i <= 35; i++)); do
        action_index=$(( ((i - 1 + RANDOM) % ${#actions}) + 1 ))
        action="${actions[$action_index]}"
        mode="canonical"
        if [[ "$action" != start && "$action" != pause && "$action" != game-end && "$action" != undo && "$action" != redo ]]; then
            if (( RANDOM % 2 == 0 )); then mode="number"; fi
        fi
        source_row="$(row_for "$locale" "$action" "$mode")"
        [[ -n "$source_row" ]] || continue
        tab=$'\t'
        separator=$'\x1f'
        source_row="${source_row//$tab/$separator}"
        IFS="$separator" read -rA source_fields <<< "$source_row"
        source_id="${source_fields[1]}"
        source_locale="${source_fields[2]}"
        category="${source_fields[3]}"
        variant="${source_fields[4]}"
        voice="${source_fields[5]}"
        text="${source_fields[6]}"
        zh="${source_fields[7]}"
        event="${source_fields[8]}"
        old_player="${source_fields[9]}"
        gender="${source_fields[10]}"
        script="${source_fields[11]}"
        old_related="${source_fields[12]}"
        wav="${source_fields[13]}"
        player_index=$(( (RANDOM % ${#names}) + 1 ))
        player="${names[$player_index]}"
        related_index=""
        related=""
        if [[ -n "$old_related" ]]; then
            related_index="$player_index"
            while [[ "$related_index" == "$player_index" ]]; do
                related_index=$(( (RANDOM % ${#names}) + 1 ))
            done
            related="${names[$related_index]}"
        fi
        if [[ "$action" == start || "$action" == pause || "$action" == game-end || "$action" == undo || "$action" == redo ]]; then
            player=""
            related=""
        elif [[ "$mode" == "canonical" ]]; then
            text="$(replace_name "$text" "$old_player" "$player")"
            zh="$(replace_name "$zh" "$old_player" "$player")"
            if [[ -n "$old_related" ]]; then
                text="$(replace_name "$text" "$old_related" "$related")"
                zh="$(replace_name "$zh" "$old_related" "$related")"
            fi
        elif [[ "$locale" == "ja" || "$locale" == "ko" ]]; then
            text="$(replace_name "$text" "$old_player" "$player")"
            zh="$(replace_name "$zh" "$old_player" "$player")"
            if [[ -n "$old_related" ]]; then
                text="$(replace_name "$text" "$old_related" "$related")"
                zh="$(replace_name "$zh" "$old_related" "$related")"
            fi
        else
            old_player_index=0
            old_related_index=0
            base_names=("${(@f)$(names_for "$locale")}")
            for ((j = 1; j <= ${#base_names}; j++)); do
                [[ "${base_names[$j]}" == "$old_player" ]] && old_player_index=$j
                [[ -n "$old_related" && "${base_names[$j]}" == "$old_related" ]] && old_related_index=$j
            done
            old_number="$(number_phrase "$locale" "$old_player_index")"
            new_number="$(number_phrase "$locale" "$player_index")"
            text="${text//$old_number/$new_number}"
            zh="${zh//$old_number/$new_number}"
            if [[ -n "$old_related" ]]; then
                old_related_number="$(number_phrase "$locale" "$old_related_index")"
                new_related_number="$(number_phrase "$locale" "$related_index")"
                text="${text//$old_related_number/$new_related_number}"
                zh="${zh//$old_related_number/$new_related_number}"
            fi
            zh="$(replace_name "$zh" "$old_player" "$player")"
            if [[ -n "$old_related" ]]; then
                zh="$(replace_name "$zh" "$old_related" "$related")"
            fi
        fi
        extra="$(filler "$locale" "$i")"
        [[ -n "$extra" ]] && text="$text $extra"
        case_id="${locale}-dynamic-${seed}-${i}"
        dynamic_variant="dynamic-${mode}"
        if [[ -n "$player" ]]; then
            player_gender="$gender"
            player_script="$script"
        else
            player_gender=""
            player_script=""
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_id" "$locale" "$category" "$dynamic_variant" "$voice" "$text" "$zh" "$event" "$player" "$player_gender" "$player_script" "$related" "$case_id.wav" >> "$output_manifest"
    done
done
