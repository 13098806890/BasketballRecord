import SwiftUI

struct VoiceInstructionView: View {
    @Environment(\.locale) private var locale

    private var languageCode: String {
        let code = locale.language.languageCode?.identifier ?? "en"
        if code == "zh" {
            let script = locale.language.script?.identifier
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        return code
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch languageCode {
                case "zh-Hans", "zh-Hant":
                    chineseContent
                case "ja":
                    japaneseContent
                case "ko":
                    koreanContent
                default:
                    englishContent
                }
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey("settings_voice_instruction"))
    }

    private func section(icon: String, title: LocalizedStringKey, content: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 42)
        }
    }

    // MARK: - Chinese
    private var chineseContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("语音控制")
                        .font(.largeTitle.weight(.bold))
                }
                Text("按住麦克风说出指令，松开后自动识别")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "basketball.fill",
                title: "投篮记录",
                content: "说出「球员名 + 投篮类型 + 命中/未中」。\n\n示例：\n「张三两分命中」「李四三分未中」\n「3号两分命中」「8号罚球命中」\n「王五加罚命中」「7号上篮未中」\n\n投篮类型：两分、三分、罚球、加罚、上篮、中投、篮下"
            )

            section(
                icon: "list.clipboard",
                title: "统计记录",
                content: "说出「球员名 + 统计类型」。\n\n示例：\n「张三犯规」「李四篮板」「王五助攻」\n「赵六盖帽」「陈七抢断」「周八失误」\n\n统计类型：犯规、篮板、助攻、盖帽、抢断、失误"
            )

            section(
                icon: "arrow.left.arrow.right",
                title: "换人",
                content: "说出「场上球员 + 换 + 替补球员」。\n\n示例：\n「张三换李四」「3号换5号」\n「王五替换赵六」"
            )

            section(
                icon: "play.rectangle",
                title: "节次与暂停",
                content: "直接说出指令，无需球员名。\n\n示例：\n「第一节开始」「第二节开始」\n「暂停」「停表」「继续」「结束」"
            )

            section(
                icon: "waveform.and.mic",
                title: "快捷指令",
                content: "在「语音快捷指令」中自定义短语，实现更快捷的记录。\n\n例如设置「好球」→「两分命中」后，说「张三好球」即可记录张三两分命中。自定义指令优先于系统匹配。"
            )

            section(
                icon: "lightbulb.fill",
                title: "小技巧",
                content: "• 说球员号码比说姓名更准确（如「3号」）\n• 球员名和指令之间不要加多余的字\n• 识别失败的记录可以在语音日志中查看详情"
            )
        }
    }

    // MARK: - Japanese
    private var japaneseContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("音声コントロール")
                        .font(.largeTitle.weight(.bold))
                }
                Text("マイクを押しながら話し、離して認識")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "basketball.fill",
                title: "シュート記録",
                content: "「選手名 + シュート種類 + 成功/失敗」で記録します。\n\n例：\n「张三ツーポイント成功」「李四スリーポイント失敗」\n「3番ツーポイント失敗」「8番フリースロー成功」\n\nシュート種類：ツーポイント、スリーポイント、フリースロー、レイアップ、ミドル、ペイント"
            )

            section(
                icon: "list.clipboard",
                title: "統計記録",
                content: "「選手名 + 統計種類」で記録します。\n\n例：\n「张三ファウル」「李四リバウンド」「王五アシスト」"
            )

            section(
                icon: "arrow.left.arrow.right",
                title: "選手交代",
                content: "「コート上の選手 + 交代キーワード + 控え選手」で交代します。\n\n例：\n「张三と李四を交代」「3番と5番を交代」"
            )

            section(
                icon: "play.rectangle",
                title: "ピリオド・一時停止",
                content: "選手名なしで直接コマンドを話します。\n\n例：\n「第1クオーター開始」「タイムアウト」「一時停止」「再開」「試合終了」"
            )

            section(
                icon: "waveform.and.mic",
                title: "ショートカットコマンド",
                content: "「音声ショートカット」でフレーズとアクションをカスタム設定できます。「ナイス」→「ツーポイント成功」と設定すれば、「张三ナイス」で素早く記録できます。"
            )
        }
    }

    // MARK: - Korean
    private var koreanContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("음성 제어")
                        .font(.largeTitle.weight(.bold))
                }
                Text("마이크를 누르고 말한 후 손을 떼면 인식")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "basketball.fill",
                title: "슛 기록",
                content: "「선수명 + 슛 종류 + 성공/실패」로 기록합니다.\n\n예시：\n「张三 투포인트 성공」「李四 쓰리포인트 실패」\n「3번 투포인트 실패」「8번 자유투 성공」\n\n슛 종류：투포인트、쓰리포인트、자유투、레이업、미드、페인트"
            )

            section(
                icon: "list.clipboard",
                title: "통계 기록",
                content: "「선수명 + 통계 종류」로 기록합니다.\n\n예시：\n「张三 파울」「李四 리바운드」「王五 어시스트」"
            )

            section(
                icon: "arrow.left.arrow.right",
                title: "선수 교체",
                content: "「코트 선수 + 교체 키워드 + 대기 선수」로 교체합니다.\n\n예시：\n「张三 교체 李四」「3번 교체 5번」"
            )

            section(
                icon: "play.rectangle",
                title: "쿼터・일시정지",
                content: "선수명 없이 직접 명령어를 말합니다.\n\n예시：\n「첫 쿼터 시작」「타임아웃」「일시정지」「재개」「경기종료」"
            )

            section(
                icon: "waveform.and.mic",
                title: "음성 단축키",
                content: "「음성 단축키」에서 구문과 동작을 직접 매핑할 수 있습니다. 「굿」→「투포인트 성공」으로 설정하면「张三 굿」으로 빠르게 기록합니다."
            )
        }
    }

    // MARK: - English
    private var englishContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("Voice Control")
                        .font(.largeTitle.weight(.bold))
                }
                Text("Hold the mic button, speak a command, then release")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "basketball.fill",
                title: "Shot Recording",
                content: "Say \"player name + shot type + made/missed\".\n\nExamples:\n\"John two made\" \"Mike three missed\"\n\"Player 5 two made\" \"23 free throw\"\n\"Smith and one\" \"8 layup missed\"\n\nShot types: two, three, free throw, layup, mid(range), paint, bonus"
            )

            section(
                icon: "list.clipboard",
                title: "Stat Events",
                content: "Say \"player name + stat type\".\n\nExamples:\n\"John foul\" \"Mike rebound\" \"Smith assist\"\n\"Brown block\" \"Jones steal\" \"Wilson turnover\""
            )

            section(
                icon: "arrow.left.arrow.right",
                title: "Substitution",
                content: "Say \"outgoing player + substitution keyword + incoming player\".\n\nExamples:\n\"John for Mike\" \"3 for 5\"\n\"Smith sub Jones\" \"Player 8 replace Player 10\""
            )

            section(
                icon: "play.rectangle",
                title: "Period & Pause",
                content: "No player name needed.\n\nExamples:\n\"First quarter\" \"Next quarter\"\n\"Timeout\" \"Pause\" \"Resume\"\n\"Game over\" \"Finish\""
            )

            section(
                icon: "waveform.and.mic",
                title: "Voice Shortcuts",
                content: "Create custom phrase-to-action mappings in \"Voice Shortcuts\".\n\nFor example, map \"Nice\" → \"Two Made\", then saying \"John nice\" records a two-point make for John instantly."
            )

            section(
                icon: "lightbulb.fill",
                title: "Tips",
                content: "• Jersey numbers are more reliable than names (e.g. \"23\")\n• Keep player name and command close together without extra words\n• Failed recognitions can be reviewed in the voice log"
            )
        }
    }
}
