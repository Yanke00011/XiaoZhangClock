import SwiftUI

enum PixelTab: String, CaseIterable, Identifiable {
    case clock, timers, stopwatch, settings, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clock: "时钟"
        case .timers: "倒计时"
        case .stopwatch: "秒表"
        case .settings: "设置"
        case .about: "关于"
        }
    }
    var icon: PixelIcon.Symbol {
        switch self {
        case .clock: .clock
        case .timers: .timer
        case .stopwatch: .stopwatch
        case .settings: .settings
        case .about: .about
        }
    }
}

struct PixelTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: PixelTab
    var body: some View {
        HStack(spacing: 3) {
            ForEach(PixelTab.allCases) { tab in
                Button {
                    if reduceMotion { selection = tab }
                    else { withAnimation(.easeOut(duration: 0.18)) { selection = tab } }
                } label: {
                    VStack(spacing: 5) {
                        PixelIcon(symbol: tab.icon, color: selection == tab ? PixelTheme.primary : PixelTheme.textMuted, size: 16)
                        Text(tab.title).pixelFont(.micro).tracking(0.1).lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(selection == tab ? PixelTheme.primary : PixelTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 3).padding(.top, 11).padding(.bottom, 10)
                    .contentShape(Rectangle())
                    .background {
                        if selection == tab {
                            Capsule().glassEffect(.regular.tint(PixelTheme.primary.opacity(0.20)).interactive(), in: Capsule())
                                .matchedGeometryEffect(id: "pixel-tab-selection", in: selectionAnimation)
                        }
                    }
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .padding(1)
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background {
            Capsule().glassEffect(.regular.tint(Color.white.opacity(0.045)).interactive(), in: Capsule())
        }
        .overlay(Capsule().stroke(PixelTheme.borderStrong, lineWidth: 0.8))
        .shadow(color: PixelTheme.secondary.opacity(0.08), radius: 14, y: 4)
    }
    @Namespace private var selectionAnimation
}

struct StopwatchView: View {
    @Environment(TimeEngine.self) private var timeEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var isRunning: Bool { timeEngine.stopwatchIsRunning }
    private var laps: [TimeInterval] { timeEngine.stopwatchLaps }
    private var elapsed: TimeInterval { timeEngine.stopwatchElapsed }
    private var readout: String {
        let hundredths = Int((elapsed * 100).rounded(.down))
        return String(format: "%02d:%02d.%02d", hundredths / 6000, (hundredths / 100) % 60, hundredths % 100)
    }

    var body: some View {
        VStack(spacing: 19) {
            PixelPageHeader(title: "秒表", subtitle: "记录每一刻")
            PixelGlyphClock(value: readout, color: PixelTheme.secondary, height: 78).frame(height: 82).padding(.top, 8)
            HStack(spacing: 10) {
                toolButton(isRunning ? "暂停" : "开始", icon: isRunning ? .pause : .play, prominent: true) {
                    if isRunning { timeEngine.pauseStopwatch() }
                    else { timeEngine.startStopwatch() }
                }
                toolButton("计次", icon: .timer, prominent: false) {
                    guard isRunning else { return }
                    timeEngine.recordStopwatchLap()
                }.disabled(!isRunning)
                toolButton("重置", icon: .reset, prominent: false) {
                    timeEngine.resetStopwatch()
                }
            }
            if !laps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(laps.prefix(8).enumerated()), id: \.offset) { index, lap in
                        HStack {
                            Text(String(format: "第 %02d 圈", laps.count - index)).pixelFont(.caption).foregroundStyle(PixelTheme.textMuted)
                            Spacer()
                            Text(format(lap)).pixelFont(.body).foregroundStyle(PixelTheme.text)
                        }.padding(.vertical, 10)
                        if index < min(laps.count, 8) - 1 { Rectangle().fill(PixelTheme.border).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 14).background(PixelTheme.surface, in: RoundedRectangle(cornerRadius: PixelRadius.control))
                .overlay(RoundedRectangle(cornerRadius: PixelRadius.control).stroke(PixelTheme.border, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { timeEngine.setHundredthUpdates(isRunning) }
        .onDisappear { timeEngine.setHundredthUpdates(false) }
    }

    private func format(_ value: TimeInterval) -> String {
        let n = Int((value * 100).rounded(.down))
        return String(format: "%02d:%02d.%02d", n / 6000, (n / 100) % 60, n % 100)
    }
}

private func toolButton(_ title: String, icon: PixelIcon.Symbol, prominent: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            PixelIcon(symbol: icon, color: prominent ? PixelTheme.background : PixelTheme.primary, size: 11)
            Text(title).pixelFont(.button)
        }
        .tracking(0.5).foregroundStyle(prominent ? PixelTheme.background : PixelTheme.primary)
        .padding(.vertical, 12).frame(maxWidth: .infinity)
        .background(prominent ? PixelTheme.primary : PixelTheme.surface, in: Rectangle())
        .overlay(Rectangle().stroke(prominent ? PixelTheme.primary : PixelTheme.border, lineWidth: 1))
    }
    .buttonStyle(PixelButtonStyle())
}
