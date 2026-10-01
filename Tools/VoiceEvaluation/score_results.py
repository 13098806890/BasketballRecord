#!/usr/bin/env python3
import argparse
import csv
import json
import math
import re
import unicodedata


def normalize(text):
    folded = unicodedata.normalize("NFKC", text).casefold()
    return "".join(char for char in folded if char.isalnum())


def tokens(text):
    normalized = unicodedata.normalize("NFKC", text).casefold().strip()
    if re.search(r"[\u2e80-\u9fff\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff]", normalized):
        return [char for char in normalized if char.isalnum()]
    return [token for token in re.split(r"\s+", normalized) if token]


def distance(left, right):
    previous = list(range(len(right) + 1))
    for left_index, left_value in enumerate(left, start=1):
        current = [left_index]
        for right_index, right_value in enumerate(right, start=1):
            current.append(min(
                current[-1] + 1,
                previous[right_index] + 1,
                previous[right_index - 1] + (left_value != right_value),
            ))
        previous = current
    return previous[-1]


def error_rate(expected, actual, split):
    expected_tokens = split(expected)
    actual_tokens = split(actual)
    denominator = max(len(expected_tokens), 1)
    return distance(expected_tokens, actual_tokens) / denominator


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def load_manifest(path):
    with open(path, encoding="utf-8", newline="") as stream:
        return {row["case_id"]: row for row in csv.DictReader(stream, delimiter="\t")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("results", help="CSV with engine,case_id,transcript,first_result_ms,final_result_ms,event_code")
    parser.add_argument("--manifest", default=None)
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    manifest_path = args.manifest or f"{args.results.rsplit('/', 1)[0]}/manifest.tsv"
    manifest = load_manifest(manifest_path)
    rows = []
    with open(args.results, encoding="utf-8", newline="") as stream:
        for result in csv.DictReader(stream):
            expected = manifest[result["case_id"]]
            transcript = result.get("transcript", "")
            first_result = float(result["first_result_ms"]) if result.get("first_result_ms") else None
            final_result = float(result["final_result_ms"]) if result.get("final_result_ms") else None
            rows.append({
                "engine": result.get("engine", ""),
                "case_id": result["case_id"],
                "locale": expected["locale"],
                "expected_text": expected.get("localized_text", expected.get("text", "")),
                "zh_translation": expected.get("zh_translation", ""),
                "category": expected.get("category", ""),
                "expected_event": expected.get("expected_event", ""),
                "expected_player": expected.get("expected_player", ""),
                "expected_related_player": expected.get("expected_related_player", ""),
                "wav_file": expected.get("wav_file", f'{result["case_id"]}.wav'),
                "transcript": transcript,
                "cer": error_rate(normalize(expected.get("localized_text", expected.get("text", ""))), normalize(transcript), list),
                "wer": error_rate(expected.get("localized_text", expected.get("text", "")), transcript, tokens),
                "event_match": result.get("event_code", "") == expected["expected_event"],
                "player_match": result.get("player_match", "true" if not expected.get("expected_player") else "false") == "true",
                "related_player_match": result.get("related_player_match", "true" if not expected.get("expected_related_player") else "false") == "true",
                "first_result_ms": first_result,
                "final_result_ms": final_result,
            })

    first_results = [row["first_result_ms"] for row in rows if row["first_result_ms"] is not None]
    final_results = [row["final_result_ms"] for row in rows if row["final_result_ms"] is not None]
    summary = {
        "cases": len(rows),
        "event_accuracy": sum(row["event_match"] for row in rows) / max(len(rows), 1),
        "player_accuracy": sum(row["player_match"] for row in rows if row["expected_player"]) / max(sum(bool(row["expected_player"]) for row in rows), 1),
        "related_player_accuracy": sum(row["related_player_match"] for row in rows if row["expected_related_player"]) / max(sum(bool(row["expected_related_player"]) for row in rows), 1),
        "overall_accuracy": sum(row["event_match"] and row["player_match"] and row["related_player_match"] for row in rows) / max(len(rows), 1),
        "mean_cer": sum(row["cer"] for row in rows) / max(len(rows), 1),
        "mean_wer": sum(row["wer"] for row in rows) / max(len(rows), 1),
        "first_result_p50_ms": percentile(first_results, 0.5),
        "first_result_p95_ms": percentile(first_results, 0.95),
        "final_result_p50_ms": percentile(final_results, 0.5),
        "final_result_p95_ms": percentile(final_results, 0.95),
        "rows": rows,
    }
    payload = json.dumps(summary, ensure_ascii=False, indent=2)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as stream:
            stream.write(payload)
    else:
        print(payload)


if __name__ == "__main__":
    main()
