# Voice evaluation kit

这套评测资产用于比较 `legacySpeech` 和 `speechTranscriber` 两种引擎在篮球口令上的表现。它将识别准确率和产品事件解析准确率分开记录，避免“文字看起来相近但没有记成正确事件”的情况被忽略。

## 生成录音

需要 macOS 自带的 `say` 和 `afconvert`。先用 manifest 构建脚本生成 10 个 locale、每种 35 条的完整测试矩阵，再用系统已安装的多语言声音生成 16 kHz、16-bit、单声道 WAV：

```sh
Tools/VoiceEvaluation/build_manifest.sh
Tools/VoiceEvaluation/generate_recordings.sh
```

默认输出到临时目录，也可以传入 manifest 和输出目录：

```sh
Tools/VoiceEvaluation/generate_recordings.sh \
  Tools/VoiceEvaluation/manifest.tsv \
  /tmp/basketballrecord-voice-evaluation
```

这些是可重复的合成语音基线，不替代真实用户录音。真实设备评测时，应在安静、多人说话、不同距离和不同网络状态下分别采集一组真人样本，并保留相同的 case id。

## 结果格式

将每条录音送入某一个引擎后，记录为 CSV：

```text
engine,case_id,transcript,first_result_ms,final_result_ms,event_code
legacySpeech,en-three,Bob three,420,760,stat.threeMade
speechTranscriber,en-three,Bob three,180,510,stat.threeMade
```

`first_result_ms` 是从开始送入音频到首个可用结果的耗时，`final_result_ms` 是到最终结果的耗时，`event_code` 是现有篮球事件解析器输出的 eventCode；`player_match` 和 `related_player_match` 分别表示球员与组合动作目标球员是否正确。

## 评分

```sh
python3 Tools/VoiceEvaluation/score_results.py \
  /tmp/basketballrecord-voice-evaluation/results.csv \
  --manifest Tools/VoiceEvaluation/manifest.tsv \
  --output /tmp/basketballrecord-voice-evaluation/score.json
```

## 运行文件型 ASR 测试

使用下面的脚本可以自动生成 WAV、构建测试包、运行文件型 XCTest，并在成功产生结果时输出评分：

```sh
Tools/VoiceEvaluation/run_file_evaluation.sh
```

默认只运行 `speechTranscriber`。比较两种方案时：

```sh
VOICE_ASR_EVAL_ENGINES=legacySpeech,speechTranscriber \
Tools/VoiceEvaluation/run_file_evaluation.sh
```

也可以指定真人录音目录、目标 Simulator 和输出文件：

```sh
VOICE_ASR_EVAL_AUDIO_DIR=/path/to/wav \
VOICE_ASR_EVAL_DESTINATION='platform=iOS Simulator,name=iPhone 18 Pro Max' \
VOICE_ASR_EVAL_OUTPUT=/tmp/voice-results.csv \
Tools/VoiceEvaluation/run_file_evaluation.sh
```

没有系统语音模型、语言资源或旧版 Speech 授权时，测试会标记为环境跳过，不会伪造识别结果。SpeechTranscriber 的文件测试应优先在真实 iOS 26 设备上运行；Simulator 只能验证 WAV 读取、适配器和规则解析链路。

输出包括：

- `mean_cer`：字符错误率，适合中文、日文、韩文和俄文等语言
- `mean_wer`：词错误率，适合空格分词语言；CJK 语言按字符切分
- `event_accuracy`：篮球事件命中率
- 首结果和最终结果的 P50/P95 延迟
- 每个 case 的逐项结果，便于定位某种语言或口令的退化
- `diagnostics.log`：locale、profile、AssetInventory 状态、reservation、结果数量和 alternative 数量
- `unavailable.txt`：设备不支持、模型不可用、locale 不支持等环境状态；这些记录不计入识别率

SpeechTranscriber 评测会把当前语言的规则词和 manifest 中该语言的球员名单提供给 `AnalysisContext`，并在每条文件用例完成后释放 locale reservation。这样可以避免连续跑多语言时把“资源占用上限”误判为“识别失败”。

生成简体中文 HTML 报告：

```sh
python3 Tools/VoiceEvaluation/generate_report.py \
  Tools/VoiceEvaluation/manifest.tsv \
  /path/to/results.csv \
  Artifacts/VoiceEvaluation/multilingual-report.html
```

报告包含本地化测试内容、中文翻译、transcript、事件码、是否通过、延迟汇总和可播放 WAV 链接。WAV 文件名统一为 `语言-测试内容.wav`。

## 评测边界

SpeechTranscriber 只在 iOS 26 及以上系统可用，并且可能需要系统下载语言资源。Simulator 不能代表真实麦克风和 Neural Engine 的延迟，因此本阶段只把 Simulator 构建和规则解析作为自动验证；端到端音频延迟必须在真实设备上记录。
