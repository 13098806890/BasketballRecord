#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
manifest_path="${1:-$script_dir/manifest.tsv}"
output_dir="${2:-${TMPDIR:-/tmp}/basketballrecord-voice-evaluation}"

mkdir -p "$output_dir"

tail -n +2 "$manifest_path" | while IFS=$'\t' read -r case_id locale category variant voice localized_text zh_translation expected_event expected_player player_gender name_script expected_related_player wav_file; do
    aiff_path="$output_dir/$case_id.aiff"
    wav_path="$output_dir/$case_id.wav"
    spoken_text="$localized_text"
    case "$locale" in
        zh-Hans|zh-Hant-TW)
            if [[ "$spoken_text" == *[A-Za-z]* ]]; then
                spoken_text="${spoken_text//王Emma/王 Emma}"
                spoken_text="${spoken_text//王 Emma/王 Emma}"
                segment_dir="$output_dir/.segments"
                mkdir -p "$segment_dir"
                concat_list="$segment_dir/$case_id.txt"
                : > "$concat_list"
                segment_index=0
                for segment in ${(z)spoken_text}; do
                    segment_index=$((segment_index + 1))
                    segment_aiff="$segment_dir/$case_id-$segment_index.aiff"
                    if [[ "$segment" != *[!A-Za-z0-9-]* ]]; then
                        segment_voice="Samantha"
                    else
                        segment_voice="$voice"
                    fi
                    say -v "$segment_voice" -r 165 -o "$segment_aiff" "$segment"
                    printf "file '%s'\n" "${segment_aiff:A}" >> "$concat_list"
                done
                ffmpeg -nostdin -loglevel error -y -f concat -safe 0 -i "$concat_list" -ac 1 -ar 16000 -c:a pcm_s16le "$wav_path"
            else
                say -v "$voice" -r 165 -o "$aiff_path" "$spoken_text"
            fi
            ;;
        ja|ko)
            spoken_text="${spoken_text// /}"
            say -v "$voice" -r 175 -o "$aiff_path" "$spoken_text"
            ;;
        *)
            say -v "$voice" -r 175 -o "$aiff_path" "$spoken_text"
            ;;
    esac
    if [[ -f "$wav_path" ]]; then
        :
    elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -nostdin -loglevel error -y -i "$aiff_path" -ac 1 -ar 16000 -c:a pcm_s16le "$wav_path"
    else
        afconvert -f WAVE -d LEI16@16000 "$aiff_path" "$wav_path"
    fi
    if [[ -f "$aiff_path" ]]; then
        rm "$aiff_path"
    fi
    printf '%s\t%s\n' "$case_id" "$wav_path"
done
