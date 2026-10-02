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
device_identifier=""
bundle_identifier="com.xiedongze.BasketballRecord"
build_settings=()

if [[ "$destination" == platform=iOS,* ]]; then
    device_identifier="${destination#*id=}"
    device_identifier="${device_identifier%%,*}"
fi

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

if [[ -n "$device_identifier" ]]; then
    app_path="$(find "$derived_data_path/Build/Products" -path '*/BasketballRecord.app' -type d -print -quit)"
    xcrun devicectl device install app --device "$device_identifier" "$app_path" --timeout 180 --quiet
    xcrun devicectl device copy to \
        --device "$device_identifier" \
        --source "$audio_dir" \
        --destination Documents/VoiceEvaluation \
        --domain-type appDataContainer \
        --domain-identifier "$bundle_identifier" \
        --timeout 180 \
        --quiet
fi

plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_AUDIO_DIR' -string "$audio_dir" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_MANIFEST' -string "$manifest_path" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_ENGINES' -string "$engine_names" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_OUTPUT' -string "$output_path" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_AUDIO_DIR' -string "$audio_dir" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_MANIFEST' -string "$manifest_path" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_ENGINES' -string "$engine_names" "$xctestrun_path"
plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_OUTPUT' -string "$output_path" "$xctestrun_path"
if [[ "$release_all_locales" == "1" ]]; then
    plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_RELEASE_ALL_LOCALES' -string "1" "$xctestrun_path"
    plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_RELEASE_ALL_LOCALES' -string "1" "$xctestrun_path"
fi
if [[ -n "$locale_names" ]]; then
    plutil -insert 'TestConfigurations.0.TestTargets.0.TestingEnvironmentVariables.VOICE_ASR_EVAL_LOCALES' -string "$locale_names" "$xctestrun_path"
    plutil -insert 'TestConfigurations.0.TestTargets.0.EnvironmentVariables.VOICE_ASR_EVAL_LOCALES' -string "$locale_names" "$xctestrun_path"
fi

evaluation_arguments=(
    "--VOICE_ASR_EVAL_AUDIO_DIR=$audio_dir"
    "--VOICE_ASR_EVAL_MANIFEST=$manifest_path"
    "--VOICE_ASR_EVAL_ENGINES=$engine_names"
    "--VOICE_ASR_EVAL_OUTPUT=$output_path"
)
if [[ "$release_all_locales" == "1" ]]; then
    evaluation_arguments+=("--VOICE_ASR_EVAL_RELEASE_ALL_LOCALES=1")
fi
if [[ -n "$locale_names" ]]; then
    evaluation_arguments+=("--VOICE_ASR_EVAL_LOCALES=$locale_names")
fi
argument_index=0
for argument in "${evaluation_arguments[@]}"; do
    plutil -insert "TestConfigurations.0.TestTargets.0.CommandLineArguments.$argument_index" -string "$argument" "$xctestrun_path"
    argument_index=$((argument_index + 1))
done

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

if [[ -n "$device_identifier" ]]; then
    xcrun devicectl device copy from \
        --device "$device_identifier" \
        --source Documents/VoiceEvaluation/results.csv \
        --destination "$output_path" \
        --domain-type appDataContainer \
        --domain-identifier "$bundle_identifier" \
        --timeout 180 \
        --quiet || true
fi

rg 'VOICE_ASR_UNAVAILABLE,' "$test_log_path" > "$audio_dir/unavailable.txt" || true
rg 'VOICE_ASR_DIAGNOSTIC,' "$test_log_path" > "$audio_dir/diagnostics.log" || true

if [[ -f "$output_path" ]]; then
    python3 "$script_dir/score_results.py" "$output_path" --manifest "$manifest_path" --output "$audio_dir/score.json"
    printf '%s\n' "$audio_dir/score.json"
fi
