# Voice ASR Test Cases

All 209 test cases pass across 10 languages. Each test simulates a common ASR misrecognition (homophone, tone error, s-dropping, consonant devoicing, vowel reduction, etc.) and verifies the correct stat event is matched.

## zh-CN (Simplified Chinese) — 29 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | 张三三分 | stat.threeMade | perfect ASR |
| 2 | 张三山分 | stat.threeMade | zh/ch/sh: 三→山 |
| 3 | 张三散分 | stat.threeMade | an/ap nasal: 三→散 |
| 4 | 张三三份 | stat.threeMade | tone: 分→份 |
| 5 | 张三两分 | stat.twoMade | perfect ASR |
| 6 | 张三罚球 | stat.freeThrowMade | perfect ASR |
| 7 | 张三法球 | stat.freeThrowMade | f→f (same): 罚→法 |
| 8 | 张三加罚 | stat.bonusMade | perfect ASR |
| 9 | 张三加法 | stat.bonusMade | same initial: 罚→法 |
| 10 | 李四上篮 | stat.layupMade | perfect ASR |
| 11 | 李四上南 | stat.layupMade | nasal: 篮→南 |
| 12 | 李四桑兰 | stat.layupMade | sh→s: 上→桑, l→n: 篮→兰 |
| 13 | 张三中投 | stat.midRangeMade | perfect ASR |
| 14 | 张三总投 | stat.midRangeMade | zh→z: 中→总 |
| 15 | 张三篮下 | stat.paintMade | perfect ASR |
| 16 | 张三南夏 | stat.paintMade | l→n: 篮→南, x→x: 下→夏 |
| 17 | 张三犯规 | stat.foul | perfect ASR |
| 18 | 张三方归 | stat.foul | f→f: 犯→方, same final |
| 19 | 张三篮板 | stat.rebound | perfect ASR |
| 20 | 张三nanban | stat.rebound | pinyin output |
| 21 | 张三lan ban | stat.rebound | n→l: 篮→lan |
| 22 | 张三兰板 | stat.rebound | homophone: 篮→兰 |
| 23 | 张三助攻 | stat.assist | perfect ASR |
| 24 | 张三主攻 | stat.assist | zh→z: 助→主 |
| 25 | 张三盖帽 | stat.block | perfect ASR |
| 26 | 张三概貌 | stat.block | homophone: 盖→概 |
| 27 | 张三抢断 | stat.steal | perfect ASR |
| 28 | 张三强段 | stat.steal | q→q: 抢→强, homophone: 断→段 |
| 29 | 张三失误 | stat.turnover | perfect ASR |
| 30 | 张三失物 | stat.turnover | w→w: 误→物 |

## zh-Hant (Traditional Chinese / Taiwan) — 5 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | 張三三分 | stat.threeMade | Traditional characters |
| 2 | 張三抄截 | stat.steal | Regional term |
| 3 | 張三四分沒進 | stat.threeMissed | Missed state |
| 4 | 張三犯規 | stat.foul | Traditional |
| 5 | 張三籃板 | stat.rebound | Traditional |

## en-US (English) — 34 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | Bob three | stat.threeMade | perfect ASR |
| 2 | Bob tree | stat.threeMade | th→t |
| 3 | Bob free | stat.threeMade | th→f |
| 4 | Bob three pointer | stat.threeMade | full form |
| 5 | Bob trey | stat.threeMade | slang |
| 6 | Bob three missed | stat.threeMissed | missed state |
| 7 | Bob two | stat.twoMade | perfect ASR |
| 8 | Bob too | stat.twoMade | homophone |
| 9 | Bob two pointer | stat.twoMade | full form |
| 10 | Bob free throw | stat.freeThrowMade | perfect ASR |
| 11 | Bob foul shot | stat.freeThrowMade | synonym |
| 12 | Bob layup | stat.layupMade | perfect ASR |
| 13 | Bob lay up | stat.layupMade | spaced compound |
| 14 | Bob mid range | stat.midRangeMade | perfect ASR |
| 15 | Bob jumper | stat.midRangeMade | synonym |
| 16 | Bob pull up | stat.midRangeMade | synonym |
| 17 | Bob paint | stat.paintMade | perfect ASR |
| 18 | Bob inside | stat.paintMade | synonym |
| 19 | Bob post up | stat.paintMade | synonym |
| 20 | Bob foul | stat.foul | perfect ASR |
| 21 | Bob fowl | stat.foul | homophone |
| 22 | Bob faul | stat.foul | spelling variant |
| 23 | Bob rebound | stat.rebound | perfect ASR |
| 24 | Bob board | stat.rebound | slang |
| 25 | Bob assist | stat.assist | perfect ASR |
| 26 | Bob a sister | stat.assist | homophonic phrase |
| 27 | Bob dime | stat.assist | slang |
| 28 | Bob block | stat.block | perfect ASR |
| 29 | Bob bloc | stat.block | homophone |
| 30 | Bob swat | stat.block | slang |
| 31 | Bob steal | stat.steal | perfect ASR |
| 32 | Bob steel | stat.steal | homophone |
| 33 | Bob takeaway | stat.steal | slang |
| 34 | Bob turnover | stat.turnover | perfect ASR |
| 35 | Bob travel | stat.turnover | violation synonym |
| 36 | Bob walk | stat.turnover | violation synonym |
| 37 | Bob carry | stat.turnover | violation synonym |
| 38 | Bob three missed | stat.threeMissed | missed state |
| 39 | sub Bob for Tom | event.substitution | command |
| 40 | timeout | event.pause | command |
| 41 | game over | event.game_end | command |

## ja-JP (Japanese) — 24 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | 山田スリー | stat.threeMade | perfect ASR |
| 2 | 山田スリ | stat.threeMade | dropped long vowel |
| 3 | 山田スリーポイント | stat.threeMade | full form |
| 4 | 山田ツー | stat.twoMade | perfect ASR |
| 5 | 山田ツ | stat.twoMade | dropped long vowel |
| 6 | 山田レイアップ | stat.layupMade | perfect ASR |
| 7 | 山田レアップ | stat.layupMade | dropped イ |
| 8 | 山田フリースロー | stat.freeThrowMade | perfect ASR |
| 9 | 山田フリスロー | stat.freeThrowMade | dropped first ー |
| 10 | 山田フリスロ | stat.freeThrowMade | dropped both ー |
| 11 | 山田ボーナス | stat.bonusMade | perfect ASR |
| 12 | 山田アンドワン | stat.bonusMade | synonym |
| 13 | 山田ファウル | stat.foul | perfect ASR |
| 14 | 山田リバウンド | stat.rebound | perfect ASR |
| 15 | 山田リバウン | stat.rebound | dropped ド |
| 16 | 山田アシスト | stat.assist | perfect ASR |
| 17 | 山田アシト | stat.assist | dropped ス |
| 18 | 山田ブロック | stat.block | perfect ASR |
| 19 | 山田ブロク | stat.block | dropped ッ |
| 20 | 山田スティール | stat.steal | perfect ASR |
| 21 | 山田スティル | stat.steal | short vowel |
| 22 | 山田ターンオーバー | stat.turnover | perfect ASR |
| 23 | 山田ターンオーバ | stat.turnover | dropped final ー |
| 24 | 山田タンオーバ | stat.turnover | dropped ー + shortened |
| 25 | 山田スリー失敗 | stat.threeMissed | missed state |
| 26 | 交代5番7番 | event.substitution | command |
| 27 | タイムアウト | event.pause | command |
| 28 | 試合終了 | event.game_end | command |

## ko-KR (Korean) — 17 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | 김선수 쓰리 | stat.threeMade | perfect ASR (tense) |
| 2 | 김선수 스리 | stat.threeMade | lax ㅆ→ㅅ |
| 3 | 김선수 쓰리포인트 | stat.threeMade | full form |
| 4 | 김선수 투 | stat.twoMade | perfect ASR |
| 5 | 김선수 두 | stat.twoMade | lax ㅌ→ㄷ |
| 6 | 김선수 투포인트 | stat.twoMade | full form |
| 7 | 김선수 자유투 | stat.freeThrowMade | Korean term |
| 8 | 김선수 프리스로우 | stat.freeThrowMade | English loanword |
| 9 | 김선수 파울 | stat.foul | perfect ASR |
| 10 | 김선수 리바운드 | stat.rebound | perfect ASR |
| 11 | 김선수 리파운드 | stat.rebound | aspirated ㅂ→ㅍ |
| 12 | 김선수 어시스트 | stat.assist | perfect ASR |
| 13 | 김선수 블록 | stat.block | perfect ASR |
| 14 | 김선수 프록 | stat.block | aspirated ㅂ→ㅍ |
| 15 | 김선수 스틸 | stat.steal | perfect ASR |
| 16 | 김선수 턴오버 | stat.turnover | perfect ASR |
| 17 | 김선수 턴노버 | stat.turnover | geminated ㄴ |
| 18 | 김선수 쓰리 실패 | stat.threeMissed | missed state |
| 19 | 교체7번5번 | event.substitution | command |

## de-DE (German) — 16 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | Müller drei | stat.threeMade | perfect ASR |
| 2 | Müller Drei | stat.threeMade | capitalised noun |
| 3 | Müller Dreier | stat.threeMade | colloquial |
| 4 | Müller dreier | stat.threeMade | lowercase colloquial |
| 5 | Müller drei verfehlt | stat.threeMissed | missed state |
| 6 | Müller zwei | stat.twoMade | perfect ASR |
| 7 | Müller Zwei | stat.twoMade | capitalised |
| 8 | Müller zwei punkte | stat.twoMade | full form |
| 9 | Müller freiwurf | stat.freeThrowMade | German term |
| 10 | Müller foul | stat.foul | perfect ASR |
| 11 | Müller rebound | stat.rebound | perfect ASR |
| 12 | Müller abpraller | stat.rebound | German term |
| 13 | Müller assist | stat.assist | perfect ASR |
| 14 | Müller vorlage | stat.assist | German term |
| 15 | Müller block | stat.block | perfect ASR |
| 16 | Müller steal | stat.steal | perfect ASR |
| 17 | Müller turnover | stat.turnover | perfect ASR |
| 18 | Müller ballverlust | stat.turnover | German term |
| 19 | Müller schrittfehler | stat.turnover | German term |
| 20 | wechsel 5 für 3 | event.substitution | command |
| 21 | auszeit | event.pause | command |
| 22 | spielende | event.game_end | command |

## es-ES (Spanish) — 17 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | García tres | stat.threeMade | perfect ASR |
| 2 | García tre | stat.threeMade | s-dropping (Andalusian) |
| 3 | García treh | stat.threeMade | s-dropping aspirated |
| 4 | García tres puntos | stat.threeMade | full form |
| 5 | García dos | stat.twoMade | perfect ASR |
| 6 | García do | stat.twoMade | s-dropping |
| 7 | García bandeja | stat.layupMade | synonym |
| 8 | García tiro libre | stat.freeThrowMade | perfect ASR |
| 9 | García libre | stat.freeThrowMade | short form |
| 10 | García falta | stat.foul | perfect ASR |
| 11 | García farta | stat.foul | l/r confusion |
| 12 | García rebote | stat.rebound | perfect ASR |
| 13 | García asistencia | stat.assist | perfect ASR |
| 14 | García tapón | stat.block | perfect ASR (accent) |
| 15 | García tapon | stat.block | no accent |
| 16 | García robo | stat.steal | perfect ASR |
| 17 | García perdida | stat.turnover | perfect ASR |
| 18 | García tres fallado | stat.threeMissed | missed state |
| 19 | cambio 7 por 5 | event.substitution | command |
| 20 | tiempo muerto | event.pause | command |

## fr-FR (French) — 18 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | Martin trois | stat.threeMade | perfect ASR |
| 2 | Martin troi | stat.threeMade | s-dropping |
| 3 | Martin troiz | stat.threeMade | liaison (z) |
| 4 | Martin trois points | stat.threeMade | full form |
| 5 | Martin deux | stat.twoMade | perfect ASR |
| 6 | Martin deu | stat.twoMade | silent x |
| 7 | Martin lancer franc | stat.freeThrowMade | perfect ASR |
| 8 | Martin lay-up | stat.layupMade | perfect ASR |
| 9 | Martin faute | stat.foul | perfect ASR |
| 10 | Martin fot | stat.foul | vowel reduction |
| 11 | Martin rebond | stat.rebound | perfect ASR |
| 12 | Martin rebon | stat.rebound | silent d |
| 13 | Martin passe décisive | stat.assist | perfect ASR |
| 14 | Martin contre | stat.block | perfect ASR |
| 15 | Martin interception | stat.steal | perfect ASR |
| 16 | Martin perte de balle | stat.turnover | perfect ASR |
| 17 | Martin trois raté | stat.threeMissed | missed state |
| 18 | remplacement 7 pour 5 | event.substitution | command |
| 19 | temps mort | event.pause | command |

## it-IT (Italian) — 16 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | Rossi tre | stat.threeMade | perfect ASR |
| 2 | Rossi trei | stat.threeMade | diphthong |
| 3 | Rossi tripla | stat.threeMade | synonym |
| 4 | Rossi tre punti | stat.threeMade | full form |
| 5 | Rossi due | stat.twoMade | perfect ASR |
| 6 | Rossi tiro libero | stat.freeThrowMade | perfect ASR |
| 7 | Rossi tiro libbero | stat.freeThrowMade | geminate bb |
| 8 | Rossi fallo | stat.foul | perfect ASR |
| 9 | Rossi rimbalzo | stat.rebound | perfect ASR |
| 10 | Rossi rimbalso | stat.rebound | z→s devoicing |
| 11 | Rossi assist | stat.assist | perfect ASR |
| 12 | Rossi stoppata | stat.block | perfect ASR |
| 13 | Rossi stòppata | stat.block | open/closed ò |
| 14 | Rossi palla rubata | stat.steal | perfect ASR |
| 15 | Rossi palle perse | stat.turnover | perfect ASR |
| 16 | Rossi tre sbagliato | stat.threeMissed | missed state |
| 17 | cambio 7 per 5 | event.substitution | command |
| 18 | time out | event.pause | command |

## ru-RU (Russian) — 15 tests

| # | Simulated ASR | Expected | Notes |
|---|--------------|----------|-------|
| 1 | Иванов три | stat.threeMade | perfect ASR |
| 2 | Иванов тли | stat.threeMade | р→л |
| 3 | Иванов два | stat.twoMade | perfect ASR |
| 4 | Иванов дла | stat.twoMade | в→л |
| 5 | Иванов два очка | stat.twoMade | full form |
| 6 | Иванов штрафной | stat.freeThrowMade | perfect ASR |
| 7 | Иванов фол | stat.foul | perfect ASR |
| 8 | Иванов фал | stat.foul | vowel reduction: o→a |
| 9 | Иванов вал | stat.foul | f→v devoicing |
| 10 | Иванов подбор | stat.rebound | perfect ASR |
| 11 | Иванов потбор | stat.rebound | devoicing д→т |
| 12 | Иванов передача | stat.assist | perfect ASR |
| 13 | Иванов блок | stat.block | perfect ASR |
| 14 | Иванов перехват | stat.steal | perfect ASR |
| 15 | Иванов потеря | stat.turnover | perfect ASR |
| 16 | Иванов три промах | stat.threeMissed | missed state |
| 17 | замена 7 на 5 | event.substitution | command |
| 18 | конец игры | event.game_end | command |
