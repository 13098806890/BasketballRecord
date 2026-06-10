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
                Text("通过语音快速记录比赛数据，无需手动点击按钮")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "mic.circle.fill",
                title: "如何使用麦克风按钮",
                content: "在设置中开启「显示语音按钮」后，记分页底部会出现麦克风图标。\n\n按住麦克风按钮开始录音，说出指令后松开即可识别。识别成功时屏幕会闪烁绿色提示，失败则闪烁红色。"
            )

            section(
                icon: "waveform.badge.mic",
                title: "支持的指令类型",
                content: "• 投篮记录：说「张三三分命中」「李四两分未中」「8号罚球」等\n• 统计事件：说「篮板」「犯规」「助攻」「盖帽」「抢断」「失误」\n• 换人：说「张三换李四」「3号换5号」\n• 节次控制：说「第一节开始」「第二节结束」\n• 暂停：说「暂停」「停表」「继续」"
            )

            section(
                icon: "waveform.and.mic",
                title: "快捷指令",
                content: "在「语音快捷指令」中可以自定义短语到动作的映射。\n\n例如设置「好球」→「两分命中」，以后说「张三好球」就能直接记录张三两分命中。自定义指令优先级高于系统匹配。"
            )

            section(
                icon: "lightbulb.fill",
                title: "使用技巧",
                content: "• 先选中球员再说投篮指令，或直接说「球员名+指令」\n• 说球员号码比说名字更准确\n• 如果 ASR 返回拼音（例如 ASR 将「罚篮」识别为「fa lan」），系统会自动匹配\n• 识别失败的记录可以在语音日志中查看详情"
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
                Text("音声で素早く試合データを記録")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "mic.circle.fill",
                title: "マイクボタンの使い方",
                content: "設定で「音声ボタンを表示」をオンにすると、採点ページ下部にマイクアイコンが表示されます。\n\nマイクボタンを押し続けて録音を開始し、話し終わったら離して認識します。認識成功時は画面が緑色に、失敗時は赤色に一瞬光ります。"
            )

            section(
                icon: "waveform.badge.mic",
                title: "対応コマンド",
                content: "• シュート記録：「张三ツーポイント成功」「スリーポイント失敗」など\n• 統計イベント：「ファウル」「リバウンド」「アシスト」「ブロック」「スティール」「ターンオーバー」\n• 選手交代：「张三と李四を交代」\n• ピリオド：「第1クオーター開始」「試合終了」\n• 一時停止：「タイムアウト」「一時停止」「再開」"
            )

            section(
                icon: "waveform.and.mic",
                title: "ショートカットコマンド",
                content: "「音声ショートカット」でフレーズとアクションのカスタムマッピングを設定できます。\n\n例：「ナイス」→「ツーポイント成功」と設定すれば、「张三ナイス」で张三のツーポイント成功を記録。カスタム設定はシステムのマッチングより優先されます。"
            )

            section(
                icon: "lightbulb.fill",
                title: "ヒント",
                content: "• 選手を先に選択してからシュートコマンドを言うか、「選手名+コマンド」の順で話す\n• 名前より背番号の方が認識精度が高い\n• ASRがピンインを返した場合でも自動マッチングを試みます\n• 失敗した認識は音声ログで詳細を確認できます"
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
                Text("음성으로 빠르게 경기 데이터 기록")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "mic.circle.fill",
                title: "마이크 버튼 사용법",
                content: "설정에서 '음성 버튼 표시'를 켜면 득점 페이지 하단에 마이크 아이콘이 나타납니다.\n\n마이크 버튼을 길게 눌러 녹음을 시작하고, 말을 마친 후 버튼에서 손을 떼면 인식됩니다. 인식 성공 시 화면이 녹색으로, 실패 시 빨간색으로 깜빡입니다."
            )

            section(
                icon: "waveform.badge.mic",
                title: "지원 명령어",
                content: "• 슛 기록：「张三 투포인트 성공」「쓰리포인트 실패」등\n• 통계 이벤트：「파울」「리바운드」「어시스트」「블록」「스틸」「턴오버」\n• 선수 교체：「张三换李四」\n• 쿼터 제어：「첫 쿼터 시작」「경기 종료」\n• 일시 정지：「타임아웃」「일시정지」「재개」"
            )

            section(
                icon: "waveform.and.mic",
                title: "음성 단축키",
                content: "'음성 단축키'에서 특정 구문과 동작을 직접 매핑할 수 있습니다.\n\n예: '굿' → '투포인트 성공'으로 설정하면 '张三 굿'으로张三의 2점슛 성공을 기록합니다. 사용자 정의 명령어는 시스템 매칭보다 우선 처리됩니다."
            )

            section(
                icon: "lightbulb.fill",
                title: "사용 팁",
                content: "• 선수를 먼저 선택한 후 슛 명령을 말하거나 '선수명+명령어' 순서로 말하기\n• 이름보다 등번호가 인식 정확도가 더 높음\n• 실패한 인식 기록은 음성 로그에서 상세히 확인 가능"
            )
        }
    }

    // MARK: - English (and fallback)
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
                Text("Record game stats quickly with your voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            section(
                icon: "mic.circle.fill",
                title: "How to Use the Mic Button",
                content: "Enable 'Show Voice Button' in Settings to show the microphone icon at the bottom of the scoring page.\n\nPress and hold the mic button to start recording, speak your command, then release. A green flash means success, red means failure."
            )

            section(
                icon: "waveform.badge.mic",
                title: "Supported Commands",
                content: "• Shot recording: 'John three made', 'Mike two missed', 'Player 5 free throw'\n• Stat events: 'Foul', 'Rebound', 'Assist', 'Block', 'Steal', 'Turnover'\n• Substitution: 'John for Mike', '3 for 5'\n• Period control: 'First quarter', 'Next quarter', 'Game over'\n• Pause: 'Timeout', 'Pause', 'Resume'"
            )

            section(
                icon: "waveform.and.mic",
                title: "Voice Shortcuts",
                content: "In 'Voice Shortcuts' you can create custom phrase-to-action mappings.\n\nFor example, map 'Nice' → 'Two Made'. Then saying 'John nice' records a two-point make for John. Custom shortcuts take priority over built-in matching."
            )

            section(
                icon: "lightbulb.fill",
                title: "Tips",
                content: "• Select a player first or say 'player name + command'\n• Jersey numbers are more reliable than names for ASR\n• Failed recognitions can be reviewed in the voice log\n• Voice commands work in all supported languages — switch your system language to use the corresponding voice rules"
            )
        }
    }
}
