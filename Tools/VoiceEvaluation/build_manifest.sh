#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
manifest_path="${1:-$script_dir/manifest.tsv}"

mkdir -p "${manifest_path:h}"
printf '%s\n' 'case_id	locale	category	variant	voice	localized_text	zh_translation	expected_event	expected_player	player_gender	name_script	expected_related_player	wav_file' > "$manifest_path"

emit_locale() {
    local locale="$1"
    local voice="$2"
    shift 2
    local -a names=("$@")
    local suffix text zh event category player_index related_index player gender script related

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
            if (( player_index <= 6 )); then
                script="native"
            elif (( player_index == 11 )); then
                script="mixed"
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
        local case_id="${locale}-${suffix}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_id" "$locale" "$category" "canonical" "$voice" "$text" "$zh" "$event" "$player" "$gender" "$script" "$related" "$case_id.wav" >> "$manifest_path"
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

emit_locale 'en' 'Eddy (English (US))' \
    'James Carter' 'Emily Stone' 'Michael Brown' 'Olivia Davis' 'Liam Wilson' 'Sophia Taylor' 'Noah Anderson' 'Ava Martin' 'Zhang San' '李四' 'Emma王' 'Juan Garcia' <<'ROWS'
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

emit_locale 'ja' 'Eddy (Japanese (Japan))' \
    '山田太郎' '佐藤健' '鈴木翔' '田中美咲' '高橋愛' '伊藤葵' 'Emma' 'Michael' 'Alice' 'John' '山田Emma' 'David' <<'ROWS'
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

emit_locale 'ko' 'Eddy (Korean (South Korea))' \
    '김민수' '이준호' '박지훈' '최서연' '김하늘' '정수빈' 'Emma' 'Michael' 'Alice' 'John' '김Emma' 'David' <<'ROWS'
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

emit_locale 'de' 'Eddy (German (Germany))' \
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

emit_locale 'es' 'Eddy (Spanish (Spain))' \
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

emit_locale 'fr' 'Eddy (French (France))' \
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

emit_locale 'it' 'Eddy (Italian (Italy))' \
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
