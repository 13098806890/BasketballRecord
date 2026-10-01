#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h:h}"
manifest_path="${VOICE_ASR_EVAL_MANIFEST:-$script_dir/manifest.tsv}"
audio_dir="${VOICE_ASR_EVAL_AUDIO_DIR:-${TMPDIR:-/tmp}/basketballrecord-voice-evaluation}"
engine_names="${VOICE_ASR_EVAL_ENGINES:-speechTranscriber}"
if [[ "${VOICE_ASR_EVAL_INCLUDE_LEGACY_BASELINE:-0}" == "1" && "$engine_names" != *"legacySpeech"* ]]; then
    engine_names="legacySpeech,$engine_names"
fi
locale_names="${VOICE_ASR_EVAL_LOCALES:-}"
destination="${VOICE_ASR_EVAL_DESTINATION:-platform=iOS Simulator,name=iPhone 18 Pro Max}"
derived_data_path="$(mktemp -d /tmp/basketballrecord-voice-derived.XXXXXX)"
output_path="${VOICE_ASR_EVAL_OUTPUT:-$audio_dir/results.csv}"
release_all_locales="${VOICE_ASR_EVAL_RELEASE_ALL_LOCALES:-0}"
test_log_path="$audio_dir/test-output.log"
development_team="${VOICE_ASR_EVAL_DEVELOPMENT_TEAM:-}"
build_settings=()

mkdir -p "$audio_dir" "${output_path:h}"

if [[ -n "$development_team" ]]; then
    build_settings+=("DEVELOPMENT_TEAM=$development_team")
fi

first_wav="$(awk -F '\t' 'NR == 2 { print $13 }' "$manifest_path")"
if [[ -z "$first_wav" || ! -f "$audio_dir/$first_wav" ]]; then
    "$script_dir/generate_recordings.sh" "$manifest_path" "$audio_dir"
fi

xcodebuild \
    -project "$project_dir/BasketballRecord.xcodeproj" \
    -scheme BasketballRecord \
    -destination "$destination" \
    -derivedDataPath "$derived_data_path" \
    "${build_settings[@]}" \
    build-for-testing

xctestrun_source="$(find "$derived_data_path/Build/Products" -name '*.xctestrun' -print -quit)"
xctestrun_path="$derived_data_path/Build/Products/BasketballRecord_voice_evaluation.xctestrun"
cp "$xctestrun_source" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_AUDIO_DIR' -string "$audio_dir" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_MANIFEST' -string "$manifest_path" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_ENGINES' -string "$engine_names" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_OUTPUT' -string "$output_path" "$xctestrun_path"
if [[ "$release_all_locales" == "1" ]]; then
    plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_RELEASE_ALL_LOCALES' -string "1" "$xctestrun_path"
fi
if [[ -n "$locale_names" ]]; then
    plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_LOCALES' -string "$locale_names" "$xctestrun_path"
fi

xcodebuild \
    test-without-building \
    -xctestrun "$xctestrun_path" \
    -destination "$destination" \
    -only-testing:BasketballRecordTests/VoiceASRFileTranscriptionTests/testConfiguredWAVCorpusIsReadable \
    -only-testing:BasketballRecordTests/VoiceASRFileTranscriptionTests/testConfiguredFileCorpus \
    2>&1 | tee "$test_log_path"

if rg -q 'VOICE_ASR_HEADER,' "$test_log_path"; then
    {
        rg 'VOICE_ASR_HEADER,' "$test_log_path" | tail -n 1 | sed 's/.*VOICE_ASR_HEADER,//'
        rg 'VOICE_ASR_RESULT,' "$test_log_path" | sed 's/.*VOICE_ASR_RESULT,//'
    } > "$output_path"
fi

rg 'VOICE_ASR_UNAVAILABLE,' "$test_log_path" > "$audio_dir/unavailable.txt" || true
rg 'VOICE_ASR_DIAGNOSTIC,' "$test_log_path" > "$audio_dir/diagnostics.log" || true

if [[ -f "$output_path" ]]; then
    python3 "$script_dir/score_results.py" "$output_path" --manifest "$manifest_path" --output "$audio_dir/score.json"
    printf '%s\n' "$audio_dir/score.json"
fi
