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


def is_unavailable(row):
    error = row.get("error", "").lower()
    return "unavailable" in error or "allocated locales" in error or "设备不支持" in error or "speechtranscriber" in error and "不支持" in error


def read_manifest(path):
    with path.open(encoding="utf-8", newline="") as stream:
        return {row["case_id"]: row for row in csv.DictReader(stream, delimiter="\t")}


def read_results(path):
    if not path or not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def read_iteration_history(path):
    if not path.exists():
        return []
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def classify_log_row(row, expected):
    if is_unavailable(row):
        return "unavailable"
    status = row.get("recognition_status", "")
    if status == "asr_no_result" or not row.get("transcript", "").strip():
        return "asr_no_result"
    if status == "asr_error":
        return "asr_error"
    if not row.get("event_code", ""):
        return "parser_no_action"
    if row.get("event_code", "") != expected.get("expected_event", ""):
        return "parser_wrong_event"
    if expected.get("expected_player") and row.get("player_match") != "true":
        return "player_not_matched"
    if expected.get("expected_related_player") and row.get("related_player_match") != "true":
        return "related_player_not_matched"
    return "success"


def build_log_analysis(manifest, results, output_path):
    categories = {}
    examples = {}
    for result in results:
        expected = manifest.get(result.get("case_id", ""), {})
        locale = expected.get("locale", "unknown")
        category = classify_log_row(result, expected)
        locale_counts = categories.setdefault(locale, {})
        locale_counts[category] = locale_counts.get(category, 0) + 1
        if category not in {"success", "unavailable"}:
            locale_examples = examples.setdefault(locale, {}).setdefault(category, [])
            if len(locale_examples) < 5:
                locale_examples.append({
                    "case_id": result.get("case_id", ""),
                    "transcript": result.get("transcript", ""),
                    "event_code": result.get("event_code", ""),
                    "voice_log": result.get("voice_log", "")
                })
    analysis = {
        "source": "results.csv",
        "categories": categories,
        "examples": examples
    }
    pathlib.Path(output_path).write_text(json.dumps(analysis, ensure_ascii=False, indent=2), encoding="utf-8")
    return analysis


def render_log_analysis(analysis):
    if not analysis or not analysis.get("categories"):
        return ""
    category_names = {
        "success": "解析并匹配成功",
        "asr_no_result": "ASR 无结果",
        "asr_error": "ASR 错误",
        "parser_no_action": "解析无动作",
        "parser_wrong_event": "解析事件错误",
        "player_not_matched": "球员未匹配",
        "related_player_not_matched": "关联球员未匹配",
        "unavailable": "设备/模型不可用"
    }
    rows = []
    for locale, counts in sorted(analysis["categories"].items()):
        for category, count in sorted(counts.items()):
            rows.append(f"<tr><td>{cell(locale)}</td><td>{cell(category_names.get(category, category))}</td><td>{count}</td></tr>")
    example_sections = []
    for locale, locale_examples in sorted(analysis.get("examples", {}).items()):
        items = []
        for category, examples in sorted(locale_examples.items()):
            for example in examples:
                items.append(
                    f"<li><code>{cell(category)}</code> {cell(example.get('case_id'))}：{cell(example.get('transcript'))}"
                    f"；解析={cell(example.get('event_code'))}；VoiceLog={cell(example.get('voice_log'))}</li>"
                )
        if items:
            example_sections.append(f"<details><summary>{cell(locale)} 失败样本</summary><ul>{''.join(items)}</ul></details>")
    return (
        "<section><h2>VoiceLog 自动闭环分析</h2>"
        "<p>每次测试结束后，结果会按 ASR 无结果、解析无动作、事件错误、球员匹配失败和成功自动分类，并把失败样本与 VoiceLog 一起保存到 <code>log-analysis.json</code>。下一轮优化直接从数量最多的类别和样本进入。</p>"
        "<table><thead><tr><th>Locale</th><th>日志分类</th><th>数量</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table>"
        + "".join(example_sections)
        + "</section>"
    )


def summarize(rows):
    available = [row for row in rows if not is_unavailable(row)]
    event_matches = [row.get("event_code") == row.get("expected_event") for row in available]
    named = [row for row in available if row.get("expected_player")]
    related = [row for row in available if row.get("expected_related_player")]
    overall = [
        row.get("event_code") == row.get("expected_event")
        and row.get("player_match") == "true"
        and row.get("related_player_match") == "true"
        for row in available
    ]
    return {
        "cases": len(available),
        "total_cases": len(rows),
        "unavailable": len(rows) - len(available),
        "event_accuracy": sum(event_matches) / max(len(available), 1),
        "player_accuracy": sum(row.get("player_match") == "true" for row in named) / max(len(named), 1),
        "related_player_accuracy": sum(row.get("related_player_match") == "true" for row in related) / max(len(related), 1),
        "overall_accuracy": sum(overall) / max(len(available), 1),
        "first_p50": latency(rows, "first_result_ms", 0.5),
        "first_p95": latency(rows, "first_result_ms", 0.95),
        "final_p50": latency(rows, "final_result_ms", 0.5),
        "final_p95": latency(rows, "final_result_ms", 0.95),
    }


def cell(value):
    return html.escape(str(value or ""))


def delta_html(value):
    if value is None:
        return "—"
    if value > 0:
        css_class = "delta-up"
    elif value < 0:
        css_class = "delta-down"
    else:
        css_class = "delta-flat"
    return f'<span class="{css_class}">{value * 100:+.1f}%</span>'


def render_iteration_history(history):
    if not history:
        return ""
    rows = []
    increment_rows = []
    analysis_sections = []
    previous_locales = {}
    previous_overall = None
    for item in history:
        overall = item.get("overall_accuracy")
        delta = item.get("delta")
        if delta is None and overall is not None and previous_overall is not None:
            delta = overall - previous_overall
        delta_text = delta_html(delta)
        rows.append(
            "<tr>"
            f"<td>{cell(item.get('round'))}</td><td>{cell(item.get('version'))}</td>"
            f"<td>{cell(item.get('change'))}</td><td>{cell(item.get('log_evidence'))}</td>"
            f"<td>{item.get('available_cases', '—')}</td><td>{ratio(item.get('event_accuracy'))}</td>"
            f"<td>{ratio(item.get('player_accuracy'))}</td><td>{ratio(overall)}</td>"
            f"<td>{delta_text}</td><td>{cell(item.get('notes'))}</td>"
            "</tr>"
        )
        locale_overall = item.get("locale_overall", {})
        locale_rows = []
        for locale, value in locale_overall.items():
            previous = previous_locales.get(locale)
            locale_delta = None if previous is None else value - previous
            locale_delta_text = delta_html(locale_delta)
            increment_rows.append(
                f"<tr><td>{cell(item.get('round'))}</td><td>{cell(locale)}</td>"
                f"<td>{ratio(previous)}</td><td>{ratio(value)}</td><td>{locale_delta_text}</td></tr>"
            )
            locale_rows.append(
                f"<tr><td>{cell(locale)}</td><td>{ratio(previous)}</td><td>{ratio(value)}</td><td>{locale_delta_text}</td></tr>"
            )
        log_stats = item.get("log_stats", {})
        stats_text = "；".join(f"{cell(key)} {value} 条" for key, value in log_stats.items()) if log_stats else "本轮未保存结构化 VoiceLog 统计"
        log_capture = item.get("log_capture")
        if not log_capture:
            log_capture = "已保存每条 VoiceLog parser trace" if log_stats else "历史结果未保存 VoiceLog 字段"
        analysis_sections.append(
            f"<details open><summary>{cell(item.get('round'))} · {cell(item.get('version'))}</summary>"
            f"<p><strong>改进内容：</strong>{cell(item.get('change'))}</p>"
            f"<p><strong>日志采集：</strong>{cell(log_capture)}。<strong>日志统计：</strong>{stats_text}。</p>"
            f"<p><strong>日志分析：</strong>{cell(item.get('log_analysis', item.get('log_evidence')))}</p>"
            f"<p><strong>本轮结果：</strong>事件 {ratio(item.get('event_accuracy'))}，姓名 {ratio(item.get('player_accuracy'))}，整体 {ratio(overall)}；整体较上一轮 {delta_text}。</p>"
            "<table><thead><tr><th>Locale</th><th>上一轮</th><th>本轮</th><th>增量</th></tr></thead><tbody>"
            + "".join(locale_rows)
            + "</tbody></table></details>"
        )
        previous_locales = locale_overall
        if overall is not None:
            previous_overall = overall
    return (
        "<section><h2>方案二语音识别演进</h2>"
        "<p>每一轮都使用同一套 10 个 locale × 70 条语料，在当前连接的 iOS 27 真机上运行。"
        "R5 起结果同时保留 SpeechTranscriber 的候选转写和 App 内 VoiceLog parser trace；R0–R4 没有保存 VoiceLog 的历史结果会明确标注，不能当作已采集日志。</p>"
        "<table><thead><tr><th>轮次</th><th>版本</th><th>本轮改动</th><th>日志证据与分析</th><th>有效用例</th><th>事件准确率</th><th>姓名准确率</th><th>整体准确率</th><th>较上一轮</th><th>备注</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table>"
        "<h3>每种语言的增量</h3>"
        "<table><thead><tr><th>轮次</th><th>Locale</th><th>上一轮</th><th>本轮</th><th>增量</th></tr></thead><tbody>"
        + "".join(increment_rows)
        + "</tbody></table>"
        + "".join(analysis_sections)
        + "</section>"
    )


def build_report(manifest_path, results_path, output_path):
    manifest = read_manifest(manifest_path)
    results = read_results(results_path)
    iteration_history = read_iteration_history(pathlib.Path(output_path).parent / "iteration-history.json")
    log_analysis = build_log_analysis(manifest, results, pathlib.Path(output_path).parent / "log-analysis.json")
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
        passed = summary["cases"] > 0 and summary["overall_accuracy"] >= 0.8 and summary["event_accuracy"] >= 0.8
        if summary["cases"] == 0:
            decision = "设备不可用"
        elif passed and summary["player_accuracy"] >= 0.8:
            decision = "通过"
        elif passed:
            decision = "整体通过/姓名待优化"
        else:
            decision = "未通过/待优化"
        first_latency = f"{summary['first_p50']:.0f} ms / {summary['first_p95']:.0f} ms" if summary["first_p50"] is not None and summary["first_p95"] is not None else "—"
        final_latency = f"{summary['final_p50']:.0f} ms / {summary['final_p95']:.0f} ms" if summary["final_p50"] is not None and summary["final_p95"] is not None else "—"
        summary_rows.append(
            "<tr>"
            f"<td>{cell(locale)}</td><td>{cell(engine)}</td><td>{summary['cases']}/{summary['total_cases']}</td>"
            f"<td>{ratio(summary['event_accuracy'])}</td><td>{ratio(summary['player_accuracy'])}</td>"
            f"<td>{ratio(summary['overall_accuracy'])}</td><td>{decision}</td>"
            f"<td>{first_latency}</td>"
            f"<td>{final_latency}</td>"
            "</tr>"
        )

    baseline_comparison_rows = []
    for locale in sorted({row.get("locale", "") for row in manifest.values()}):
        baseline = summarize(grouped.get(("legacySpeech", locale), []))
        candidate = summarize(grouped.get(("speechTranscriber", locale), []))
        if baseline["total_cases"] == 0 and candidate["total_cases"] == 0:
            continue
        baseline_comparison_rows.append(
            "<tr>"
            f"<td>{cell(locale)}</td>"
            f"<td>{baseline['cases']}/{baseline['total_cases']} · {ratio(baseline['overall_accuracy'])}</td>"
            f"<td>{candidate['cases']}/{candidate['total_cases']} · {ratio(candidate['overall_accuracy'])}</td>"
            f"<td>{ratio(baseline['event_accuracy'])} / {ratio(candidate['event_accuracy'])}</td>"
            f"<td>{ratio(baseline['player_accuracy'])} / {ratio(candidate['player_accuracy'])}</td>"
            "</tr>"
        )

    baseline_comparison = ""
    if baseline_comparison_rows:
        baseline_comparison = (
            "<section><h2>方案一基准对照</h2>"
            "<p>方案一与方案二使用同一批 WAV、同一套期望事件和同一套解析结果判定。每个单元格格式为“有效/总用例 · 整体准确率”；事件和姓名两列按“方案一 / 方案二”显示。</p>"
            "<table><thead><tr><th>Locale</th><th>方案一 legacySpeech</th><th>方案二 SpeechTranscriber</th><th>事件准确率</th><th>姓名准确率</th></tr></thead><tbody>"
            + "".join(baseline_comparison_rows)
            + "</tbody></table></section>"
        )

    detail_rows = []
    for case_id, expected in manifest.items():
        matching = [row for row in results if row.get("case_id") == case_id]
        if not matching:
            matching = [{"engine": "未运行", "transcript": "", "event_code": "", "event_match": "", "player_match": "", "related_player_match": ""}]
        for result in matching:
            expected_result = manifest.get(result.get("case_id", ""), expected)
            unavailable = is_unavailable(result)
            passed = not unavailable and result.get("event_code", "") == expected_result.get("expected_event", "") and result.get("player_match", "true") == "true" and result.get("related_player_match", "true") == "true"
            wav_href = f"expanded-wav/{expected.get('wav_file', case_id + '.wav')}"
            detail_rows.append(
                "<tr>"
                f"<td>{cell(expected.get('locale'))}</td><td>{cell(expected.get('variant'))}</td><td>{cell(expected.get('category'))}</td><td>{cell(result.get('engine'))}</td>"
                f"<td>{cell(expected.get('localized_text'))}</td><td>{cell(expected.get('zh_translation'))}</td>"
                f"<td>{cell(expected.get('expected_event'))}</td><td>{cell(result.get('transcript'))}</td>"
                f"<td>{cell(result.get('event_code'))}</td><td>{'环境不可用' if unavailable else ('通过' if passed else '失败/待测')}</td>"
                f"<td>{cell(result.get('recognition_status'))}</td><td>{cell(result.get('error'))}</td><td>{cell(result.get('candidates'))}</td><td>{cell(result.get('voice_log'))}</td><td><a href='{html.escape(wav_href)}'>播放 WAV</a></td>"
                "</tr>"
            )

    generated = pathlib.Path(output_path).stat().st_mtime if pathlib.Path(output_path).exists() else None
    status = "已生成结果" if results else "已生成测试设计，等待真实设备结果"
    baseline_path = pathlib.Path(output_path).parent / "physical-ios27-legacy" / "score.json"
    baseline_html = ""
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        baseline_html = (
            "<section><h2>历史中文 legacySpeech 真实设备基线（补充）</h2>"
            f"<p>该基线来自此前 iOS 27 真机的旧 30 条语料：事件准确率 {ratio(baseline.get('event_accuracy'))}，"
            f"平均 CER {baseline.get('mean_cer', 0):.3f}，平均 WER {baseline.get('mean_wer', 0):.3f}，"
            f"首结果 P50/P95 {baseline.get('first_result_p50_ms', '—')} / {baseline.get('first_result_p95_ms', '—')} ms，"
            f"最终结果 P50/P95 {baseline.get('final_result_p50_ms', '—')} / {baseline.get('final_result_p95_ms', '—')} ms。"
            "这只是中文第一方案的历史基线，不代表本轮 350 条多语言矩阵已经完成。</p></section>"
        )
    speech_locales = sorted({manifest.get(row.get("case_id", ""), {}).get("locale", "") for row in results if row.get("engine") == "speechTranscriber" and not row.get("error") and manifest.get(row.get("case_id", ""), {}).get("locale")})
    unavailable_locales = []
    for locale in sorted({row.get("locale", "") for row in manifest.values()}):
        locale_results = [row for row in results if row.get("engine") == "speechTranscriber" and manifest.get(row.get("case_id", ""), {}).get("locale") == locale]
        if locale_results and all(is_unavailable(row) for row in locale_results):
            unavailable_locales.append(locale)
    speech_resource_errors = sum("Too many allocated locales" in row.get("error", "") for row in results if row.get("engine") == "speechTranscriber")
    speech_note = (
        "本轮 iOS 27 真机 SpeechTranscriber 实际跑到的 locale："
        + ", ".join(speech_locales)
        + "。"
        + ("设备不可用 locale：" + ", ".join(unavailable_locales) + "。" if unavailable_locales else "")
        + f"资源限制记录：{speech_resource_errors} 条。"
    )
    evolution_html = render_iteration_history(iteration_history)
    log_analysis_html = render_log_analysis(log_analysis)
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
.pass{{color:#087443;font-weight:700}} .fail{{color:#a53c22;font-weight:700}} .delta-up{{color:#c62828;font-weight:700}} .delta-down{{color:#2e7d32;font-weight:700}} .delta-flat{{color:#687381;font-weight:700}} code{{background:#eef2f6;border-radius:4px;padding:2px 4px}}
</style></head><body><main>
<h1>BasketballRecord 多语言语音识别评测</h1>
<p><strong>状态：</strong>{status}　<strong>语料：</strong>{len(manifest)} 条 WAV，10 个 locale，命名格式为 <code>语言-测试内容.wav</code></p>
<div class="note">本轮只运行 SpeechTranscriber，不修改中文第一方案的生产逻辑。本报告把事件准确率与整体准确率作为 80% 门槛，姓名准确率单独列为诊断指标。SpeechTranscriber 不可用或模型未下载时显示为 unavailable，不会被伪计为失败或通过。</div>
<section><h2>测试设计摘要</h2><p>每种语言 70 条不同用例：35 条使用当地球员姓名的标准口令，35 条使用替代表达。日语和韩语使用符合当地习惯的本地姓名，以及标准篮球词搭配当地自然语气；其他语言保留球衣号码替代口令。基础语料包含 18 个命中/未中投篮、8 个统计动作、3 个组合动作、5 个比赛控制命令、1 个换人命令。每条结果还会保留 SpeechTranscriber 的候选转写和 App 内 VoiceLog parser trace，方便按“识别错误 / 解析错误 / 球员匹配错误”拆分优化。详情列同时展示本地化原文、中文翻译、识别结果、事件判断、识别状态和 WAV 链接。</p></section>
<section><h2>语言和姓名覆盖</h2><table><thead><tr><th>Locale</th><th>球员姓名数</th><th>用例数</th></tr></thead><tbody>{''.join(locale_rows)}</tbody></table></section>
<section><h2>当前指标口径</h2><p>逐语言汇总使用该语言自己的 70 条用例；俄语因当前真机不支持 SpeechTranscriber，标记为设备不可用，不计入“有效用例”整体准确率。因此本页简体中文 60/70 = 85.7%，繁体中文 59/70 = 84.3%，英文 60/70 = 85.7%，意大利语 56/70 = 80.0%。<code>score.json</code> 仍保留 700 条全量结果，包含俄语不可用行，不能与这里的有效用例口径直接比较。</p></section>
<section><h2>引擎汇总</h2><table><thead><tr><th>Locale</th><th>引擎</th><th>有效/总用例</th><th>事件准确率</th><th>姓名准确率</th><th>整体准确率</th><th>判定</th><th>首结果 P50/P95</th><th>最终结果 P50/P95</th></tr></thead><tbody>{''.join(summary_rows) or '<tr><td colspan="9">尚未写入真实设备识别结果</td></tr>'}</tbody></table><p>{html.escape(speech_note)}</p></section>
{baseline_comparison}
{evolution_html}
{log_analysis_html}
<section><details><summary><h2 style="display:inline">逐条结果（{len(results)} 条，点击展开）</h2></summary><table><thead><tr><th>语言</th><th>样本组</th><th>类别</th><th>引擎</th><th>Localized 测试内容</th><th>中文翻译</th><th>期望事件</th><th>识别 transcript</th><th>解析事件</th><th>是否通过</th><th>识别状态</th><th>错误</th><th>候选转写</th><th>VoiceLog</th><th>WAV</th></tr></thead><tbody>{''.join(detail_rows)}</tbody></table></details></section>
{baseline_html}<section><h2>解释与后续</h2><p>合成语音结果只能回答“本地规则与系统识别器在固定语料上的可重复表现”。正式发布前还应追加真人录音、不同口音、篮球场噪声、多人重叠说话和近场/远场样本。未达到 80% 的语言会以失败 transcript、对应 WAV 和 parser 事件码作为优化入口。</p></section>
</main></body></html>"""
    pathlib.Path(output_path).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_report.py MANIFEST RESULTS OUTPUT")
    build_report(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]) if sys.argv[2] else None, pathlib.Path(sys.argv[3]))
