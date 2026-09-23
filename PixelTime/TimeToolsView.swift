import SwiftUI

enum PixelTab: String, CaseIterable, Identifiable {
    case clock, timers, stopwatch, focus, explore, settings, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clock: "时钟"
        case .timers: "倒计时"
        case .stopwatch: "秒表"
        case .focus: "专注"
        case .explore: "时间机器"
        case .settings: "设置"
        case .about: "关于"
        }
    }
    var icon: PixelIcon.Symbol {
        switch self {
        case .clock: .clock
        case .timers: .timer
        case .stopwatch: .stopwatch
        case .focus: .sparkle
        case .explore: .timeline
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
                        PixelIcon(symbol: tab.icon, color: selection == tab ? PixelTheme.primary : PixelTheme.muted, size: 16)
                        Text(tab.title).pixelFont(.micro).tracking(0.1).lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(selection == tab ? PixelTheme.primary : PixelTheme.muted)
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
        .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 0.8))
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
            toolHeading("秒表", subtitle: "记录每一刻")
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
                            Text(String(format: "第 %02d 圈", laps.count - index)).pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                            Spacer()
                            Text(format(lap)).pixelFont(.body).foregroundStyle(PixelTheme.text)
                        }.padding(.vertical, 10)
                        if index < min(laps.count, 8) - 1 { Rectangle().fill(PixelTheme.border).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 14).background(PixelTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PixelTheme.border, lineWidth: 1))
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

private enum FocusPhase: String, CaseIterable, Identifiable {
    case focus = "专注", shortBreak = "短暂休息", longBreak = "长休息"
    var id: String { rawValue }
}

struct FocusView: View {
    @Environment(TimeEngine.self) private var timeEngine
    @State private var phase: FocusPhase = .focus
    @State private var preset = "25 分钟"
    @State private var customMinutes = 40
    @State private var remaining: TimeInterval = 25 * 60
    @State private var isRunning = false
    @State private var startInstant: ContinuousClock.Instant = ContinuousClock().now
    @State private var storedRemaining: TimeInterval = 25 * 60
    @State private var completed = false
    private var duration: TimeInterval {
        switch phase {
        case .focus:
            switch preset {
            case "50 分钟": 50 * 60
            case "90 分钟": 90 * 60
            case "自定义": TimeInterval(customMinutes * 60)
            default: 25 * 60
            }
        case .shortBreak: 5 * 60
        case .longBreak: 15 * 60
        }
    }
    private var liveRemaining: TimeInterval {
        isRunning ? max(0, storedRemaining - elapsed(since: startInstant, until: timeEngine.currentMonotonicNow)) : remaining
    }
    private var clockText: String {
        let n = Int(liveRemaining.rounded(.up))
        return String(format: "%02d:%02d", n / 60, n % 60)
    }

    var body: some View {
        VStack(spacing: 18) {
            toolHeading("专注", subtitle: "留一段时间给自己")
            HStack(spacing: 6) {
                ForEach(FocusPhase.allCases) { item in
                    Button { select(item) } label: {
                        Text(item.rawValue).pixelFont(.caption).tracking(0.2).lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(phase == item ? PixelTheme.background : PixelTheme.muted)
                            .padding(.vertical, 9).frame(maxWidth: .infinity)
                            .background(phase == item ? PixelTheme.primary : PixelTheme.surface, in: Rectangle())
                    }.buttonStyle(PixelButtonStyle())
                }
            }
            if phase == .focus {
                HStack(spacing: 5) {
                    ForEach(["25 分钟", "50 分钟", "90 分钟", "自定义"], id: \.self) { value in
                        Button { preset = value; resetForSelection() } label: {
                            Text(value).pixelFont(.caption).tracking(0.1).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(preset == value ? PixelTheme.background : PixelTheme.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(preset == value ? PixelTheme.primary : PixelTheme.surface, in: Rectangle())
                        }.buttonStyle(PixelButtonStyle())
                    }
                }
                if preset == "自定义" {
                    HStack {
                        Text("自定义时长（分钟）").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                        Spacer()
                        Button { customMinutes = max(1, customMinutes - 5); resetForSelection() } label: { Text("−").pixelFont(.body).foregroundStyle(PixelTheme.primary) }
                        Text("\(customMinutes)").pixelFont(.body).foregroundStyle(PixelTheme.text).frame(minWidth: 38)
                        Button { customMinutes = min(180, customMinutes + 5); resetForSelection() } label: { Text("+").pixelFont(.body).foregroundStyle(PixelTheme.primary) }
                    }
                }
            }
            PixelGlyphClock(value: clockText, color: completed ? PixelTheme.secondary : PixelTheme.success, height: 84).padding(.top, 6)
            PixelProgressRail(fraction: duration > 0 ? liveRemaining / duration : 0).frame(height: 8)
            Text(completed ? "本轮已完成" : "\(phase.rawValue)中").pixelFont(.caption).tracking(0.7).foregroundStyle(completed ? PixelTheme.secondary : PixelTheme.muted)
            HStack(spacing: 10) {
                toolButton(isRunning ? "暂停" : (completed ? "再来一次" : "开始"), icon: isRunning ? .pause : .play, prominent: true) {
                    if isRunning {
                        startInstant = timeEngine.currentMonotonicNow
                        remaining = liveRemaining; storedRemaining = remaining; isRunning = false
                    }
                    else {
                        if completed || remaining <= 0 { remaining = duration; storedRemaining = duration; completed = false }
                        startInstant = timeEngine.currentMonotonicNow; isRunning = true
                    }
                }
                toolButton("重置", icon: .reset, prominent: false) { remaining = duration; storedRemaining = duration; isRunning = false; completed = false }
            }
        }
        .onChange(of: timeEngine.now) { _, _ in
            guard isRunning, liveRemaining <= 0 else { return }
            remaining = 0; storedRemaining = 0; isRunning = false; completed = true
        }
        .onChange(of: customMinutes) { _, _ in resetForSelection() }
    }

    private func select(_ item: FocusPhase) {
        phase = item
        resetForSelection()
    }
    private func resetForSelection() {
        isRunning = false; completed = false; remaining = duration; storedRemaining = duration
    }
}

struct TimeMachineView: View {
    @Environment(TimeEngine.self) private var timeEngine
    @State private var offsetHours: Double = 0
    @AppStorage("uses24HourTime") private var uses24HourTime = true
    private var target: Date { timeEngine.now.addingTimeInterval(offsetHours * 3_600) }
    private var timeText: String {
        TimePresentation.clock(target, uses24HourTime: uses24HourTime, timeZone: .current)
    }
    private var dateText: String {
        TimePresentation.longDate(target, timeZone: .current)
    }
    private var offsetLabel: String {
        if abs(offsetHours) < 0.01 { return "现在" }
        let sign = offsetHours > 0 ? "+" : "−"
        let hours = Int(abs(offsetHours))
        let minutes = Int((abs(offsetHours) - Double(hours)) * 60)
        return minutes == 0 ? "\(sign)\(hours) 小时" : "\(sign)\(hours) 小时 \(minutes) 分"
    }

    var body: some View {
        VStack(spacing: 21) {
            toolHeading("时间机器", subtitle: "探索另一个时刻")
            HStack(spacing: 8) {
                Rectangle().fill(PixelTheme.accentOrange.opacity(0.55)).frame(width: 12, height: 2)
                Text(offsetLabel).pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.accentOrange)
                Rectangle().fill(PixelTheme.accentOrange.opacity(0.55)).frame(width: 12, height: 2)
            }.padding(.top, 13)
            PixelGlyphClock(value: timeText, color: PixelTheme.accentOrange, height: 84)
            Text(dateText).pixelFont(.caption).tracking(0.7).foregroundStyle(PixelTheme.text)
            VStack(spacing: 9) {
                HStack {
                    Text("昨天").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                    Spacer()
                    Text("现在").pixelFont(.caption).foregroundStyle(PixelTheme.primary)
                    Spacer()
                    Text("未来三天").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                }
                PixelTimelineControl(value: $offsetHours)
            }
            Text("本地时间 · \(PixelTimeZoneName.chineseCity(for: .current))").pixelFont(.caption).tracking(0.6).foregroundStyle(PixelTheme.muted)
            Text("这里只是预览，不会修改系统时间。").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
        }
    }
}

private func elapsed(since start: ContinuousClock.Instant, until end: ContinuousClock.Instant) -> TimeInterval {
    let components = start.duration(to: end).components
    return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
}

private struct PixelTimelineControl: View {
    @Binding var value: Double
    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.width / 8))
            let active = Int(Double(count - 1) * (value + 24) / 96)
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(0..<count, id: \.self) { index in
                        Rectangle().fill(index == active ? PixelTheme.primary : Color.white.opacity(index < active ? 0.22 : 0.08))
                            .frame(height: index == active ? 8 : 4).frame(maxHeight: .infinity)
                    }
                }
                Rectangle().fill(PixelTheme.primary).frame(width: 10, height: 14)
                    .shadow(color: PixelTheme.primary.opacity(0.35), radius: 7)
                    .offset(x: CGFloat(value + 24) / 96 * max(0, proxy.size.width - 10))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let location = min(max(0, gesture.location.x), proxy.size.width)
                let raw = -24 + Double(location / max(1, proxy.size.width)) * 96
                value = (raw * 4).rounded() / 4
            })
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("以小时为单位浏览时间")
        .accessibilityValue("\(value, specifier: "%.2f") 小时")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(72, value + 0.25)
            case .decrement: value = max(-24, value - 0.25)
            @unknown default: break
            }
        }
    }
}

private func toolHeading(_ title: String, subtitle: String) -> some View {
    VStack(spacing: 5) {
        Text(title).pixelFont(.headline).tracking(1.2).foregroundStyle(PixelTheme.text)
        Text(subtitle).pixelFont(.caption).tracking(0.6).foregroundStyle(PixelTheme.muted)
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

private struct PixelProgressRail: View {
    var fraction: Double
    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.width / 8))
            let filled = Int(Double(count) * min(1, max(0, fraction)))
            HStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle().fill(index < filled ? PixelTheme.primary : Color.white.opacity(0.07))
                }
            }
        }
    }
}
