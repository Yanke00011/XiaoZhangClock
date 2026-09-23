import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Countdown.createdAt, order: .reverse) private var countdowns: [Countdown]
    @State private var showingNewCountdown = false
    @State private var newCountdownIsCapsule = false
    @State private var selectedTab: PixelTab = .clock
    @State private var appeared = false
    @State private var timeEngine = TimeEngine.shared
    @AppStorage("pixelAnimationsEnabled") private var pixelAnimations = true
    @AppStorage("uses24HourTime") private var uses24HourTime = true
    private var now: Date { timeEngine.now }
    private var mood: PixelTimeMood { PixelTimeMood.at(now) }
    private var pageAccent: Color {
        switch selectedTab {
        case .clock: mood.accent
        case .timers: PixelTheme.accentPink
        case .stopwatch: PixelTheme.secondary
        case .focus: PixelTheme.success
        case .explore: PixelTheme.accentOrange
        case .settings, .about: PixelTheme.secondary
        }
    }

    var body: some View {
        ZStack {
            PixelWorldBackground(tone: pageAccent, particleCount: selectedTab == .focus ? 7 : mood.particleCount, isAnimated: pixelAnimations)
            RadialGradient(colors: [pageAccent.opacity(0.095), .clear], center: .top, startRadius: 10, endRadius: 430).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        pageContent.id(selectedTab)
                            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    }.padding(.horizontal, 30).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PixelTabBar(selection: $selectedTab).padding(.bottom, 12).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .opacity(appeared ? 1 : 0).offset(y: reduceMotion || appeared ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: appeared)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: selectedTab)
        .environment(\.font, PixelTypography.font(.body))
        .environment(timeEngine)
        .onAppear {
            timeEngine.start()
            appeared = true
            countdowns.forEach { $0.reconcile(at: timeEngine.now) }
            try? modelContext.save()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timeEngine.start()
                timeEngine.refreshForForeground()
            } else {
                timeEngine.stop()
            }
        }
        .onDisappear { timeEngine.stop() }
        .sheet(isPresented: $showingNewCountdown) {
            NewCountdownView(timeEngine: timeEngine, isCapsule: newCountdownIsCapsule)
        }
    }

    @ViewBuilder private var pageContent: some View {
        switch selectedTab {
        case .clock:
            ClockView(uses24HourTime: uses24HourTime).padding(.top, 39).padding(.bottom, 38)
            countdownSection
            Button { presentNewCountdown(capsule: false) } label: {
                HStack(spacing: 9) { PixelIcon(symbol: .plus, size: 12); Text("新建倒计时").pixelFont(.button) }
                    .tracking(1).foregroundStyle(PixelTheme.primary).padding(.vertical, 15).frame(maxWidth: .infinity)
                    .background(PixelTheme.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(PixelTheme.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4])))
            }.buttonStyle(PixelButtonStyle()).padding(.top, 15).padding(.bottom, 24)
        case .timers:
            countdownSection.padding(.top, 34)
            HStack(spacing: 10) {
                actionButton("倒计时", icon: .plus) { presentNewCountdown(capsule: false) }
                actionButton("时间胶囊", icon: .capsule) { presentNewCountdown(capsule: true) }
            }.padding(.top, 17).padding(.bottom, 26)
        case .stopwatch: StopwatchView().padding(.top, 36).padding(.bottom, 30)
        case .focus: FocusView().padding(.top, 36).padding(.bottom, 30)
        case .explore: TimeMachineView().padding(.top, 36).padding(.bottom, 30)
        case .settings: SettingsView(pixelAnimations: $pixelAnimations, uses24HourTime: $uses24HourTime).padding(.top, 34).padding(.bottom, 30)
        case .about: AboutView().padding(.top, 34).padding(.bottom, 30)
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 0) {
            sectionHeader
            if countdowns.isEmpty { emptyState.padding(.top, 24).padding(.bottom, 24) }
            else {
                LazyVStack(spacing: 12) {
                    ForEach(countdowns) { countdown in CountdownCard(countdown: countdown) }
                }.padding(.top, 17)
            }
        }
    }

    private func actionButton(_ title: String, icon: PixelIcon.Symbol, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { PixelIcon(symbol: icon, size: 12); Text(title).pixelFont(.button) }
                .tracking(0.5).foregroundStyle(PixelTheme.primary).padding(.vertical, 13).frame(maxWidth: .infinity)
                .background(PixelTheme.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PixelTheme.border, lineWidth: 1))
        }.buttonStyle(PixelButtonStyle())
    }

    private func presentNewCountdown(capsule: Bool) {
        newCountdownIsCapsule = capsule
        showingNewCountdown = true
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(PixelTheme.primary.opacity(0.13)).frame(width: 28, height: 28)
                    PixelIcon(symbol: .clock, size: 16)
                }
                Text("小张时钟").pixelFont(.title).tracking(2).foregroundStyle(PixelTheme.text)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(PixelTheme.primary).frame(width: 5, height: 5).shadow(color: PixelTheme.primary.opacity(0.7), radius: 5)
                Text(headerTimeStatus)
                    .pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.muted)
            }
        }.padding(.top, 24)
    }

    private var headerTimeStatus: String {
        guard timeEngine.source == .network else { return "本地时间 · 实时" }
        return switch timeEngine.syncState {
        case .synchronized: "实时时间 · 已校准"
        case .syncing: "实时时间 · 正在同步"
        case .idle: "实时时间 · 尚未同步"
        case .unavailable(let message): message.contains("上次校准") ? "实时时间 · 暂时离线" : "实时时间 · 本地回退"
        }
    }

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("倒计时").pixelFont(.headline).tracking(1).foregroundStyle(PixelTheme.text)
                Text("\(countdowns.count.formatted(.number.precision(.integerLength(2)))) 个计时项目").pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.muted)
            }
            Spacer()
            PixelIcon(symbol: .timer, color: PixelTheme.muted, size: 14)
        }
        .padding(.top, 2)
        .overlay(alignment: .top) { Rectangle().fill(PixelTheme.border).frame(height: 1).offset(y: -17) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            PixelIcon(symbol: .sparkle, size: 22).padding(.bottom, 5)
            Text("还没有倒计时").pixelFont(.body).foregroundStyle(PixelTheme.text)
            Text("为重要的时刻留出时间").pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 16)
    }
}
