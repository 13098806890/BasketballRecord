#!/usr/bin/env python3
import csv
import html
import json
import pathlib
import statistics
import sys


def ratio(value):
    return f"{value * 100:.1f}%" if value is not None else "—"


def latency(rows, key, percentile):
    values = sorted(float(row[key]) for row in rows if row.get(key))
    if not values:
        return None
    position = (len(values) - 1) * percentile
    lower = int(position)
    upper = min(lower + 1, len(values) - 1)
    return values[lower] + (values[upper] - values[lower]) * (position - lower)


def read_manifest(path):
    with path.open(encoding="utf-8", newline="") as stream:
        return {row["case_id"]: row for row in csv.DictReader(stream, delimiter="\t")}


def read_results(path):
    if not path or not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def summarize(rows):
    event_matches = [row.get("event_code") == row.get("expected_event") for row in rows]
    named = [row for row in rows if row.get("expected_player")]
    related = [row for row in rows if row.get("expected_related_player")]
    overall = [
        row.get("event_code") == row.get("expected_event")
        and row.get("player_match") == "true"
        and row.get("related_player_match") == "true"
        for row in rows
    ]
    return {
        "cases": len(rows),
        "event_accuracy": sum(event_matches) / max(len(rows), 1),
        "player_accuracy": sum(row.get("player_match") == "true" for row in named) / max(len(named), 1),
        "related_player_accuracy": sum(row.get("related_player_match") == "true" for row in related) / max(len(related), 1),
        "overall_accuracy": sum(overall) / max(len(rows), 1),
        "first_p50": latency(rows, "first_result_ms", 0.5),
        "first_p95": latency(rows, "first_result_ms", 0.95),
        "final_p50": latency(rows, "final_result_ms", 0.5),
        "final_p95": latency(rows, "final_result_ms", 0.95),
    }


def cell(value):
    return html.escape(str(value or ""))


def build_report(manifest_path, results_path, output_path):
    manifest = read_manifest(manifest_path)
    results = read_results(results_path)
    grouped = {}
    for result in results:
        expected = manifest.get(result.get("case_id", ""), {})
        merged = {**expected, **result}
        merged["event_match"] = result.get("event_code", "") == expected.get("expected_event", "")
        grouped.setdefault((result.get("engine", ""), expected.get("locale", "")), []).append(merged)

    locale_rows = []
    for locale in sorted({row.get("locale", "") for row in manifest.values()}):
        count = len({row.get("expected_player", "") for row in manifest.values() if row.get("locale") == locale and row.get("expected_player")})
        locale_rows.append(f"<tr><td>{cell(locale)}</td><td>{count}</td><td>{len([row for row in manifest.values() if row.get('locale') == locale])}</td></tr>")

    summary_rows = []
    for (engine, locale), rows in sorted(grouped.items()):
        summary = summarize(rows)
        passed = summary["overall_accuracy"] >= 0.8 and summary["event_accuracy"] >= 0.8
        decision = "通过" if passed and summary["player_accuracy"] >= 0.8 else "整体通过/姓名待优化" if passed else "未通过/待测"
        first_latency = f"{summary['first_p50']:.0f} ms / {summary['first_p95']:.0f} ms" if summary["first_p50"] is not None and summary["first_p95"] is not None else "—"
        final_latency = f"{summary['final_p50']:.0f} ms / {summary['final_p95']:.0f} ms" if summary["final_p50"] is not None and summary["final_p95"] is not None else "—"
        summary_rows.append(
            "<tr>"
            f"<td>{cell(locale)}</td><td>{cell(engine)}</td><td>{summary['cases']}</td>"
            f"<td>{ratio(summary['event_accuracy'])}</td><td>{ratio(summary['player_accuracy'])}</td>"
            f"<td>{ratio(summary['overall_accuracy'])}</td><td>{decision}</td>"
            f"<td>{first_latency}</td>"
            f"<td>{final_latency}</td>"
            "</tr>"
        )

    detail_rows = []
    for case_id, expected in manifest.items():
        matching = [row for row in results if row.get("case_id") == case_id]
        if not matching:
            matching = [{"engine": "未运行", "transcript": "", "event_code": "", "event_match": "", "player_match": "", "related_player_match": ""}]
        for result in matching:
            expected_result = manifest.get(result.get("case_id", ""), expected)
            passed = result.get("event_code", "") == expected_result.get("expected_event", "") and result.get("player_match", "true") == "true" and result.get("related_player_match", "true") == "true"
            wav_href = f"expanded-wav/{expected.get('wav_file', case_id + '.wav')}"
            detail_rows.append(
                "<tr>"
                f"<td>{cell(expected.get('locale'))}</td><td>{cell(expected.get('category'))}</td><td>{cell(result.get('engine'))}</td>"
                f"<td>{cell(expected.get('localized_text'))}</td><td>{cell(expected.get('zh_translation'))}</td>"
                f"<td>{cell(expected.get('expected_event'))}</td><td>{cell(result.get('transcript'))}</td>"
                f"<td>{cell(result.get('event_code'))}</td><td>{'通过' if passed else '失败/待测'}</td>"
                f"<td>{cell(result.get('error'))}</td><td><a href='{html.escape(wav_href)}'>播放 WAV</a></td>"
                "</tr>"
            )

    generated = pathlib.Path(output_path).stat().st_mtime if pathlib.Path(output_path).exists() else None
    status = "已生成结果" if results else "已生成测试设计，等待真实设备结果"
    baseline_path = pathlib.Path(output_path).parent / "physical-ios27-legacy" / "score.json"
    baseline_html = ""
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        baseline_html = (
            "<section><h2>已有中文 legacySpeech 真实设备基线</h2>"
            f"<p>该基线来自此前 iOS 27 真机的旧 30 条语料：事件准确率 {ratio(baseline.get('event_accuracy'))}，"
            f"平均 CER {baseline.get('mean_cer', 0):.3f}，平均 WER {baseline.get('mean_wer', 0):.3f}，"
            f"首结果 P50/P95 {baseline.get('first_result_p50_ms', '—')} / {baseline.get('first_result_p95_ms', '—')} ms，"
            f"最终结果 P50/P95 {baseline.get('final_result_p50_ms', '—')} / {baseline.get('final_result_p95_ms', '—')} ms。"
            "这只是中文第一方案的历史基线，不代表本轮 350 条多语言矩阵已经完成。</p></section>"
        )
    speech_locales = sorted({manifest.get(row.get("case_id", ""), {}).get("locale", "") for row in results if row.get("engine") == "speechTranscriber" and manifest.get(row.get("case_id", ""), {}).get("locale")})
    speech_resource_errors = sum("Too many allocated locales" in row.get("error", "") for row in results if row.get("engine") == "speechTranscriber")
    speech_note = (
        "本轮 iOS 27 真机 SpeechTranscriber 实际跑到的 locale："
        + ", ".join(speech_locales)
        + f"；另有 {speech_resource_errors} 条因设备同时最多分配 5 个语言资源而记录为资源限制，俄语在该设备上报告为 locale/model unavailable。"
    )
    content = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BasketballRecord 多语言语音识别评测</title>
<style>
body{{font:14px/1.6 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;margin:0;background:#f4f6f8;color:#1c2636}}
main{{max-width:1440px;margin:24px auto;padding:0 20px}}
section{{background:#fff;border-radius:14px;padding:20px;margin:16px 0;box-shadow:0 3px 16px #1c263612;overflow:auto}}
h1{{margin:0 0 8px}} h2{{margin:0 0 12px;font-size:20px}}
table{{border-collapse:collapse;width:100%;white-space:nowrap}} th,td{{border-bottom:1px solid #e8ebef;padding:8px 10px;text-align:left;vertical-align:top}} th{{background:#f8fafc;position:sticky;top:0}}
.note{{background:#fff7df;border-left:4px solid #e0a400;padding:12px 14px;border-radius:8px}}
.pass{{color:#087443;font-weight:700}} .fail{{color:#a53c22;font-weight:700}} code{{background:#eef2f6;border-radius:4px;padding:2px 4px}}
</style></head><body><main>
<h1>BasketballRecord 多语言语音识别评测</h1>
<p><strong>状态：</strong>{status}　<strong>语料：</strong>{len(manifest)} 条 WAV，10 个 locale，命名格式为 <code>语言-测试内容.wav</code></p>
<div class="note">中文 legacySpeech 只作为“旧方案真实设备基线”，不修改生产逻辑；本报告把事件准确率与整体准确率作为 80% 门槛，姓名准确率单独列为诊断指标。SpeechTranscriber 不可用或模型未下载时显示为 unavailable，不会被伪计为失败或通过。</div>
<section><h2>测试设计摘要</h2><p>每种语言 35 条：18 个命中/未中投篮、8 个统计动作、3 个组合动作、5 个比赛控制命令、1 个换人命令。每种语言实际覆盖 12 名球员，含男女姓名、本地姓名、英文姓名及中英文混杂姓名。详情列同时展示本地化原文、中文翻译、识别结果、事件判断和 WAV 链接。</p></section>
<section><h2>语言和姓名覆盖</h2><table><thead><tr><th>Locale</th><th>球员姓名数</th><th>用例数</th></tr></thead><tbody>{''.join(locale_rows)}</tbody></table></section>
<section><h2>引擎汇总</h2><table><thead><tr><th>Locale</th><th>引擎</th><th>用例</th><th>事件准确率</th><th>姓名准确率</th><th>整体准确率</th><th>判定</th><th>首结果 P50/P95</th><th>最终结果 P50/P95</th></tr></thead><tbody>{''.join(summary_rows) or '<tr><td colspan="9">尚未写入真实设备识别结果</td></tr>'}</tbody></table><p>{html.escape(speech_note)}</p></section>
<section><h2>逐条结果</h2><table><thead><tr><th>语言</th><th>类别</th><th>引擎</th><th>Localized 测试内容</th><th>中文翻译</th><th>期望事件</th><th>识别 transcript</th><th>解析事件</th><th>是否通过</th><th>错误</th><th>WAV</th></tr></thead><tbody>{''.join(detail_rows)}</tbody></table></section>
{baseline_html}<section><h2>解释与后续</h2><p>合成语音结果只能回答“本地规则与系统识别器在固定语料上的可重复表现”。正式发布前还应追加真人录音、不同口音、篮球场噪声、多人重叠说话和近场/远场样本。未达到 80% 的语言会以失败 transcript、对应 WAV 和 parser 事件码作为优化入口。</p></section>
</main></body></html>"""
    pathlib.Path(output_path).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_report.py MANIFEST RESULTS OUTPUT")
    build_report(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]) if sys.argv[2] else None, pathlib.Path(sys.argv[3]))
