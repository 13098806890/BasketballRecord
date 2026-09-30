#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
manifest_path="${1:-$script_dir/manifest.tsv}"

mkdir -p "${manifest_path:h}"
printf '%s\n' 'case_id	locale	category	variant	voice	localized_text	zh_translation	expected_event	expected_player	player_gender	name_script	expected_related_player	wav_file' > "$manifest_path"

number_phrase() {
    local locale="$1"
    local number="$2"
    case "$locale" in
        zh-Hans) print -r -- "${number}号" ;;
        zh-Hant-TW) print -r -- "${number}號" ;;
        ja) print -r -- "背番号${number}番の選手" ;;
        ko) print -r -- "등번호 ${number}번 선수" ;;
        en) print -r -- "number ${number}" ;;
        de) print -r -- "Nummer ${number}" ;;
        es) print -r -- "número ${number}" ;;
        fr) print -r -- "numéro ${number}" ;;
        it) print -r -- "numero ${number}" ;;
        ru) print -r -- "номер ${number}" ;;
        *) print -r -- "number ${number}" ;;
    esac
}

alternate_command_text() {
    local locale="$1"
    local suffix="$2"
    case "${locale}:${suffix}" in
        zh-Hans:start) print -r -- '开始比赛' ;;
        zh-Hans:pause) print -r -- '暂停一下' ;;
        zh-Hans:game-end) print -r -- '比赛结束' ;;
        zh-Hans:undo) print -r -- '撤销上一条' ;;
        zh-Hans:redo) print -r -- '重做上一条' ;;
        zh-Hant-TW:start) print -r -- '開始比賽' ;;
        zh-Hant-TW:pause) print -r -- '暫停一下' ;;
        zh-Hant-TW:game-end) print -r -- '比賽結束' ;;
        zh-Hant-TW:undo) print -r -- '撤銷上一條' ;;
        zh-Hant-TW:redo) print -r -- '重做上一條' ;;
        en:start) print -r -- 'start the game' ;;
        en:pause) print -r -- 'timeout now' ;;
        en:game-end) print -r -- 'game over now' ;;
        en:undo) print -r -- 'undo last action' ;;
        en:redo) print -r -- 'redo last action' ;;
        de:start) print -r -- 'start das Spiel' ;;
        de:pause) print -r -- 'auszeit bitte' ;;
        de:game-end) print -r -- 'spielende jetzt' ;;
        de:undo) print -r -- 'rückgängig letzte Aktion' ;;
        de:redo) print -r -- 'wiederholen letzte Aktion' ;;
        es:start) print -r -- 'inicio del partido' ;;
        es:pause) print -r -- 'tiempo muerto ahora' ;;
        es:game-end) print -r -- 'fin del partido' ;;
        es:undo) print -r -- 'deshacer última acción' ;;
        es:redo) print -r -- 'rehacer última acción' ;;
        fr:start) print -r -- 'début du match' ;;
        fr:pause) print -r -- 'temps mort maintenant' ;;
        fr:game-end) print -r -- 'fin du match' ;;
        fr:undo) print -r -- 'annuler dernière action' ;;
        fr:redo) print -r -- 'refaire dernière action' ;;
        it:start) print -r -- 'inizio della partita' ;;
        it:pause) print -r -- 'timeout adesso' ;;
        it:game-end) print -r -- 'fine partita' ;;
        it:undo) print -r -- 'annulla ultima azione' ;;
        it:redo) print -r -- 'ripeti ultima azione' ;;
        ja:start) print -r -- '試合開始' ;;
        ja:pause) print -r -- 'タイムアウトお願いします' ;;
        ja:game-end) print -r -- '試合終了' ;;
        ja:undo) print -r -- '最後の操作を元に戻す' ;;
        ja:redo) print -r -- '最後の操作をやり直す' ;;
        ko:start) print -r -- '경기 시작' ;;
        ko:pause) print -r -- '타임아웃 요청' ;;
        ko:game-end) print -r -- '경기종료' ;;
        ko:undo) print -r -- '마지막 실행 취소' ;;
        ko:redo) print -r -- '마지막 재실행' ;;
        ru:start) print -r -- 'начало игры' ;;
        ru:pause) print -r -- 'тайм-аут сейчас' ;;
        ru:game-end) print -r -- 'конец игры' ;;
        ru:undo) print -r -- 'отменить последнее' ;;
        ru:redo) print -r -- 'повторить последнее' ;;
        *) print -r -- '' ;;
    esac
}

alternate_player_text() {
    local locale="$1"
    local suffix="$2"
    local player="$3"
    local related="$4"
    case "${locale}:${suffix}" in
        ja:two-made) print -r -- "${player}のツーが成功" ;;
        ja:two-missed) print -r -- "${player}のツーは外れ" ;;
        ja:three-made) print -r -- "${player}のスリーが成功" ;;
        ja:three-missed) print -r -- "${player}のスリーは外れ" ;;
        ja:bonus-made) print -r -- "${player}のアンドワンが成功" ;;
        ja:bonus-missed) print -r -- "${player}のアンドワンは外れ" ;;
        ja:free-throw-made) print -r -- "${player}がフリースローを決めた" ;;
        ja:free-throw-missed) print -r -- "${player}のフリースローは外れ" ;;
        ja:layup-made) print -r -- "${player}がレイアップを決めた" ;;
        ja:layup-missed) print -r -- "${player}のレイアップは外れ" ;;
        ja:mid-range-made) print -r -- "${player}のミドルシュートが成功" ;;
        ja:mid-range-missed) print -r -- "${player}のミドルシュートは外れ" ;;
        ja:paint-made) print -r -- "${player}がインサイドで成功" ;;
        ja:paint-missed) print -r -- "${player}のインサイドは外れ" ;;
        ja:putback-made) print -r -- "${player}のプットバックが成功" ;;
        ja:putback-missed) print -r -- "${player}のプットバックは外れ" ;;
        ja:dunk-made) print -r -- "${player}のダンクシュートが成功" ;;
        ja:dunk-missed) print -r -- "${player}のダンクシュートは外れ" ;;
        ja:foul) print -r -- "${player}のファウル" ;;
        ja:rebound) print -r -- "${player}がリバウンド" ;;
        ja:offensive-rebound) print -r -- "${player}がオフェンスリバウンド" ;;
        ja:defensive-rebound) print -r -- "${player}がディフェンスリバウンド" ;;
        ja:assist) print -r -- "${player}がアシスト" ;;
        ja:block) print -r -- "${player}がブロック" ;;
        ja:steal) print -r -- "${player}がスティール" ;;
        ja:turnover) print -r -- "${player}のターンオーバー" ;;
        ja:assist-two) print -r -- "${player}のアシストで${related}がツーを成功" ;;
        ja:assist-three) print -r -- "${player}のアシストで${related}がスリーを成功" ;;
        ja:steal-turnover) print -r -- "${player}がスティールして${related}がターンオーバー" ;;
        ja:substitution) print -r -- "${player}を交代して${related}を出場" ;;
        ko:two-made) print -r -- "${player} 2점 성공" ;;
        ko:two-missed) print -r -- "${player} 2점 실패" ;;
        ko:three-made) print -r -- "${player} 3점 성공" ;;
        ko:three-missed) print -r -- "${player} 3점 실패" ;;
        ko:bonus-made) print -r -- "${player} 앤드원 성공" ;;
        ko:bonus-missed) print -r -- "${player} 앤드원 실패" ;;
        ko:free-throw-made) print -r -- "${player} 자유투 성공" ;;
        ko:free-throw-missed) print -r -- "${player} 자유투 실패" ;;
        ko:layup-made) print -r -- "${player} 레이업슛 성공" ;;
        ko:layup-missed) print -r -- "${player} 레이업슛 실패" ;;
        ko:mid-range-made) print -r -- "${player} 미드레인지 성공" ;;
        ko:mid-range-missed) print -r -- "${player} 미드레인지 실패" ;;
        ko:paint-made) print -r -- "${player} 페인트존 성공" ;;
        ko:paint-missed) print -r -- "${player} 페인트존 실패" ;;
        ko:putback-made) print -r -- "${player} 풋백 성공" ;;
        ko:putback-missed) print -r -- "${player} 풋백 실패" ;;
        ko:dunk-made) print -r -- "${player} 덩크슛 성공" ;;
        ko:dunk-missed) print -r -- "${player} 덩크슛 실패" ;;
        ko:foul) print -r -- "${player} 파울" ;;
        ko:rebound) print -r -- "${player} 리바운드" ;;
        ko:offensive-rebound) print -r -- "${player} 공격 리바운드" ;;
        ko:defensive-rebound) print -r -- "${player} 수비 리바운드" ;;
        ko:assist) print -r -- "${player} 어시스트" ;;
        ko:block) print -r -- "${player} 블락" ;;
        ko:steal) print -r -- "${player} 스틸" ;;
        ko:turnover) print -r -- "${player} 턴오버" ;;
        ko:assist-two) print -r -- "${player} 어시스트 ${related} 투 성공" ;;
        ko:assist-three) print -r -- "${player} 어시스트 ${related} 쓰리 성공" ;;
        ko:steal-turnover) print -r -- "${player} 스틸 ${related} 턴오버" ;;
        ko:substitution) print -r -- "${player} 교체 ${related} 투입" ;;
        *) print -r -- '' ;;
    esac
}

emit_locale() {
    local locale="$1"
    local voice="$2"
    shift 2
    local -a names=("$@")
    local suffix text zh event category player_index related_index player gender script related case_id
    local alt_text player_number related_number alt_voice

    while IFS='|' read -r suffix text zh event category player_index gender script related_index; do
        [[ -n "$suffix" ]] || continue
        player=""
        related=""
        if [[ "$player_index" != "-" ]]; then
            player="${names[$player_index]}"
            text="${text//__P__/$player}"
            zh="${zh//__P__/$player}"
            if (( player_index <= 3 || player_index == 6 || player_index == 8 || player_index == 10 || player_index == 12 )); then
                gender="male"
            else
                gender="female"
            fi
            if [[ "$player" == *[[:ascii:]]* ]] && [[ "$player" == *[![:ascii:]]* ]]; then
                script="mixed"
            elif [[ "$player" == *[![:ascii:]]* ]]; then
                script="native"
            else
                script="latin"
            fi
        else
            gender=""
            script=""
        fi
        if [[ "$related_index" != "-" ]]; then
            related="${names[$related_index]}"
            text="${text//__R__/$related}"
            zh="${zh//__R__/$related}"
        fi
        case_id="${locale}-${suffix}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_id" "$locale" "$category" "canonical" "$voice" "$text" "$zh" "$event" "$player" "$gender" "$script" "$related" "$case_id.wav" >> "$manifest_path"
        alt_text="$text"
        if [[ "$player_index" != "-" ]]; then
            if [[ "$locale" == "ja" || "$locale" == "ko" ]]; then
                alt_text="$(alternate_player_text "$locale" "$suffix" "$player" "$related")"
                if [[ "$locale" == "ja" ]]; then
                    alt_text="${text} お願いします"
                else
                    alt_text="${text} 해 주세요"
                fi
            else
                player_number="$(number_phrase "$locale" "$player_index")"
                alt_text="${alt_text//$player/$player_number}"
                if [[ "$related_index" != "-" ]]; then
                    related_number="$(number_phrase "$locale" "$related_index")"
                    alt_text="${alt_text//$related/$related_number}"
                fi
            fi
        else
            alt_text="$(alternate_command_text "$locale" "$suffix")"
        fi
        alt_voice="$voice"
        case "$locale" in
            en) alt_voice='Eddy (English (US))' ;;
            de) alt_voice='Eddy (German (Germany))' ;;
            es) alt_voice='Eddy (Spanish (Spain))' ;;
            fr) alt_voice='Eddy (French (France))' ;;
            it) alt_voice='Eddy (Italian (Italy))' ;;
        esac
        case_id="${locale}-${suffix}-number"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_id" "$locale" "$category" "number-variant" "$alt_voice" "$alt_text" "$zh" "$event" "$player" "$gender" "$script" "$related" "$case_id.wav" >> "$manifest_path"
    done
}

emit_locale 'zh-Hans' 'Tingting' \
    '张三' '李四' '王五' '赵丽' '刘芳' '陈杰' 'Emma' 'Michael' 'Alice' 'John' '王Emma' 'David' <<'ROWS'
two-made|__P__ 两分 命中|__P__ 2分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ 两分 没中|__P__ 2分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ 三分 命中|__P__ 3分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ 三分 没中|__P__ 3分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ 加罚 命中|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ 加罚 没中|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ 罚球 命中|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ 罚球 没中|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ 上篮 命中|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ 上篮 没中|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ 中投 命中|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ 中投 没中|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ 篮下 命中|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ 篮下 没中|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ 补篮 命中|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ 补篮 没中|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ 扣篮 命中|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ 扣篮 没中|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ 犯规|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ 篮板|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ 前场篮板|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ 后场篮板|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ 助攻|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ 盖帽|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ 抢断|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ 失误|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ 助攻 __R__ 两分|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ 助攻 __R__ 三分|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ 抢断 __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|开始|开始比赛|event.period|command|-|-|-|-
pause|暂停|暂停比赛|event.pause|command|-|-|-|-
game-end|结束|结束比赛|event.game_end|command|-|-|-|-
undo|撤销|撤销上一条|event.undo|command|-|-|-|-
redo|重做|重做上一条|event.redo|command|-|-|-|-
substitution|张三 换人 李四|张三换下，李四上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'zh-Hant-TW' 'Meijia' \
    '張三' '李四' '王五' '趙麗' '劉芳' '陳杰' 'Emma' 'Michael' 'Alice' 'John' '王Emma' 'David' <<'ROWS'
two-made|__P__ 兩分 命中|__P__ 2分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ 兩分 沒中|__P__ 2分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ 三分 命中|__P__ 3分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ 三分 沒中|__P__ 3分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ 加罰 命中|__P__ 加罰命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ 加罰 沒中|__P__ 加罰不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ 罰球 命中|__P__ 罰球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ 罰球 沒中|__P__ 罰球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ 上籃 命中|__P__ 上籃命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ 上籃 沒中|__P__ 上籃不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ 中投 命中|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ 中投 沒中|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ 籃下 命中|__P__ 籃下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ 籃下 沒中|__P__ 籃下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ 補籃 命中|__P__ 補籃命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ 補籃 沒中|__P__ 補籃不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ 扣籃 命中|__P__ 扣籃命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ 扣籃 沒中|__P__ 扣籃不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ 犯規|__P__ 犯規|stat.foul|stat|7|-|-|-
rebound|__P__ 籃板|__P__ 籃板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ 前場籃板|__P__ 前場籃板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ 後場籃板|__P__ 後場籃板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ 助攻|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ 蓋帽|__P__ 蓋帽|stat.block|stat|12|-|-|-
steal|__P__ 抄截|__P__ 抄截|stat.steal|stat|1|-|-|-
turnover|__P__ 失誤|__P__ 失誤|stat.turnover|stat|2|-|-|-
assist-two|__P__ 助攻 __R__ 兩分|__P__ 助攻 __R__ 兩分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ 助攻 __R__ 三分|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ 抄截 __R__|__P__ 抄截 __R__ 並造成失誤|stat.stealTurnover|composite|7|-|-|8
start|開始|開始比賽|event.period|command|-|-|-|-
pause|暫停|暫停比賽|event.pause|command|-|-|-|-
game-end|結束|結束比賽|event.game_end|command|-|-|-|-
undo|撤銷|撤銷上一條|event.undo|command|-|-|-|-
redo|重做|重做上一條|event.redo|command|-|-|-|-
substitution|張三 換人 李四|張三換下，李四上場|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'en' 'Samantha' \
    'James Carter' 'Emily Stone' 'Michael Brown' 'Olivia Davis' 'Liam Wilson' 'Sophia Taylor' 'Noah Anderson' 'Ava Martin' 'Zhang San' 'Ethan Lee' 'Grace Wang' 'Juan Garcia' <<'ROWS'
two-made|__P__ got two|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ missed two|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ got three|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ missed three|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ got and one|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ missed and one|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ got free throw|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ missed free throw|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ got layup|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ missed layup|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ got mid range|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ missed mid range|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ got paint|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ missed paint|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ got putback|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ missed putback|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ got dunk|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ missed dunk|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ foul|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ rebound|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ offensive rebound|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ defensive rebound|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ assist|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ block|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ steal|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ turnover|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ assist __R__ two|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ assist __R__ three|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ steal __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|start|开始比赛|event.period|command|-|-|-|-
pause|timeout|暂停比赛|event.pause|command|-|-|-|-
game-end|game over|结束比赛|event.game_end|command|-|-|-|-
undo|undo|撤销上一条|event.undo|command|-|-|-|-
redo|redo|重做上一条|event.redo|command|-|-|-|-
substitution|James Carter substitution Emily Stone|James Carter 换下，Emily Stone 上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'ja' 'Kyoko' \
    '山田太郎' '佐藤健' '鈴木翔' '田中美咲' '高橋愛' '伊藤葵' '小林拓真' '中村蓮' '渡辺結衣' '加藤直樹' '山田花子' '吉田陽子' <<'ROWS'
two-made|__P__ ツー 成功|__P__ 2分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ ツー 外した|__P__ 2分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ スリー 成功|__P__ 3分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ スリー 外した|__P__ 3分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ ボーナス 成功|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ ボーナス 外した|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ フリースロー 成功|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ フリースロー 外した|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ レイアップ 成功|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ レイアップ 外した|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ ミドル 成功|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ ミドル 外した|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ ペイント 成功|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ ペイント 外した|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ パットバック 成功|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ パットバック 外した|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ ダンク 成功|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ ダンク 外した|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ ファウル|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ リバウンド|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ オフェンスリバウンド|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ ディフェンスリバウンド|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ アシスト|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ ブロック|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ スティール|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ ターンオーバー|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ アシスト __R__ ツー|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ アシスト __R__ スリー|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ スティール __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|開始|开始比赛|event.period|command|-|-|-|-
pause|タイムアウト|暂停比赛|event.pause|command|-|-|-|-
game-end|試合終了|结束比赛|event.game_end|command|-|-|-|-
undo|元に戻す|撤销上一条|event.undo|command|-|-|-|-
redo|やり直す|重做上一条|event.redo|command|-|-|-|-
substitution|山田太郎 交代 佐藤健|山田太郎换下，佐藤健上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'ko' 'Yuna' \
    '김민수' '이준호' '박지훈' '최서연' '김하늘' '정수빈' '강민재' '윤서준' '한지우' '송예린' '김수아' '오지훈' <<'ROWS'
two-made|__P__ 투 성공|__P__ 2分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ 투 실패|__P__ 2分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ 쓰리 성공|__P__ 3分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ 쓰리 실패|__P__ 3分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ 보너스 성공|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ 보너스 실패|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ 자유투 성공|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ 자유투 실패|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ 레이업 성공|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ 레이업 실패|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ 미드 성공|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ 미드 실패|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ 페인트 성공|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ 페인트 실패|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ 팟백 성공|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ 팟백 실패|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ 덩크 성공|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ 덩크 실패|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ 파울|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ 리바운드|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ 공격 리바운드|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ 수비 리바운드|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ 어시스트|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ 블록|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ 스틸|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ 턴오버|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ 어시스트 __R__ 투|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ 어시스트 __R__ 쓰리|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ 스틸 __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|시작|开始比赛|event.period|command|-|-|-|-
pause|타임아웃|暂停比赛|event.pause|command|-|-|-|-
game-end|경기종료|结束比赛|event.game_end|command|-|-|-|-
undo|실행 취소|撤销上一条|event.undo|command|-|-|-|-
redo|재실행|重做上一条|event.redo|command|-|-|-|-
substitution|김민수 교체 이준호|김민수换下，李俊浩上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'de' 'Anna' \
    'Lukas Weber' 'Anna Fischer' 'Michael Müller' 'Sophie Schmidt' 'Thomas Wagner' 'Emma Keller' 'David' 'Alice' 'James' 'Olivia' 'Zhang王' '李四' <<'ROWS'
two-made|__P__ zwei getroffen|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ zwei verfehlt|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ drei getroffen|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ drei verfehlt|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ bonus getroffen|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ bonus verfehlt|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ freiwurf getroffen|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ freiwurf verfehlt|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ layup getroffen|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ layup verfehlt|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ mitteldistanz getroffen|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ mitteldistanz verfehlt|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ korbnähe getroffen|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ korbnähe verfehlt|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ putback getroffen|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ putback verfehlt|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ dunk getroffen|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ dunk verfehlt|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ foul|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ rebound|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ offensiv rebound|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ defensiv rebound|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ assist|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ block|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ steal|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ turnover|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ assist __R__ zwei|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ assist __R__ drei|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ steal __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|start|开始比赛|event.period|command|-|-|-|-
pause|auszeit|暂停比赛|event.pause|command|-|-|-|-
game-end|spielende|结束比赛|event.game_end|command|-|-|-|-
undo|rückgängig|撤销上一条|event.undo|command|-|-|-|-
redo|wiederholen|重做上一条|event.redo|command|-|-|-|-
substitution|Lukas Weber wechsel Anna Fischer|Lukas Weber换下，Anna Fischer上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'es' 'Mónica' \
    'Carlos García' 'María López' 'Juan Pérez' 'Ana Torres' 'Diego Ruiz' 'Laura Martín' 'Emma' 'Michael' 'Alice' 'John' 'GarcíaEmma' 'David' <<'ROWS'
two-made|__P__ dos anotó|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ dos fallado|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ tres anotó|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ tres fallado|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ y uno anotó|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ y uno fallado|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ tiro libre anotó|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ tiro libre fallado|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ bandeja anotó|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ bandeja fallado|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ media distancia anotó|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ media distancia fallado|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ pintura anotó|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ pintura fallado|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ putback anotó|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ putback fallado|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ mate anotó|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ mate fallado|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ falta|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ rebote|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ rebote ofensivo|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ rebote defensivo|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ asistencia|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ bloqueo|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ robo|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ perdida|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ asistencia __R__ dos|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ asistencia __R__ tres|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ robo __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|inicio|开始比赛|event.period|command|-|-|-|-
pause|tiempo muerto|暂停比赛|event.pause|command|-|-|-|-
game-end|fin del partido|结束比赛|event.game_end|command|-|-|-|-
undo|deshacer|撤销上一条|event.undo|command|-|-|-|-
redo|rehacer|重做上一条|event.redo|command|-|-|-|-
substitution|Carlos García cambio María López|Carlos García换下，María López上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'fr' 'Thomas' \
    'Jean Martin' 'Claire Dubois' 'Lucas Bernard' 'Sophie Laurent' 'Thomas Petit' 'Léa Moreau' 'Emma' 'Michael' 'Alice' 'John' 'Martin王' 'David' <<'ROWS'
two-made|__P__ deux réussi|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ deux raté|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ trois réussi|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ trois raté|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ et un réussi|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ et un raté|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ lancer franc réussi|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ lancer franc raté|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ lay-up réussi|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ lay-up raté|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ mi-distance réussi|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ mi-distance raté|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ intérieur réussi|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ intérieur raté|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ putback réussi|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ putback raté|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ dunk réussi|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ dunk raté|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ faute|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ rebond|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ rebond offensif|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ rebond défensif|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ passe|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ contre|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ interception|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ perte de balle|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ passe __R__ deux|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ passe __R__ trois|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ interception __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|début|开始比赛|event.period|command|-|-|-|-
pause|temps mort|暂停比赛|event.pause|command|-|-|-|-
game-end|fin du match|结束比赛|event.game_end|command|-|-|-|-
undo|annuler|撤销上一条|event.undo|command|-|-|-|-
redo|refaire|重做上一条|event.redo|command|-|-|-|-
substitution|Jean Martin remplacement Claire Dubois|Jean Martin换下，Claire Dubois上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'it' 'Alice' \
    'Marco Rossi' 'Giulia Bianchi' 'Luca Romano' 'Sofia Conti' 'Matteo Gallo' 'Chiara Esposito' 'Emma' 'Michael' 'Alice' 'John' 'Rossi王' 'David' <<'ROWS'
two-made|__P__ due segnato|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ due sbagliato|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ tre segnato|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ tre sbagliato|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ bonus segnato|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ bonus sbagliato|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ tiro libero segnato|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ tiro libero sbagliato|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ layup segnato|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ layup sbagliato|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ media distanza segnato|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ media distanza sbagliato|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ dentro segnato|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ dentro sbagliato|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ putback segnato|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ putback sbagliato|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ schiacciata segnata|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ schiacciata sbagliata|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ fallo|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ rimbalzo|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ rimbalzo offensivo|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ rimbalzo difensivo|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ assist|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ stoppata|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ palla rubata|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ perse|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ assist __R__ due|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ assist __R__ tre|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ palla rubata __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|inizio|开始比赛|event.period|command|-|-|-|-
pause|timeout|暂停比赛|event.pause|command|-|-|-|-
game-end|fine partita|结束比赛|event.game_end|command|-|-|-|-
undo|annulla|撤销上一条|event.undo|command|-|-|-|-
redo|ripeti|重做上一条|event.redo|command|-|-|-|-
substitution|Marco Rossi cambio Giulia Bianchi|Marco Rossi换下，Giulia Bianchi上场|event.substitution|substitution|1|-|-|2
ROWS

emit_locale 'ru' 'Milena' \
    'Иванов' 'Петров' 'Алексей Смирнов' 'Мария Иванова' 'Анна Петрова' 'Сергей Кузнецов' 'Emma' 'Michael' 'Alice' 'John' 'ИванEmma' 'David' <<'ROWS'
two-made|__P__ два попал|__P__ 两分命中|stat.twoMade|shot|1|-|-|-
two-missed|__P__ два промах|__P__ 两分不中|stat.twoMissed|shot|2|-|-|-
three-made|__P__ три попал|__P__ 三分命中|stat.threeMade|shot|3|-|-|-
three-missed|__P__ три промах|__P__ 三分不中|stat.threeMissed|shot|4|-|-|-
bonus-made|__P__ бонус попал|__P__ 加罚命中|stat.bonusMade|shot|5|-|-|-
bonus-missed|__P__ бонус промах|__P__ 加罚不中|stat.bonusMissed|shot|6|-|-|-
free-throw-made|__P__ штрафной попал|__P__ 罚球命中|stat.freeThrowMade|shot|7|-|-|-
free-throw-missed|__P__ штрафной промах|__P__ 罚球不中|stat.freeThrowMissed|shot|8|-|-|-
layup-made|__P__ лей-ап попал|__P__ 上篮命中|stat.layupMade|shot|9|-|-|-
layup-missed|__P__ лей-ап промах|__P__ 上篮不中|stat.layupMissed|shot|10|-|-|-
mid-range-made|__P__ средний попал|__P__ 中投命中|stat.midRangeMade|shot|11|-|-|-
mid-range-missed|__P__ средний промах|__P__ 中投不中|stat.midRangeMissed|shot|12|-|-|-
paint-made|__P__ краска попал|__P__ 篮下命中|stat.paintMade|shot|1|-|-|-
paint-missed|__P__ краска промах|__P__ 篮下不中|stat.paintMissed|shot|2|-|-|-
putback-made|__P__ putback попал|__P__ 补篮命中|stat.putbackMade|shot|3|-|-|-
putback-missed|__P__ putback промах|__P__ 补篮不中|stat.putbackMissed|shot|4|-|-|-
dunk-made|__P__ данк попал|__P__ 扣篮命中|stat.dunkMade|shot|5|-|-|-
dunk-missed|__P__ данк промах|__P__ 扣篮不中|stat.dunkMissed|shot|6|-|-|-
foul|__P__ фол|__P__ 犯规|stat.foul|stat|7|-|-|-
rebound|__P__ подбор|__P__ 篮板|stat.rebound|stat|8|-|-|-
offensive-rebound|__P__ подбор в нападении|__P__ 前场篮板|stat.offensiveRebound|stat|9|-|-|-
defensive-rebound|__P__ подбор в защите|__P__ 后场篮板|stat.defensiveRebound|stat|10|-|-|-
assist|__P__ передача|__P__ 助攻|stat.assist|stat|11|-|-|-
block|__P__ блок|__P__ 盖帽|stat.block|stat|12|-|-|-
steal|__P__ перехват|__P__ 抢断|stat.steal|stat|1|-|-|-
turnover|__P__ потеря|__P__ 失误|stat.turnover|stat|2|-|-|-
assist-two|__P__ передача __R__ два|__P__ 助攻 __R__ 两分|stat.assistTwoMade|composite|3|-|-|4
assist-three|__P__ передача __R__ три|__P__ 助攻 __R__ 三分|stat.assistThreeMade|composite|5|-|-|6
steal-turnover|__P__ перехват __R__|__P__ 抢断 __R__ 并造成失误|stat.stealTurnover|composite|7|-|-|8
start|начало|开始比赛|event.period|command|-|-|-|-
pause|тайм-аут|暂停比赛|event.pause|command|-|-|-|-
game-end|конец игры|结束比赛|event.game_end|command|-|-|-|-
undo|отменить|撤销上一条|event.undo|command|-|-|-|-
redo|повторить|重做上一条|event.redo|command|-|-|-|-
substitution|Иванов замена Петров|Иванов换下，彼得罗夫上场|event.substitution|substitution|1|-|-|2
ROWS
