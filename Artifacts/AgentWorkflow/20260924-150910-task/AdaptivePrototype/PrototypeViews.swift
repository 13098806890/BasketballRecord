import SwiftUI

struct AdaptivePrototypeShell: View {
    @Binding var tab: PrototypeTab
    let data = AdaptiveMockData()

    var body: some View {
        ZStack {
            AdaptivePaperBackground()
            Group {
                switch tab {
                case .management:
                    ManagementPrototypeView(data: data)
                case .score:
                    ProtectedScoreView()
                case .career:
                    CareerPrototypeView(data: data)
                case .settings:
                    SettingsPrototypeView(data: data)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdaptiveBottomBar(selection: $tab)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct ManagementPrototypeView: View {
    let data: AdaptiveMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Roster")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.navy)
                    .minimumScaleFactor(0.7)
                Text("Data Management")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.navySoft)
                AdaptiveCard {
                    VStack(spacing: 0) {
                        ForEach(data.managementItems) { item in
                            ManagementRow(item: item)
                            if item.id != data.managementItems.last?.id {
                                Divider().overlay(AdaptiveTokens.divider).padding(.leading, 112)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 90)
            .padding(.bottom, 24)
        }
    }
}

struct ManagementRow: View {
    let item: PrototypeManagementItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(item.enabled ? AdaptiveTokens.orange : AdaptiveTokens.orange.opacity(0.55))
                .frame(width: 34)
            Text(item.title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(item.enabled ? AdaptiveTokens.navy : AdaptiveTokens.navySoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
            Spacer(minLength: 8)
            if let count = item.count {
                Text("\(count)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.blue)
                    .frame(width: 44, height: 44)
                    .background(AdaptiveTokens.paleBlue)
                    .clipShape(Circle())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveTokens.navySoft.opacity(0.55))
        }
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }
}

struct CareerPrototypeView: View {
    let data: AdaptiveMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Career")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.navy)
                    .minimumScaleFactor(0.7)
                Picker("Career", selection: .constant(1)) {
                    Text("Game History").tag(0)
                    Text("Team").tag(1)
                    Text("Player").tag(2)
                }
                .pickerStyle(.segmented)
                ForEach(data.teams) { team in
                    TeamSummaryCard(team: team)
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 90)
            .padding(.bottom, 24)
        }
    }
}

struct TeamSummaryCard: View {
    let team: PrototypeTeamSummary

    var body: some View {
        AdaptiveCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(team.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AdaptiveTokens.navy)
                    Spacer()
                    Text(team.record)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(AdaptiveTokens.navySoft)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(Array(team.metrics.enumerated()), id: \.offset) { _, metric in
                        VStack(spacing: 8) {
                            Text(metric.0)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AdaptiveTokens.navySoft)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .multilineTextAlignment(.center)
                            Text(metric.1)
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                                .foregroundStyle(AdaptiveTokens.navy)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .background(AdaptiveTokens.paleBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(22)
        }
    }
}

struct SettingsPrototypeView: View {
    let data: AdaptiveMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.navy)
                    .minimumScaleFactor(0.7)
                ForEach(Array(data.settingsSections.enumerated()), id: \.offset) { index, section in
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                            .foregroundStyle(AdaptiveTokens.navySoft)
                    }
                    AdaptiveCard {
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.offset) { rowIndex, item in
                                SettingsRow(title: item, index: index, rowIndex: rowIndex)
                                if rowIndex < section.items.count - 1 {
                                    Divider().overlay(AdaptiveTokens.divider).padding(.leading, 112)
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 90)
            .padding(.bottom, 24)
        }
    }
}

struct SettingsRow: View {
    let title: String
    let index: Int
    let rowIndex: Int

    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: iconName)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(index == 0 ? AdaptiveTokens.orange : AdaptiveTokens.navy)
                .frame(width: 48)
            Text(title)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveTokens.navy)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer()
            if index == 0 && rowIndex < 2 {
                Toggle("", isOn: .constant(rowIndex == 0))
                    .labelsHidden()
                    .tint(AdaptiveTokens.orange)
            } else if index == 1 {
                Text(rowIndex == 0 ? "cm" : "kg")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveTokens.blue)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AdaptiveTokens.navySoft.opacity(0.6))
            }
        }
        .frame(minHeight: 82)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch (index, rowIndex) {
        case (0, 0): return "sun.max"
        case (0, 1): return "antenna.radiowaves.left.and.right"
        case (0, 2): return "waveform"
        case (0, 3): return "icloud"
        case (1, 0): return "ruler"
        case (1, 1): return "scalemass"
        case (2, 0): return "crown.fill"
        default: return "arrow.up.circle"
        }
    }
}

struct ProtectedScoreView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(AdaptiveTokens.navy)
            Text("Score")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(AdaptiveTokens.navy)
            Text("Protected baseline: this page is not part of the visual redesign.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveTokens.navySoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AdaptiveBottomBar: View {
    @Binding var selection: PrototypeTab

    var body: some View {
        HStack(spacing: 0) {
            BottomItem(title: "Roster", icon: "folder.fill", tab: .management, selection: $selection)
            BottomItem(title: "Score", icon: "sportscourt", tab: .score, selection: $selection)
            BottomItem(title: "Career", icon: "trophy.fill", tab: .career, selection: $selection)
            BottomItem(title: "Settings", icon: "gearshape.fill", tab: .settings, selection: $selection)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
        .padding(.horizontal, 48)
        .padding(.bottom, 8)
    }
}

struct BottomItem: View {
    let title: String
    let icon: String
    let tab: PrototypeTab
    @Binding var selection: PrototypeTab

    var body: some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selection == tab ? AdaptiveTokens.blue : AdaptiveTokens.navy)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(selection == tab ? AdaptiveTokens.paleBlue.opacity(0.9) : .clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
