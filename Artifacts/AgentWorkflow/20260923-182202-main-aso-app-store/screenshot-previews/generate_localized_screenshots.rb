require "fileutils"

run_dir = File.expand_path("..", __dir__)
preview_dir = File.join(run_dir, "screenshot-previews")

features = [
  {
    source: "01-score",
    key: "score",
    palette: ["#101B39", "#223866", "#E8753D"],
    label: {
      "zh-Hans" => "实时记分",
      "zh-Hant" => "即時記分",
      "en-US" => "Live Scoring",
      "de-DE" => "Live-Scoring",
      "es-ES" => "Marcador en directo",
      "fr-FR" => "Score en direct",
      "it" => "Punteggio live",
      "ja" => "リアルタイム記録",
      "ko" => "실시간 기록",
      "ru" => "Счёт в реальном времени"
    }
  },
  {
    source: "02-stats",
    key: "stats",
    palette: ["#F7E8CF", "#E8F0FB", "#A8C9F0"],
    label: {
      "zh-Hans" => "球员统计",
      "zh-Hant" => "球員統計",
      "en-US" => "Player Stats",
      "de-DE" => "Spielerstatistik",
      "es-ES" => "Estadísticas",
      "fr-FR" => "Statistiques",
      "it" => "Statistiche",
      "ja" => "選手スタッツ",
      "ko" => "선수 통계",
      "ru" => "Статистика игроков"
    }
  },
  {
    source: "03-detail",
    key: "review",
    palette: ["#FFF8ED", "#F1D1B1", "#DB6A35"],
    label: {
      "zh-Hans" => "赛后复盘",
      "zh-Hant" => "賽後回顧",
      "en-US" => "Game Review",
      "de-DE" => "Spielanalyse",
      "es-ES" => "Revisión del partido",
      "fr-FR" => "Analyse du match",
      "it" => "Analisi della partita",
      "ja" => "試合レビュー",
      "ko" => "경기 리뷰",
      "ru" => "Разбор матча"
    }
  },
  {
    source: "04-player",
    key: "team",
    palette: ["#102344", "#345C8B", "#E5A15C"],
    label: {
      "zh-Hans" => "球队与球员",
      "zh-Hant" => "球隊與球員",
      "en-US" => "Teams & Players",
      "de-DE" => "Teams & Spieler",
      "es-ES" => "Equipos y jugadores",
      "fr-FR" => "Équipes et joueurs",
      "it" => "Squadre e giocatori",
      "ja" => "チームと選手",
      "ko" => "팀과 선수",
      "ru" => "Команды и игроки"
    }
  },
  {
    source: "05-more",
    key: "growth",
    palette: ["#EFF6FF", "#D6E5F7", "#F2B574"],
    label: {
      "zh-Hans" => "AI 与数据",
      "zh-Hant" => "AI 與資料",
      "en-US" => "AI & Data",
      "de-DE" => "KI & Daten",
      "es-ES" => "IA y datos",
      "fr-FR" => "IA et données",
      "it" => "IA e dati",
      "ja" => "AIとデータ",
      "ko" => "AI와 데이터",
      "ru" => "ИИ и данные"
    }
  }
]

locales = {
  "zh-Hans" => {
    name: "篮球生涯手帐",
    eyebrow: "篮球生涯手帐 · 1.39",
    copy: [
      ["比赛，正在发生", "实时记分，动作一键记录", "比分、事件和球员表现，全部留在比赛现场。"],
      ["每一个数据点都算数", "球员与球队统计，赛后马上复盘", "从比分到命中率，把一场比赛看得更清楚。"],
      ["看懂一场比赛", "比分、效率、表现一次看清", "按节次回看，找到真正改变比赛的瞬间。"],
      ["把球队管理好", "球员资料与阵容，随时可查", "头像、号码、位置和生涯数据，统一管理。"],
      ["从记录到成长", "AI 总结、同步与数据导出", "让每一场比赛，都能变成下一次进步的线索。"]
    ]
  },
  "zh-Hant" => {
    name: "籃球記分",
    eyebrow: "籃球記分 · 1.39",
    copy: [
      ["比賽，正在發生", "即時記分，動作一鍵記錄", "比分、事件與球員表現，全部留在比賽現場。"],
      ["每一個數據點都重要", "球員與球隊統計，賽後立即回顧", "從比分到命中率，一場比賽看得更清楚。"],
      ["看懂一場比賽", "比分、效率、表現一次看清", "按節次回看，找到改變比賽的關鍵時刻。"],
      ["管理好你的球隊", "球員資料與陣容，隨時可查", "頭像、號碼、位置與生涯數據，集中管理。"],
      ["從記錄到成長", "AI 總結、同步與資料匯出", "讓每一場比賽，都成為下一次進步的線索。"]
    ]
  },
  "en-US" => {
    name: "Basketball Journal",
    eyebrow: "BASKETBALL JOURNAL · 1.39",
    copy: [
      ["Game time", "Live scoring, one tap per action", "Keep the score, events, and player performance together."],
      ["Every stat counts", "Team and player stats, ready after the final whistle", "See the game from the score to shooting efficiency."],
      ["Understand the game", "Score, efficiency, and performance at a glance", "Review by period and find the turning points."],
      ["Keep your team organized", "Rosters and player profiles, always at hand", "Photos, numbers, positions, and career stats in one place."],
      ["From records to progress", "AI summaries, sync, and data export", "Turn every game into the next step forward."]
    ]
  },
  "de-DE" => {
    name: "Basketball Scorebook",
    eyebrow: "BASKETBALL SCOREBOOK · 1.39",
    copy: [
      ["Das Spiel läuft", "Live-Scoring, jede Aktion sofort erfassen", "Punkte, Ereignisse und Spielerleistung an einem Ort."],
      ["Jede Statistik zählt", "Team- und Spielerdaten direkt nach dem Abpfiff", "Vom Ergebnis bis zur Wurfquote alles im Blick."],
      ["Das Spiel verstehen", "Punkte, Effizienz und Leistung auf einen Blick", "Nach Perioden zurückblicken und Wendepunkte finden."],
      ["Dein Team im Griff", "Kader und Spielerprofile jederzeit bereit", "Fotos, Nummern, Positionen und Karrierestatistiken an einem Ort."],
      ["Von Daten zu Fortschritt", "KI-Zusammenfassung, Sync und Export", "Jedes Spiel wird zum nächsten Schritt."]
    ]
  },
  "es-ES" => {
    name: "Diario Basket",
    eyebrow: "DIARIO BASKET · 1.39",
    copy: [
      ["El partido empieza", "Anota en directo, una acción cada vez", "Puntos, eventos y rendimiento, todo en un mismo lugar."],
      ["Cada dato cuenta", "Estadísticas de equipo y jugador tras el pitido final", "Del marcador a la eficacia de tiro, todo claro."],
      ["Entiende el partido", "Puntos, eficacia y rendimiento de un vistazo", "Repasa por periodos y encuentra los momentos clave."],
      ["Organiza tu equipo", "Plantillas y perfiles siempre a mano", "Fotos, dorsales, posiciones y estadísticas de carrera."],
      ["Del registro al progreso", "Resúmenes IA, sincronización y exportación", "Convierte cada partido en tu próximo paso."]
    ]
  },
  "fr-FR" => {
    name: "Basketball Scorebook",
    eyebrow: "BASKETBALL SCOREBOOK · 1.39",
    copy: [
      ["Le match commence", "Score en direct, chaque action en un geste", "Scores, événements et performances au même endroit."],
      ["Chaque statistique compte", "Données d’équipe et de joueurs après le match", "Du score à l’efficacité de tir, tout est clair."],
      ["Comprendre le match", "Score, efficacité et performances en un coup d’œil", "Revoyez chaque période et trouvez les moments clés."],
      ["Gérez votre équipe", "Effectif et profils toujours à portée de main", "Photos, numéros, postes et statistiques de carrière."],
      ["Des données aux progrès", "Résumés IA, synchronisation et export", "Faites de chaque match un pas en avant."]
    ]
  },
  "it" => {
    name: "Basketball Scorebook",
    eyebrow: "BASKETBALL SCOREBOOK · 1.39",
    copy: [
      ["La partita è iniziata", "Segna in tempo reale, un’azione alla volta", "Punteggio, eventi e rendimento sempre insieme."],
      ["Ogni dato conta", "Statistiche di squadra e giocatori dopo la sirena", "Dal punteggio all’efficienza al tiro, tutto chiaro."],
      ["Capisci la partita", "Punteggio, efficienza e rendimento a colpo d’occhio", "Rivedi ogni periodo e trova i momenti chiave."],
      ["Gestisci la tua squadra", "Rosa e profili sempre a portata di mano", "Foto, numeri, ruoli e statistiche di carriera."],
      ["Dai dati ai progressi", "Riepiloghi IA, sincronizzazione ed export", "Trasforma ogni partita nel prossimo passo."]
    ]
  },
  "ja" => {
    name: "バスケ記録",
    eyebrow: "バスケ記録 · 1.39",
    copy: [
      ["試合が始まる", "リアルタイム記録、プレーをワンタップで入力", "スコア、イベント、選手の活躍をひとつに。"],
      ["すべての数字に意味がある", "チームと選手のスタッツを試合後すぐ確認", "スコアからシュート効率まで見やすく整理。"],
      ["試合を深く知る", "スコア、効率、活躍をひと目で", "ピリオドごとに振り返り、勝負を分けた瞬間を発見。"],
      ["チームをスマートに管理", "ロスターと選手プロフィールをいつでも確認", "写真、背番号、ポジション、キャリアデータを一元管理。"],
      ["記録を成長につなげる", "AI要約、同期、データ出力", "すべての試合を次の成長のヒントに。"]
    ]
  },
  "ko" => {
    name: "농구 기록",
    eyebrow: "농구 기록 · 1.39",
    copy: [
      ["경기가 시작됩니다", "실시간 기록, 한 번의 탭으로 액션 입력", "점수, 이벤트, 선수 활약을 한곳에."],
      ["모든 기록이 중요합니다", "경기 후 팀과 선수 통계를 바로 확인", "점수부터 슈팅 효율까지 한눈에."],
      ["경기를 이해하세요", "점수, 효율, 활약을 한눈에", "쿼터별로 돌아보고 승부처를 찾으세요."],
      ["팀을 깔끔하게 관리하세요", "로스터와 선수 프로필을 언제든 확인", "사진, 번호, 포지션, 커리어 통계를 한곳에."],
      ["기록을 성장으로", "AI 요약, 동기화, 데이터 내보내기", "모든 경기를 다음 발전의 단서로."]
    ]
  },
  "ru" => {
    name: "Basketball Scorebook",
    eyebrow: "BASKETBALL SCOREBOOK · 1.39",
    copy: [
      ["Игра начинается", "Счёт в реальном времени, каждое действие — в одно касание", "Очки, события и игра каждого игрока — в одном месте."],
      ["Важна каждая цифра", "Статистика команды и игроков сразу после матча", "От счёта до эффективности бросков — всё под контролем."],
      ["Поймите игру", "Счёт, эффективность и вклад игроков — с первого взгляда", "Просматривайте периоды и находите ключевые моменты."],
      ["Управляйте командой", "Составы и профили игроков всегда под рукой", "Фото, номера, позиции и карьерная статистика в одном месте."],
      ["От записей к прогрессу", "ИИ-итоги, синхронизация и экспорт данных", "Превращайте каждый матч в следующий шаг."]
    ]
  }
}

def xml_escape(value)
  value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
end

locales.each do |locale, data|
  features.each_with_index do |feature, index|
    primary, secondary, detail = data[:copy][index]
    c1, c2, c3 = feature[:palette]
    file = File.join(preview_dir, "#{locale}-#{format('%02d', index + 1)}-#{feature[:key]}.svg")
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="1242" height="2688" viewBox="0 0 1242 2688">
        <defs>
          <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#{c1}"/><stop offset="0.56" stop-color="#{c2}"/><stop offset="1" stop-color="#{c3}"/></linearGradient>
          <filter id="shadow" x="-30%" y="-20%" width="160%" height="160%"><feDropShadow dx="0" dy="26" stdDeviation="28" flood-color="#081126" flood-opacity="0.32"/></filter>
          <clipPath id="phone"><rect x="184" y="680" width="874" height="1895" rx="58"/></clipPath>
        </defs>
        <rect width="1242" height="2688" fill="url(#bg)"/>
        <circle cx="1080" cy="240" r="220" fill="#E8753D" opacity="0.16"/>
        <circle cx="1080" cy="240" r="130" fill="none" stroke="#F6C36A" stroke-width="4" opacity="0.34"/>
        <path d="M-100 440 C220 640 520 150 830 440 S1220 720 1380 460" fill="none" stroke="#F7E8CF" stroke-width="5" opacity="0.22"/>
        <text x="92" y="132" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#223866' : '#F6C36A'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="28" font-weight="700" letter-spacing="3">#{xml_escape(data[:eyebrow])}</text>
        <text x="92" y="284" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#101B39' : '#FFFFFF'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="#{primary.length > 18 ? 68 : 82}" font-weight="800">#{xml_escape(primary)}</text>
        <text x="92" y="380" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#C4572A' : '#F7E8CF'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="#{secondary.length > 22 ? 34 : 42}" font-weight="700">#{xml_escape(secondary)}</text>
        <text x="92" y="454" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#465776' : '#D9E4F5'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="28">#{xml_escape(detail)}</text>
        <rect x="178" y="674" width="886" height="1907" rx="66" fill="#0A1025" filter="url(#shadow)"/>
        <image href="../source-screenshots/#{feature[:source]}.png" x="184" y="680" width="874" height="1895" preserveAspectRatio="xMidYMid meet" clip-path="url(#phone)"/>
        <rect x="92" y="2570" width="1058" height="2" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#223866' : '#F7E8CF'}" opacity="0.22"/>
        <text x="92" y="2638" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#101B39' : '#FFFFFF'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="28" font-weight="600">#{xml_escape(data[:name])}</text>
        <text x="1150" y="2638" text-anchor="end" fill="#{c1 == '#F7E8CF' || c1 == '#FFF8ED' || c1 == '#EFF6FF' ? '#C4572A' : '#F7E8CF'}" font-family="-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif" font-size="26">#{xml_escape(feature[:label][locale])}</text>
      </svg>
    SVG
    File.write(file, svg)
  end
end

FileUtils.mkdir_p(File.join(run_dir, "screenshots"))
