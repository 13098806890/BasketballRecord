import SwiftUI

struct VoiceInstructionView: View {
    @AppStorage("voice_locale") private var voiceLocale: String = ""

    private var languageCode: String {
        guard !voiceLocale.isEmpty else {
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            if locale == "zh-Hans" || locale == "zh-Hant" || locale == "zh-Hant-TW" || locale == "zh-Hant-HK" {
                return locale.hasPrefix("zh-Hant") ? "zh-Hant" : "zh-Hans"
            }
            return String(locale.prefix(2))
        }
        if voiceLocale.hasPrefix("zh-Hant") {
            return "zh-Hant"
        }
        if voiceLocale == "zh-Hans" {
            return "zh-Hans"
        }
        return String(voiceLocale.prefix(2))
    }

    private var t: VoiceCommandExamples.Templates {
        VoiceCommandExamples.templates(for: languageCode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                shotSection
                statSection
                substitutionSection
                periodPauseSection
                combinedSection
                shortcutsSection
                tipsSection
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey("settings_voice_instruction"))
    }

    private func section(icon: String, title: LocalizedStringKey, content: String) -> some View {
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.blue)
                Text(headerTitle)
                    .font(.largeTitle.weight(.bold))
            }
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headerTitle: String {
        switch languageCode {
        case "zh-Hans": return "语音控制"
        case "zh-Hant": return "語音控制"
        case "ja": return "音声コントロール"
        case "ko": return "음성 제어"
        case "de": return "Sprachsteuerung"
        case "es": return "Control por Voz"
        case "fr": return "Commande Vocale"
        case "it": return "Controllo Vocale"
        case "ru": return "Голосовое управление"
        default: return "Voice Control"
        }
    }

    private var headerSubtitle: String {
        switch languageCode {
        case "zh-Hans": return "按住麦克风说出指令，松开后自动识别"
        case "zh-Hant": return "按住麥克風說出指令，鬆開後自動識別"
        case "ja": return "マイクを押しながら話し、離して認識"
        case "ko": return "마이크를 누르고 말한 후 손을 떼면 인식"
        case "de": return "Mikrofon gedrückt halten, sprechen, dann loslassen"
        case "es": return "Manten presionado el microfono, habla y suelta"
        case "fr": return "Maintenez le micro enfonce, parlez, puis relachez"
        case "it": return "Tieni premuto il microfono, parla, poi rilascia"
        case "ru": return "Зажмите микрофон, говорите команду, затем отпустите"
        default: return "Hold the mic button, speak a command, then release"
        }
    }

    private var shotSection: some View {
        section(
            icon: "basketball.fill",
            title: LocalizedStringKey("voice_instruction_shots"),
            content: shotContent
        )
    }

    private var shotContent: String {
        var lines: [String]
        switch languageCode {
        case "zh-Hans":
            lines = ["说出「球员名 + 投篮类型 + 命中/未中」。",
                     "",
                     "示例："]
            let exs: [String] = [.twoMade, .threeMissed, .freeThrowMade, .layupMade, .midRangeMade, .paintMade, .bonusMade]
                .compactMap { a in t.actionTemplates[a]?.first }
                .map { tpl in
                    "「\(VoiceCommandExamples.fill(tpl, name: "张三", number: "3"))」"
                }
            lines.append(contentsOf: exs)
            lines += ["", "投篮类型：\(t.shotTypeNames.joined(separator: "、"))"]
        case "zh-Hant":
            lines = ["說出「球員名 + 投籃類型 + 命中/未中」。", "", "示例："]
            let exs: [String] = [.twoMade, .threeMissed, .freeThrowMade, .layupMade, .midRangeMade, .paintMade, .bonusMade]
                .compactMap { a in t.actionTemplates[a]?.first }
                .map { tpl in
                    "「\(VoiceCommandExamples.fill(tpl, name: "張三", number: "3"))」"
                }
            lines.append(contentsOf: exs)
            lines += ["", "投籃類型：\(t.shotTypeNames.joined(separator: "、"))"]
        case "ja":
            lines = ["「選手名 + シュート種類 + 成功/失敗」で記録します。", "", "例："]
            let exs = t.actionTemplates[.twoMade]?.prefix(2).enumerated().map { (i, tpl) in
                "「\(VoiceCommandExamples.fill(tpl, name: i == 0 ? "田中" : "田中", number: "3"))」"
            } ?? []
            lines.append(contentsOf: exs)
            lines += ["", "シュート種類：\(t.shotTypeNames.joined(separator: "、"))"]
        case "ko":
            lines = ["「선수명 + 슛 종류 + 성공/실패」로 기록합니다.", "", "예시："]
            let exs = t.actionTemplates[.twoMade]?.prefix(2).enumerated().map { (i, tpl) in
                "「\(VoiceCommandExamples.fill(tpl, name: "김철수", number: "3"))」"
            } ?? []
            lines.append(contentsOf: exs)
            lines += ["", "슛 종류：\(t.shotTypeNames.joined(separator: "、"))"]
        case "de":
            lines = [
                "Sprich 'Spielername + Wurfart + getroffen/verfehlt'.",
                "",
                "Beispiele:",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.twoMade]?.first ?? "", name: "Hans", number: "7"))'",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.threeMissed]?.first ?? "", name: "Fritz", number: "10"))'",
                "",
                "Wurfarten: \(t.shotTypeNames.joined(separator: ", "))"
            ]
        case "es":
            lines = [
                "Di 'nombre del jugador + tipo de tiro + canasta/fallo'.",
                "",
                "Ejemplos:",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.twoMade]?.first ?? "", name: "Carlos", number: "7"))'",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.threeMissed]?.first ?? "", name: "Luis", number: "10"))'",
                "",
                "Tipos: \(t.shotTypeNames.joined(separator: ", "))"
            ]
        case "fr":
            lines = [
                "Dites 'nom du joueur + type de tir + bon/non'.",
                "",
                "Exemples :",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.twoMade]?.first ?? "", name: "Pierre", number: "7"))'",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.threeMissed]?.first ?? "", name: "Paul", number: "10"))'",
                "",
                "Types : \(t.shotTypeNames.joined(separator: ", "))"
            ]
        case "it":
            lines = [
                "Di 'nome giocatore + tipo di tiro + segnato/sbagliato'.",
                "",
                "Esempi:",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.twoMade]?.first ?? "", name: "Marco", number: "7"))'",
                "'\(VoiceCommandExamples.fill(t.actionTemplates[.threeMissed]?.first ?? "", name: "Luca", number: "10"))'",
                "",
                "Tipi: \(t.shotTypeNames.joined(separator: ", "))"
            ]
        case "ru":
            lines = [
                "Скажите «имя игрока + тип броска + попал/промах».",
                "",
                "Примеры:",
                "«\(VoiceCommandExamples.fill(t.actionTemplates[.twoMade]?.first ?? "", name: "Иван", number: "7"))»",
                "«\(VoiceCommandExamples.fill(t.actionTemplates[.threeMissed]?.first ?? "", name: "Пётр", number: "10"))»",
                "",
                "Типы: \(t.shotTypeNames.joined(separator: ", "))"
            ]
        default:
            lines = [
                "Say player name/number, then anchor word (got / missed / miss), then shot type.",
                "",
                "\"got\" / \"get\" \u{2192} made, \"miss\" / \"missed\" \u{2192} miss.",
                "",
                "Examples:",
                "\"Jordan got a 3\"",
                "\"Number 23 got a two\"",
                "\"#5 missed a layup\"",
                "",
                "Shot types: \(t.shotTypeNames.joined(separator: ", "))",
                "",
                "Short form (no anchor, defaults to made):",
                "\"Jordan 3\" \"#23 two\" \"8 layup\""
            ]
        }
        return lines.joined(separator: "\n")
    }

    private var statSection: some View {
        section(
            icon: "list.clipboard",
            title: LocalizedStringKey("voice_instruction_stats"),
            content: statContent
        )
    }

    private var statContent: String {
        let names = t.statTypeNames.map(\.1).joined(separator: "、")
        switch languageCode {
        case "zh-Hans":
            let exs = t.statExamples.prefix(6).map { "「\($0.1)」" }.joined()
            return "说出「球员名 + 统计类型」。\n\n示例：\n\(exs)\n\n统计类型：\(names)"
        case "zh-Hant":
            let exs = t.statExamples.prefix(6).map { "「\($0.1)」" }.joined()
            return "說出「球員名 + 統計類型」。\n\n示例：\n\(exs)\n\n統計類型：\(names)"
        case "ja":
            return "「選手名 + 統計種類」で記録します。\n\n例：\n「田中ファウル」「李四リバウンド」「王五アシスト」"
        case "ko":
            return "「선수명 + 통계 종류」로 기록합니다.\n\n예시：\n「张三 파울」「李四 리바운드」「王五 어시스트」"
        case "de":
            let exs = t.statExamples.prefix(6).map { "'\($0.1)'" }.joined(separator: " · ")
            return "Sprich 'Spielername + Statistik'.\n\nBeispiele:\n\(exs)"
        case "es":
            let exs = t.statExamples.prefix(6).map { "'\($0.1)'" }.joined(separator: " · ")
            return "Di 'nombre del jugador + estadistica'.\n\nEjemplos:\n\(exs)"
        case "fr":
            let exs = t.statExamples.prefix(6).map { "'\($0.1)'" }.joined(separator: " · ")
            return "Dites 'nom du joueur + statistique'.\n\nExemples :\n\(exs)"
        case "it":
            let exs = t.statExamples.prefix(6).map { "'\($0.1)'" }.joined(separator: " · ")
            return "Di 'nome giocatore + statistica'.\n\nEsempi:\n\(exs)"
        case "ru":
            let exs = t.statExamples.prefix(6).map { "«\($0.1)»" }.joined(separator: " · ")
            return "Скажите «имя игрока + тип статистики».\n\nПримеры:\n\(exs)"
        default:
            let exs = t.statExamples.prefix(6).map { "\"\($0.1)\"" }.joined(separator: " ")
            return "Say \"player name/number + stat keyword\".\n\nExamples:\n\(exs)"
        }
    }

    private var substitutionSection: some View {
        section(
            icon: "arrow.left.arrow.right",
            title: LocalizedStringKey("voice_instruction_substitution"),
            content: substitutionContent
        )
    }

    private var substitutionContent: String {
        let cb = "」「"
        switch languageCode {
        case "zh-Hans":
            return "说出「场上球员 + 换 + 替补球员」。\n\n示例：\n「\(t.substitutionExamples.joined(separator: cb))」"
        case "zh-Hant":
            return "說出「場上球員 + 換 + 替補球員」。\n\n示例：\n「\(t.substitutionExamples.joined(separator: cb))」"
        case "ja":
            return "「コート上の選手 + 交代キーワード + 控え選手」で交代します。\n\n例：\n「\(t.substitutionExamples.joined(separator: cb))」"
        case "ko":
            return "「코트 선수 + 교체 키워드 + 대기 선수」로 교체합니다.\n\n예시：\n「\(t.substitutionExamples.joined(separator: cb))」"
        default:
            let exs = t.substitutionExamples.map { "'\($0)'" }.joined(separator: " · ")
            return "Say 'outgoing player + sub/replace + incoming player'.\n\nExamples:\n\(exs)"
        }
    }

    private var periodPauseSection: some View {
        section(
            icon: "play.rectangle",
            title: LocalizedStringKey("voice_instruction_period"),
            content: periodPauseContent
        )
    }

    private var periodPauseContent: String {
        let cb = "」「"
        let sdot = "' · '"
        let gm = "» · «"
        let dq = "\" \""
        let end = t.gameEndCommands
        switch languageCode {
        case "zh-Hans":
            return "直接说出指令，无需球员名。\n\n示例：\n「\(t.periodPauseCommands.joined(separator: cb))」"
        case "zh-Hant":
            return "直接說出指令，無需球員名。\n\n示例：\n「\(t.periodPauseCommands.joined(separator: cb))」"
        case "ja":
            let cmds = t.periodPauseCommands.joined(separator: cb)
            let e = end.isEmpty ? "" : "「\(end.joined(separator: cb))」"
            return "選手名なしで直接コマンドを話します。\n\n例：\n「\(cmds)」\(e)"
        case "ko":
            let cmds = t.periodPauseCommands.joined(separator: cb)
            let e = end.isEmpty ? "" : "「\(end.joined(separator: cb))」"
            return "선수명 없이 직접 명령어를 말합니다.\n\n예시：\n「\(cmds)」\(e)"
        case "de":
            let cmds = t.periodPauseCommands.joined(separator: sdot)
            let e = end.isEmpty ? "" : "\n'\(end.joined(separator: sdot))'"
            return "Kein Spielername nötig.\n\nBeispiele:\n'\(cmds)'\(e)"
        case "es":
            let cmds = t.periodPauseCommands.joined(separator: sdot)
            let e = end.isEmpty ? "" : "\n'\(end.joined(separator: sdot))'"
            return "Sin nombre de jugador.\n\nEjemplos:\n'\(cmds)'\(e)"
        case "fr":
            let cmds = t.periodPauseCommands.joined(separator: sdot)
            let e = end.isEmpty ? "" : "\n'\(end.joined(separator: sdot))'"
            return "Pas de nom de joueur necessaire.\n\nExemples :\n'\(cmds)'\(e)"
        case "it":
            let cmds = t.periodPauseCommands.joined(separator: sdot)
            let e = end.isEmpty ? "" : "\n'\(end.joined(separator: sdot))'"
            return "Nessun nome giocatore necessario.\n\nEsempi:\n'\(cmds)'\(e)"
        case "ru":
            let cmds = t.periodPauseCommands.joined(separator: gm)
            let e = end.isEmpty ? "" : "\n«\(end.joined(separator: gm))»"
            return "Имя игрока не требуется.\n\nПримеры:\n«\(cmds)»\(e)"
        default:
            let cmds = t.periodPauseCommands.joined(separator: dq)
            let e = end.isEmpty ? "" : "\n\"\(end.joined(separator: dq))\""
            return "No player name needed.\n\nExamples:\n\"\(cmds)\"\(e)"
        }
    }

    private var combinedSection: some View {
        section(
            icon: "link",
            title: LocalizedStringKey("voice_instruction_combined"),
            content: combinedContent
        )
    }

    private var combinedContent: String {
        switch languageCode {
        case "zh-Hans":
            return "复合指令：一次说出助攻+投篮或抢断+失误。\n\n示例：\n「俊宏助攻老张两分」→ 助攻 + 两分命中 + 比分更新\n「俊宏助攻老张三分」→ 助攻 + 三分命中 + 比分更新\n「俊宏抢断bobo」→ 抢断 + 失误"
        case "zh-Hant":
            return "複合指令：一次說出助攻+投籃或抄截+失誤。\n\n示例：\n「俊宏助攻老張兩分」→ 助攻 + 兩分命中 + 比分更新\n「俊宏助攻老張三分」→ 助攻 + 三分命中 + 比分更新\n「俊宏抄截bobo」→ 抄截 + 失誤"
        case "ja":
            return "複合コマンド：アシスト+シュート、スティール+ターンオーバーを一度に。\n\n例：\n「鈴木アシスト田中ツー」→ アシスト + ツー成功 + 得点更新\n「鈴木アシスト田中スリー」→ アシスト + スリー成功 + 得点更新\n「鈴木スティール佐藤」→ スティール + ターンオーバー"
        case "ko":
            return "복합 명령: 어시스트+슛 또는 스틸+턴오버를 한 번에.\n\n예시：\n「이영희 어시스트 김철수 투」→ 어시스트 + 2점 성공 + 점수 업데이트\n「이영희 어시스트 김철수 쓰리」→ 어시스트 + 3점 성공 + 점수 업데이트\n「이영희 스틸 정지원」→ 스틸 + 턴오버"
        case "de":
            return "Kombinierte Befehle: Assist + Wurf oder Steal + Turnover in einem.\n\nBeispiele:\n„Fritz Assist Hans zwei“ → Assist + 2 Punkte + Punktezähler aktualisiert\n„Fritz Assist Hans drei“ → Assist + 3 Punkte + Punktezähler aktualisiert\n„Fritz Steal Gerd“ → Steal + Turnover"
        case "es":
            return "Comandos combinados: asistencia + tiro o robo + perdida en uno.\n\nEjemplos:\n„Luis asistencia Carlos dos“ → asistencia + 2 puntos + marcador actualizado\n„Luis asistencia Carlos tres“ → asistencia + 3 puntos + marcador actualizado\n„Luis robo Juan“ → robo + perdida"
        case "fr":
            return "Commandes combinées : passe décisive + tir ou interception + perte de balle en une seule fois.\n\nExemples :\n„Paul assist Pierre deux“ → passe décisive + 2 points + score mis à jour\n„Paul assist Pierre trois“ → passe décisive + 3 points + score mis à jour\n„Paul interception Luc“ → interception + perte de balle"
        case "it":
            return "Comandi combinati: assist + tiro o palla rubata + perse in uno.\n\nEsempi:\n„Luca assist Marco due“ → assist + 2 punti + punteggio aggiornato\n„Luca assist Marco tre“ → assist + 3 punti + punteggio aggiornato\n„Luca rubata Mario“ → palla rubata + perse"
        case "ru":
            return "Комбинированные команды: ассист + бросок или перехват + потеря одним голосом.\n\nПримеры:\n«Пётр ассист Иван два» → ассист + 2 очка + счёт обновлён\n«Пётр ассист Иван три» → ассист + 3 очка + счёт обновлён\n«Пётр перехват Алексей» → перехват + потеря"
        default:
            return "Combine an assist with a shot, or a steal with a turnover, in one command.\n\nExamples:\n\"Mike assist John two\" → assist + 2PT made + score updated\n\"Mike assist John three\" → assist + 3PT made + score updated\n\"Mike steal Dave\" → steal + turnover"
        }
    }

    private var shortcutsSection: some View {
        section(
            icon: "waveform.and.mic",
            title: LocalizedStringKey("voice_instruction_shortcuts"),
            content: shortcutsContent
        )
    }

    private var shortcutsContent: String {
        switch languageCode {
        case "zh-Hans":
            return "在「语音快捷指令」中自定义短语，实现更快捷的记录。\n\n例如设置「好球」→「两分命中」后，说「张三好球」即可记录张三两分命中。自定义指令优先于系统匹配。"
        case "zh-Hant":
            return "在「語音快捷指令」中自訂短語，實現更快捷的記錄。\n\n例如設定「好球」→「兩分命中」後，說「張三好球」即可記錄張三兩分命中。自訂指令優先於系統匹配。"
        case "ja":
            return "「音声ショートカット」でフレーズとアクションをカスタム設定できます。「ナイス」→「ツーポイント成功」と設定すれば、「田中ナイス」で素早く記録できます。"
        case "ko":
            return "「음성 단축키」에서 구문과 동작을 직접 매핑할 수 있습니다. 「굿」→「투포인트 성공」으로 설정하면「김철수 굿」으로 빠르게 기록합니다."
        case "de":
            return "Erstelle eigene Befehle in 'Sprachkürzel'. Z.B. 'Gut' -> 'Zwei getroffen', dann sagt man 'Hans gut' fuer eine schnelle Aufzeichnung."
        case "es":
            return "Crea comandos personalizados en 'Atajos de Voz'. Por ejemplo, asigna 'Bueno' -> 'Dos canasta', luego di 'Carlos bueno' para registrar rapido."
        case "fr":
            return "Creez vos propres commandes dans 'Raccourcis Vocaux'. Par exemple, associez 'Bon' -> 'Deux bon', puis dites 'Pierre bon' pour enregistrer rapidement."
        case "it":
            return "Crea comandi personalizzati in 'Scorciatoie Vocali'. Ad esempio, mappa 'Bravo' -> 'Due segnato', poi di 'Marco bravo' per registrare velocemente."
        case "ru":
            return "Создайте свои команды в «Голосовых сокращениях». Например, настройте «Отлично» \u{2192} «Два попал», затем скажите «Иван отлично» для быстрой записи."
        default:
            return "Create custom phrase-to-action mappings in \"Voice Shortcuts\".\n\nFor example, map \"Nice\" \u{2192} \"Two Made\", then saying \"John nice\" records a two-point make for John instantly."
        }
    }

    private var tipsSection: some View {
        section(
            icon: "lightbulb.fill",
            title: LocalizedStringKey("voice_instruction_tips"),
            content: tipsContent
        )
    }

    private var tipsContent: String {
        switch languageCode {
        case "zh-Hans":
            return "• 说球员号码比说姓名更准确（如「3号」）\n• 球员名和指令之间不要加多余的字\n• 主客队有相同号码时，只说号码默认匹配主队队员，匹配客队需加主队/客队前缀\n• 识别失败的记录可以在语音日志中查看详情"
        case "zh-Hant":
            return "• 說球員號碼比說姓名更準確（如「3號」）\n• 球員名和指令之間不要加多餘的字\n• 主客隊有相同號碼時，只說號碼默認匹配主隊隊員，匹配客隊需加主隊/客隊前綴\n• 識別失敗的記錄可以在語音日誌中查看詳情"
        case "ja":
            return "• 選手名より背番号の方が正確です（例：「3番」）\n• 選手名とコマンドの間に余分な文字を入れないでください\n• ホームとアウェイに同じ番号がある場合、番号のみだとホームが優先されます。アウェイを指定するには「アウェイ」を付けてください\n• 認識に失敗した記録は音声ログで確認できます"
        case "ko":
            return "• 선수 이름보다 번호가 더 정확합니다 (예: 「3번」)\n• 선수명과 명령어 사이에 불필요한 글자를 넣지 마세요\n• 홈과 어웨이에 같은 번호가 있으면 번호만으로는 홈이 우선 매칭됩니다. 어웨이를 지정하려면 「어웨이」를 붙이세요\n• 인식 실패 기록은 음성 로그에서 확인할 수 있습니다"
        case "de":
            return "• Trikotnummern sind zuverlässiger als Namen (z.B. \u{201E}23\u{201C} statt \u{201E}Jordan\u{201C})\n• Keine überflüssigen Wörter zwischen Name/Nummer und Befehl\n• Bei gleicher Nummer in beiden Teams wird ohne Präfix das Heimteam bevorzugt. Für das Auswärtsteam \u{201E}Auswärts\u{201C} voranstellen\n• Fehlerkennungen können im Sprachprotokoll überprüft werden"
        case "es":
            return "• Los números de camiseta son más fiables que los nombres (ej. \"23\" en vez de \"Jordan\")\n• No añadas palabras extra entre el nombre/número y el comando\n• Si ambos equipos tienen el mismo número, sin prefijo se empareja con el equipo local. Para el visitante, añade \"Visitante\"\n• Los fallos de reconocimiento se pueden revisar en el registro de voz"
        case "fr":
            return "• Les numéros de maillot sont plus fiables que les noms (ex. \"23\" au lieu de \"Jordan\")\n• N'ajoutez pas de mots inutiles entre le nom/numéro et la commande\n• Si les deux équipes ont le même numéro, sans préfixe, le joueur local est prioritaire. Pour l'équipe visiteuse, ajoutez \"Extérieur\"\n• Les échecs de reconnaissance sont consultables dans le journal vocal"
        case "it":
            return "• I numeri di maglia sono più affidabili dei nomi (es. \"23\" invece di \"Jordan\")\n• Non inserire parole extra tra nome/numero e comando\n• Se entrambe le squadre hanno lo stesso numero, senza prefisso viene abbinato il giocatore di casa. Per l'ospite, aggiungi \"Ospite\"\n• I riconoscimenti falliti possono essere rivisti nel registro vocale"
        case "ru":
            return "• Номера игроков надёжнее имён (например, «23» вместо «Джордан»)\n• Не добавляйте лишних слов между именем/номером и командой\n• Если одинаковый номер есть в обеих командах, без префикса будет выбран игрок хозяев. Для гостей добавьте «Гости»\n• Неудачные распознавания можно проверить в журнале голосовых команд"
        default:
            return "• Jersey numbers are more reliable than names (e.g. \"23\" instead of \"Jordan\")\n• Use \"got\" / \"missed\" as anchor words for clearest recognition\n• When both teams share the same number, saying just the number matches the home player; add \"away\" to match the away player\n• For team stats mode, use \"home\" / \"away\" as the player name\n• Failed recognitions can be reviewed in the voice log"
        }
    }
}
