import SwiftUI

struct PixelPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = min(7, min(rect.width, rect.height) / 5)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

enum PixelDesign {
    static let ink = Color(red: 0.9569, green: 0.9686, blue: 0.9843)
    static let muted = Color(red: 0.5529, green: 0.6078, blue: 0.6784)
    static let background = Color(red: 0.0275, green: 0.0627, blue: 0.1059)
    static let panel = Color(red: 0.0510, green: 0.1020, blue: 0.1647)
    static let panelStrong = Color(red: 0.0667, green: 0.1216, blue: 0.1922)
    static let line = Color(red: 0.5373, green: 0.6941, blue: 0.8196, opacity: 0.22)
    static let cyan = Color(red: 0.3608, green: 0.8824, blue: 0.9020)
    static let amber = Color(red: 1.0, green: 0.7843, blue: 0.3412)
    static let lime = Color(red: 0.6549, green: 0.8902, blue: 0.3647)
}

struct PixelDepthButtonStyle: ButtonStyle {
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .shadow(
                color: accent.opacity(configuration.isPressed ? 0.08 : 0.24),
                radius: 0,
                x: configuration.isPressed ? 0 : 3,
                y: configuration.isPressed ? 0 : 3
            )
    }
}

struct PlayerProfileNavigationBarSkin: ViewModifier {
    let isPixelSkin: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPixelSkin {
            content.toolbar(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

struct PixelArenaBackground: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .color(PixelDesign.background))

            let gridStep: CGFloat = 16
            var x: CGFloat = 0
            while x <= size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(PixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                x += gridStep
            }

            var y: CGFloat = 0
            while y <= size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(PixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                y += gridStep
            }
        }
        .ignoresSafeArea()
    }
}

enum PixelStatIconKind {
    case points
    case minutes
    case games
    case fieldGoal
    case freeThrow
    case twoPoint
    case threePoint
    case rebounds
    case playmaking
    case discipline
    case pointsPerShot
    case efficiency

    var color: Color { PixelDesign.cyan }

    var symbol: String {
        switch self {
        case .points: return "PTS"
        case .minutes: return "MIN"
        case .games: return "G"
        case .fieldGoal: return "FG"
        case .freeThrow: return "FT"
        case .twoPoint: return "2P"
        case .threePoint: return "3P"
        case .rebounds: return "REB"
        case .playmaking: return "AST"
        case .discipline: return "!"
        case .pointsPerShot: return "PPS"
        case .efficiency: return "%"
        }
    }
}

struct PixelStatIcon: View {
    var kind: PixelStatIconKind

    var body: some View {
        Text(kind.symbol)
            .font(.system(size: kind.symbol.count >= 3 ? 7 : 8, weight: .black, design: .monospaced))
            .foregroundStyle(kind.color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

extension PlayerProfileView {
    func careerPixelContent(availableHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let scale = min(max(availableWidth / 390, 0.92), 1.24)
        let headerBudget: CGFloat = 112 * scale
        let badgeBudget: CGFloat = player.map { showBadges && !$0.badges.isEmpty ? 106 : 0 } ?? 0
        let statsMinHeight = min(760, max(0, availableHeight - headerBudget - badgeBudget))

        return VStack(spacing: 0) {
            if let player {
                careerPixelHeader(player, scale: scale)
            }

            pixelCombinedStats(scale: scale, minHeight: statsMinHeight)

            if let player, showBadges, !player.badges.isEmpty {
                pixelBadgeSection(player)
                    .padding(.top, 10)
            }
        }
        .padding(.bottom, 4)
    }

    var pixelGameSelectionToolbarItem: some View {
        NavigationLink {
            PlayerGameSelectionView(games: allPlayerGames, selectedIDs: $selectedGameIDs)
        } label: {
            HStack(spacing: 4) {
                Text(selectionSummaryText)
                    .font(.system(.caption2, design: .monospaced).weight(.black))
                    .lineLimit(1)
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(PixelDesign.cyan.opacity(0.75), lineWidth: 1)
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(PixelDesign.cyan)
                }
                .frame(width: 32, height: 32)
            }
            .foregroundStyle(PixelDesign.cyan)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey("button_choose_games"))
    }

    private func careerPixelHeader(_ player: Player, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                pixelPlayerAvatar(player)
                    .frame(width: 72, height: 72)
                    .overlay(PixelPanelShape().stroke(PixelDesign.cyan, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("label_player"))
                        .font(.system(size: max(9, 10 * scale), weight: .bold, design: .monospaced))
                        .foregroundStyle(PixelDesign.cyan)
                        .tracking(1.2)
                    Text(player.name)
                        .font(.system(size: min(27, max(21, 23 * scale)), weight: .black, design: .monospaced))
                        .foregroundStyle(PixelDesign.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 8) {
                        if !player.position.isEmpty {
                            Text(player.position)
                                .font(.system(size: min(14, max(11, 12 * scale)), weight: .black, design: .monospaced))
                                .foregroundStyle(PixelDesign.amber)
                        }
                        Text(profileSubtitle(player))
                            .font(.system(size: min(14, max(11, 12.5 * scale)), weight: .bold, design: .monospaced))
                            .foregroundStyle(PixelDesign.ink.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                }

                Spacer(minLength: 4)

                Button {
                    showingELOHistory = true
                } label: {
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey("pixel_elo_label"))
                            .font(.system(size: max(9, 10 * scale), weight: .bold, design: .monospaced))
                            .foregroundStyle(PixelDesign.muted)
                        Text(String(Int(playerELO)))
                            .font(.system(size: min(25, max(21, 22 * scale)), weight: .black, design: .monospaced))
                            .foregroundStyle(PixelDesign.amber)
                    }
                    .frame(width: 68, height: 60)
                    .background(PixelPanelShape().fill(PixelDesign.panelStrong))
                    .overlay(PixelPanelShape().stroke(PixelDesign.amber.opacity(0.65), lineWidth: 1))
                }
                .buttonStyle(PixelDepthButtonStyle(accent: PixelDesign.amber))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func pixelPlayerAvatar(_ player: Player) -> some View {
        ZStack {
            PixelPanelShape()
                .fill(PixelDesign.cyan)
            if let data = player.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(PixelPanelShape())
            } else {
                Image("pixel_default_avatar")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(PixelPanelShape())
            }
        }
        .overlay(PixelPanelShape().stroke(PixelDesign.background, lineWidth: 2))
    }

    private func pixelSummaryMetrics(scale: CGFloat) -> some View {
        let totalGames = filteredGames.count
        let winRate = totalGames > 0 ? String(format: "%.1f%%", Double(statsGroup.winCount) / Double(totalGames) * 100) : "--"
        let metrics: [(String, String, Color)] = [
            (localized("stats_games"), "\(totalGames)", PixelDesign.ink),
            (localized("stat_label_starter"), "\(starterGameCount)", PixelDesign.ink),
            (localized("stat_label_bench"), "\(benchGameCount)", PixelDesign.ink),
            (localized("stats_win_rate"), winRate, PixelDesign.lime),
            (localized("pixel_efficiency_pps"), String(format: "%.2f", totalStats.pointsPerShot), PixelDesign.amber),
            (localized("pixel_efficiency_efg"), percent(totalStats.effectiveFieldGoalRate), PixelDesign.cyan),
            (localized("pixel_efficiency_ts"), percent(totalStats.trueShootingRate), PixelDesign.cyan)
        ]

        return HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                VStack(spacing: 1) {
                    Text(metric.0)
                        .font(.system(size: max(8, 8.5 * scale), weight: .bold, design: .monospaced))
                        .foregroundStyle(PixelDesign.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    Text(metric.1)
                        .font(.system(size: max(10, 10.5 * scale), weight: .black, design: .monospaced))
                        .foregroundStyle(metric.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
                .frame(maxWidth: .infinity, minHeight: 35)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(PixelDesign.line)
                        .frame(width: 1, height: 28)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(PixelDesign.panelStrong.opacity(0.82))
        .overlay(PixelPanelShape().stroke(PixelDesign.line, lineWidth: 1))
    }

    private func pixelBadgeSection(_ player: Player) -> some View {
        let grouped = Dictionary(grouping: player.badges, by: { $0.type })
            .mapValues(\.count)
            .sorted { $0.key.title < $1.key.title }

        return pixelCustomSection(localized("label_badges"), sectionId: "badges", accent: PixelDesign.cyan) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(grouped, id: \.key) { type, count in
                        VStack(spacing: 5) {
                            Image(type.assetName)
                                .resizable()
                                .interpolation(.none)
                                .frame(width: 48, height: 48)
                            Text(count > 1 ? "\(type.title) ×\(count)" : type.title)
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(PixelDesign.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(width: 88)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
    }

    private func pixelCombinedStats(scale: CGFloat, minHeight: CGFloat) -> some View {
        let careerCells = pixelCareerCells()
        let averageCells = pixelAverageCells()
        let rowHeight = min(58, max(32, (minHeight - 150) / 9))
        let columnWidth = min(92, max(78, 78 * scale))

        return VStack(spacing: 0) {
            pixelSummaryMetrics(scale: scale)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(PixelDesign.cyan)
                    .frame(width: 5, height: max(16, 17 * scale))
                Text(LocalizedStringKey("pixel_stat_log"))
                    .font(.system(size: min(21, max(17, 18 * scale)), weight: .black, design: .monospaced))
                    .foregroundStyle(PixelDesign.cyan)
                    .tracking(1.2)
                Spacer()
                Text(LocalizedStringKey("pixel_stat_career"))
                    .frame(width: columnWidth, alignment: .leading)
                Text(LocalizedStringKey("pixel_stat_average"))
                    .frame(width: columnWidth, alignment: .leading)
            }
            .font(.system(.caption2, design: .monospaced).weight(.black))
            .foregroundStyle(PixelDesign.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PixelDesign.line)
                    .frame(height: 1)
            }

            if careerCells.isEmpty || averageCells.isEmpty {
                Text(LocalizedStringKey("text_no_stats_in_group"))
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(PixelDesign.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                pixelStatGroup(title: LocalizedStringKey("pixel_group_scoring"), careerCells: [careerCells[0], careerCells[1]], averageCells: [averageCells[0], averageCells[1]], icons: [.points, .minutes], rowHeight: rowHeight, columnWidth: columnWidth, scale: scale)
                pixelStatGroup(title: LocalizedStringKey("pixel_group_shooting"), careerCells: [careerCells[3], careerCells[4], careerCells[5], careerCells[6]], averageCells: [averageCells[3], averageCells[4], averageCells[5], averageCells[6]], icons: [.fieldGoal, .freeThrow, .twoPoint, .threePoint], rowHeight: rowHeight, columnWidth: columnWidth, scale: scale)
                pixelStatGroup(title: LocalizedStringKey("pixel_group_all_around"), careerCells: [careerCells[7], careerCells[8], careerCells[9]], averageCells: [averageCells[7], averageCells[8], averageCells[9]], icons: [.rebounds, .playmaking, .discipline], rowHeight: rowHeight, columnWidth: columnWidth, scale: scale)
            }
        }
        .background(PixelPanelShape().fill(PixelDesign.panel))
        .overlay(PixelPanelShape().stroke(PixelDesign.line, lineWidth: 1))
        .padding(.horizontal, 12)
        .frame(minHeight: minHeight, alignment: .top)
    }

    private func pixelStatGroup(title: LocalizedStringKey, careerCells: [StatCell], averageCells: [StatCell], icons: [PixelStatIconKind], rowHeight: CGFloat, columnWidth: CGFloat, scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(PixelDesign.amber)
                    .frame(width: 5, height: 12)
                Text(title)
                    .font(.system(.caption2, design: .monospaced).weight(.black))
                    .foregroundStyle(PixelDesign.amber)
                    .tracking(1.1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 3)
            .background(PixelDesign.panelStrong.opacity(0.45))

            ForEach(0..<min(careerCells.count, min(averageCells.count, icons.count)), id: \.self) { index in
                pixelCombinedRow(career: careerCells[index], average: averageCells[index], icon: icons[index], rowHeight: rowHeight, columnWidth: columnWidth, scale: scale)
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PixelDesign.line)
                .frame(height: 1)
        }
    }

    private func pixelCustomSection<Content: View>(_ title: String, sectionId: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            pixelSectionHeader(title, sectionId: sectionId, accent: accent)
            if expandedStatSections.contains(sectionId) {
                content()
            }
        }
        .padding(.horizontal, 12)
    }

    private func pixelSectionHeader(_ title: String, sectionId: String, accent: Color) -> some View {
        Button { togglePixelSection(sectionId) } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 6, height: 22)
                Text(title)
                    .font(.system(.headline, design: .monospaced).weight(.black))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: expandedStatSections.contains(sectionId) ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pixelCombinedRow(career: StatCell, average: StatCell, icon: PixelStatIconKind, rowHeight: CGFloat, columnWidth: CGFloat, scale: CGFloat) -> some View {
        HStack(spacing: 6) {
            PixelStatIcon(kind: icon)
                .frame(width: 18, height: 18)
                .padding(2)
                .overlay(Rectangle().stroke(icon.color.opacity(0.7), lineWidth: 1))

            let labelParts = pixelLabelParts(career)
            HStack(spacing: 5) {
                Text(labelParts.label)
                    .font(.system(size: min(14, max(11, 11.5 * scale)), weight: .bold, design: .monospaced))
                    .foregroundStyle(PixelDesign.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                if let rate = labelParts.rate {
                    Text(rate)
                        .font(.system(size: min(13, max(10.5, 10.5 * scale)), weight: .black, design: .monospaced))
                        .foregroundStyle(PixelDesign.lime)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(PixelDesign.lime.opacity(0.13))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(pixelCompactValue(career.value))
                .font(.system(size: min(16, max(12, 13 * scale)), weight: .black, design: .monospaced))
                .foregroundStyle(PixelDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(width: columnWidth, alignment: .leading)

            Text(pixelCompactValue(average.value))
                .font(.system(size: min(16, max(12, 13 * scale)), weight: .black, design: .monospaced))
                .foregroundStyle(PixelDesign.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(width: columnWidth, alignment: .leading)
        }
        .frame(minHeight: rowHeight)
        .padding(.horizontal, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PixelDesign.line.opacity(0.6))
                .frame(height: 1)
        }
    }

    private func pixelCompactValue(_ value: String) -> String {
        let firstLine = value.components(separatedBy: "\n").first ?? value
        return firstLine.replacingOccurrences(of: " / ", with: "/")
    }

    private func pixelLabelParts(_ cell: StatCell) -> (label: String, rate: String?) {
        let parts = cell.value.components(separatedBy: "\n")
        let compactLabel = cell.label.replacingOccurrences(of: " / ", with: "/")
        guard parts.count > 1, !parts[1].isEmpty else { return (compactLabel, nil) }
        return (compactLabel, parts[1])
    }

    private func pixelCareerCells() -> [StatCell] {
        let rows = buildCareerStatRows()
        guard rows.count >= 4, let minutes = rows[0].leftSplit, let careerGames = rows[0].rightSplit, let freeThrow = rows[1].leftSplit, let twoPoint = rows[1].rightSplit, let threePoint = rows[1].right, let assists = rows[2].right, let pointsPerShot = rows[3].rightSplit, let efficiency = rows[3].right else { return [] }
        return [rows[0].left, StatCell(label: minutes.label, value: pixelDurationText(totalMinutes * 60)), careerGames, rows[1].left, freeThrow, twoPoint, threePoint, rows[2].left, assists, rows[3].left, pointsPerShot, efficiency]
    }

    private func pixelAverageCells() -> [StatCell] {
        let rows = buildAverageStatRows()
        guard rows.count >= 4, let minutes = rows[0].leftSplit, let averageGames = rows[0].rightSplit, let freeThrow = rows[1].leftSplit, let twoPoint = rows[1].rightSplit, let threePoint = rows[1].right, let assists = rows[2].right, let pointsPerShot = rows[3].right, let efficiency = rows[3].rightSplit else { return [] }
        return [rows[0].left, StatCell(label: minutes.label, value: pixelDurationText(totalMinutes / Double(max(1, filteredGames.count)) * 60)), averageGames, rows[1].left, freeThrow, twoPoint, threePoint, rows[2].left, assists, rows[3].left, pointsPerShot, efficiency]
    }

    private func pixelDurationText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: NSLocalizedString("pixel_duration_format", comment: "Pixel profile duration"), total / 60, total % 60)
    }

    private func togglePixelSection(_ sectionId: String) {
        if expandedStatSections.contains(sectionId) {
            expandedStatSections.remove(sectionId)
        } else {
            expandedStatSections.insert(sectionId)
        }
    }
}
