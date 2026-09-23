import SwiftUI
import SwiftData

struct CountdownCard: View {
    @Environment(TimeEngine.self) private var timeEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var countdown: Countdown
    private var now: Date { timeEngine.now }
    @State private var celebrate = false
    @State private var collapseProgress = -1.0
    @State private var showingActions = false
    @State private var showingDeleteConfirmation = false
    private var remaining: TimeInterval { countdown.remaining(at: now) }
    private var fraction: Double { countdown.totalDuration > 0 ? min(1, max(0, remaining / countdown.totalDuration)) : 0 }
    private var status: String {
        if countdown.isCompleted { return "已完成" }
        if fraction <= 0.10 { return "即将结束" }
        if fraction <= 0.30 { return "时间不多" }
        return countdown.isRunning ? "进行中" : "已暂停"
    }
    private var statusColor: Color {
        if countdown.isCompleted { return PixelTheme.success }
        if fraction <= 0.10 { return PixelTheme.critical }
        if fraction <= 0.30 { return PixelTheme.warning }
        if countdown.isCapsule { return PixelTheme.accentPink }
        return countdown.isRunning ? PixelTheme.primary : PixelTheme.muted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if countdown.isCapsule { PixelIcon(symbol: .capsule, size: 11) }
                        Text(countdown.title.uppercased()).pixelFont(.headline).tracking(1).foregroundStyle(PixelTheme.text).lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        Rectangle().fill(statusColor).frame(width: 5, height: 5)
                        Text(countdown.isCapsule ? "时间胶囊 · \(status)" : status).pixelFont(.caption).tracking(0.6).foregroundStyle(statusColor)
                    }
                }
                Spacer()
                Button {
                    if reduceMotion { showingActions.toggle() }
                    else { withAnimation(.easeOut(duration: 0.12)) { showingActions.toggle() } }
                } label: {
                    PixelIcon(symbol: .dots, color: PixelTheme.muted, size: 13).frame(width: 28, height: 24).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if countdown.isCompleted && collapseProgress < 0 {
                        Text("时间到").pixelFont(.headline).tracking(1).foregroundStyle(PixelTheme.primary)
                    } else if countdown.style == .matrix {
                        matrixReadout.frame(maxWidth: .infinity)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            PixelGlyphClock(value: timeLabel, collapseProgress: collapseProgress >= 0 ? collapseProgress : nil, height: 44)
                            if showsCalendarDays { Text("天").pixelFont(.caption).foregroundStyle(PixelTheme.muted) }
                        }
                    }
                }
                    .foregroundStyle(countdown.isCompleted ? PixelTheme.primary : PixelTheme.text).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            if countdown.style == .classic {
                PixelProgress(fraction: fraction, active: countdown.isRunning || countdown.isCompleted, color: statusColor).frame(height: 8)
            }
            HStack {
                Text(countdown.isDateBased ? targetSummary : "\(Int(fraction * 100))% \(countdown.isCapsule ? "后开启" : "剩余")")
                    .pixelFont(.caption).tracking(0.4).foregroundStyle(PixelTheme.muted)
                Spacer()
                if countdown.style == .ring {
                    PixelRing(fraction: fraction, color: countdown.isRunning || countdown.isCompleted ? statusColor : PixelTheme.primary.opacity(0.7))
                        .frame(width: 45, height: 45)
                }
                Button {
                    if countdown.isRunning { countdown.pause(at: now) }
                    else if countdown.isCompleted { countdown.reset(at: now) }
                    else { countdown.start(at: now) }
                    persist()
                } label: {
                    HStack(spacing: 7) { PixelIcon(symbol: countdown.isRunning ? .pause : .play, color: PixelTheme.background, size: 11); Text(buttonTitle).pixelFont(.button) }.tracking(0.5)
                        .foregroundStyle(PixelTheme.background).padding(.horizontal, 13).padding(.vertical, 7)
                        .background(PixelTheme.primary, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(PixelButtonStyle())
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .background(LinearGradient(colors: [PixelTheme.elevated, PixelTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: PixelTheme.corner))
        .overlay(RoundedRectangle(cornerRadius: PixelTheme.corner).stroke(PixelTheme.border, lineWidth: 1))
        .overlay(PixelCorners().stroke(PixelTheme.primary.opacity(0.28), lineWidth: 1).padding(1))
        .overlay {
            Group {
                if celebrate { PixelBurst().transition(.opacity) }
            }.allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if showingActions {
                VStack(spacing: 0) {
                    actionMenuButton("重置", icon: .reset) { countdown.reset(at: now); persist(); showingActions = false }
                    Rectangle().fill(PixelTheme.border).frame(height: 1)
                    actionMenuButton("删除", icon: .trash) { showingDeleteConfirmation = true; showingActions = false }
                }
                .padding(5).frame(width: 112)
                .background(PixelTheme.surface, in: Rectangle())
                .overlay(Rectangle().stroke(PixelTheme.primary.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                .offset(y: 37).padding(.trailing, 14).zIndex(2)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .confirmationDialog("确定删除这个倒计时吗？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) { modelContext.delete(countdown); persist() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("删除后无法恢复。")
        }
        .shadow(color: countdown.isRunning ? PixelTheme.primary.opacity(0.045) : .clear, radius: 16, y: 4)
        .scaleEffect(celebrate ? 1.025 : 1)
        .onAppear {
            if countdown.isRunning && countdown.remaining(at: now) <= 0 {
                countdown.reconcile(at: now)
                persist()
            }
        }
        .onChange(of: timeEngine.now) { _, date in
            if countdown.isRunning && countdown.remaining(at: date) <= 0 {
                countdown.reconcile(at: date); persist()
                guard !reduceMotion else { return }
                collapseProgress = 0
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(380))
                    for frame in 1...12 {
                        try? await Task.sleep(for: .milliseconds(32))
                        collapseProgress = Double(frame) / 12
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.52)) { celebrate = true }
                    try? await Task.sleep(for: .milliseconds(550))
                    withAnimation(.spring()) { celebrate = false }
                    collapseProgress = -1
                }
            }
        }
    }

    private var timeLabel: String {
        if countdown.isDateBased {
            if countdown.isAllDay && remaining >= 86_400 {
                let days = calendarDaysRemaining
                return days > 0 ? "\(days)" : "今天"
            }
            if remaining >= 86_400 {
                let days = calendarDaysRemaining
                if days > 0 { return "\(days)" }
                let value = Int(remaining.rounded(.up))
                return String(format: "%02d:%02d:%02d", value / 3_600, (value / 60) % 60, value % 60)
            }
        }
        let value = Int(remaining.rounded(.up))
        let days = value / 86_400, hours = (value % 86_400) / 3_600, minutes = (value % 3_600) / 60, seconds = value % 60
        return days > 0 ? String(format: "%d天 %02d:%02d:%02d", days, hours, minutes, seconds) : String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    private var showsCalendarDays: Bool {
        guard countdown.isDateBased, !countdown.isCompleted else { return false }
        return remaining >= 86_400 && calendarDaysRemaining > 0
    }
    private var calendarDaysRemaining: Int {
        let calendar = Calendar.current
        let target = countdown.targetDate ?? now.addingTimeInterval(remaining)
        let start = countdown.isAllDay ? calendar.startOfDay(for: now) : now
        let end = countdown.isAllDay ? calendar.startOfDay(for: target) : target
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    private var targetSummary: String {
        guard let targetDate = countdown.targetDate else { return "\(Int(remaining.rounded(.up))) 秒后" }
        return TimePresentation.shortDate(targetDate) + (countdown.isAllDay ? " · 全天" : " · " + TimePresentation.time(targetDate))
    }
    private var matrixReadout: some View {
        let value = Int(remaining.rounded(.up))
        let calendarDays = countdown.isDateBased && remaining >= 86_400 ? calendarDaysRemaining : 0
        let dayCount = countdown.isDateBased ? calendarDays : value / 86_400
        let usesDays = dayCount > 0
        let first = usesDays ? dayCount : (countdown.isDateBased ? value / 3_600 : (value % 86_400) / 3_600)
        let calendarRemainder: DateComponents? = {
            guard calendarDays > 0 else { return nil }
            let calendar = Calendar.current
            let target = countdown.targetDate ?? now.addingTimeInterval(remaining)
            let base = countdown.isAllDay ? calendar.startOfDay(for: now) : now
            guard let afterWholeDays = calendar.date(byAdding: .day, value: calendarDays, to: base) else { return nil }
            return calendar.dateComponents([.hour, .minute], from: afterWholeDays, to: target)
        }()
        let second = calendarRemainder?.hour ?? (usesDays ? (value % 86_400) / 3_600 : (value % 3_600) / 60)
        let third = calendarRemainder?.minute ?? (usesDays ? (value % 3_600) / 60 : value % 60)
        return HStack(alignment: .center, spacing: 22) {
            matrixColumn(first, unit: usesDays ? "天" : "时")
            matrixColumn(second, unit: usesDays ? "时" : "分")
            matrixColumn(third, unit: usesDays ? "分" : "秒")
        }
    }
    private func matrixColumn(_ value: Int, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value)).pixelFont(.countdown).foregroundStyle(PixelTheme.text)
            Text(unit).pixelFont(.caption).foregroundStyle(PixelTheme.muted)
        }.padding(.horizontal, 6).padding(.vertical, 4).background(PixelTheme.primary.opacity(0.07), in: Rectangle())
    }
    private var buttonTitle: String { countdown.isRunning ? "暂停" : (countdown.isCompleted ? "重新开始" : "开始") }
    private func persist() { try? modelContext.save() }
    private func actionMenuButton(_ title: String, icon: PixelIcon.Symbol, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                PixelIcon(symbol: icon, color: title == "删除" ? PixelTheme.critical : PixelTheme.primary, size: 11)
                Text(title).pixelFont(.caption).tracking(0.5).foregroundStyle(title == "删除" ? PixelTheme.critical : PixelTheme.text)
                Spacer(minLength: 0)
            }.padding(.horizontal, 7).padding(.vertical, 9).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct PixelBurst: View {
    private let particles: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.36, -0.28, 4), (-0.22, -0.43, 3), (-0.05, -0.34, 5), (0.14, -0.45, 3), (0.34, -0.29, 4),
        (0.43, -0.08, 3), (0.31, 0.15, 5), (0.18, 0.35, 3), (-0.06, 0.43, 4), (-0.26, 0.30, 3),
        (-0.42, 0.12, 5), (-0.48, -0.08, 3), (0.05, -0.12, 3), (-0.15, 0.05, 4), (0.25, 0.02, 3), (0.02, 0.28, 3)
    ]
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for (x, y, side) in particles {
                    let rect = CGRect(x: size.width * (0.5 + x) - side / 2,
                                      y: size.height * (0.5 + y) - side / 2,
                                      width: side, height: side)
                    context.fill(Path(rect), with: .color(PixelTheme.primary.opacity(0.72)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .shadow(color: PixelTheme.primary.opacity(0.35), radius: 9)
        }
        .allowsHitTesting(false)
    }
}

private struct PixelProgress: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fraction: Double
    var active: Bool
    var color: Color
    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.width / 8))
            let filled = Int((Double(count) * fraction).rounded(.down))
            HStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle().fill(index < filled ? color : Color.white.opacity(0.07))
                        .shadow(color: index < filled && active ? color.opacity(0.45) : .clear, radius: 4)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: filled)
                }
            }
        }
    }
}

private struct PixelRing: View {
    var fraction: Double
    var color: Color
    private let count = 24
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.39
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                let lit = Double(index) / Double(count) < fraction
                context.fill(Path(rect), with: .color(lit ? color : Color.white.opacity(0.08)))
            }
        }
        .shadow(color: color.opacity(0.16), radius: 8)
        .accessibilityLabel("剩余 \(Int(fraction * 100))%")
    }
}
