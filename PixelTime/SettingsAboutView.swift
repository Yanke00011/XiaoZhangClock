import SwiftUI

struct SettingsView: View {
    @Environment(TimeEngine.self) private var timeEngine
    @Binding var pixelAnimations: Bool
    @Binding var uses24HourTime: Bool

    var body: some View {
        @Bindable var bindableTimeEngine = timeEngine
        VStack(alignment: .leading, spacing: 22) {
            pageTitle("设置", subtitle: "调整你的像素时间")
            VStack(alignment: .leading, spacing: 18) {
                    sectionTitle("时间")
                    settingRow("时间来源", detail: timeEngine.source.title) {
                        Picker("时间来源", selection: $bindableTimeEngine.source) {
                            ForEach(TimeSource.allCases) { source in Text(source.title).tag(source) }
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 190).environment(\.font, PixelTypography.font(.caption))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(timeStateColor).frame(width: 6, height: 6)
                            Text(timeEngine.syncState.title).pixelFont(.caption).foregroundStyle(timeStateColor)
                            Spacer()
                            if timeEngine.source == .network {
                                Text(String(format: "%+.2f 秒", timeEngine.networkOffset)).pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                            }
                        }
                        if let lastSync = timeEngine.lastSynchronizedAt {
                            Text("上次校准：\(TimePresentation.time(lastSync)) · Google 公共 NTP")
                                .pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                        } else {
                            Text("网络校准不会修改 macOS 系统时钟。")
                                .pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                        }
                        Button {
                            Task { await timeEngine.synchronize() }
                        } label: {
                            HStack(spacing: 7) {
                                PixelIcon(symbol: .reset, color: PixelTheme.primary, size: 11)
                                Text("立即同步").pixelFont(.caption).foregroundStyle(PixelTheme.primary)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).disabled(timeEngine.syncState == .syncing)
                    }
                    Divider().overlay(PixelTheme.border)
                    settingRow("时间格式", detail: uses24HourTime ? "24 小时制" : "12 小时制") {
                        Picker("时间格式", selection: $uses24HourTime) {
                            Text("24 小时制").tag(true)
                            Text("12 小时制").tag(false)
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 170).environment(\.font, PixelTypography.font(.caption))
                    }
                    Divider().overlay(PixelTheme.border)
                    sectionTitle("动画")
                    settingRow("像素动态背景", detail: pixelAnimations ? "已开启" : "已关闭") {
                        Toggle("像素动态背景", isOn: $pixelAnimations).labelsHidden().toggleStyle(.switch).tint(PixelTheme.primary)
                    }
                    HStack(spacing: 8) {
                        PixelIcon(symbol: .sparkle, color: PixelTheme.secondary, size: 13)
                    Text("系统辅助功能中的“减少动态效果”始终优先生效。")
                            .pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                    }
            }
            Rectangle().fill(PixelTheme.border).frame(height: 1).padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("外观")
                    HStack(spacing: 9) {
                        colorSwatch("深夜蓝", color: PixelTheme.background, selected: true)
                        colorSwatch("电光青", color: PixelTheme.primary, selected: false)
                        colorSwatch("像素紫", color: PixelTheme.secondary, selected: false)
                    }
            }
        }
    }

    private func settingRow<Control: View>(_ title: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).pixelFont(.body).foregroundStyle(PixelTheme.text)
                Text(detail).pixelFont(.caption).foregroundStyle(PixelTheme.muted)
            }
            Spacer(minLength: 8)
            control()
        }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value).pixelFont(.headline).foregroundStyle(PixelTheme.secondary)
    }

    private var timeStateColor: Color {
        switch timeEngine.syncState {
        case .synchronized: PixelTheme.success
        case .syncing: PixelTheme.warning
        case .idle, .unavailable: PixelTheme.muted
        }
    }

    private func colorSwatch(_ title: String, color: Color, selected: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 16, height: 16)
            Text(title).pixelFont(.caption).foregroundStyle(selected ? PixelTheme.text : PixelTheme.muted)
            if selected { PixelIcon(symbol: .play, color: PixelTheme.primary, size: 9) }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(PixelTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AboutView: View {
    private var version: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "未设置" }
    private var build: String { (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "未设置" }

    var body: some View {
        VStack(spacing: 22) {
            pageTitle("关于小张时钟", subtitle: "属于你的像素时间世界")
            PixelSurface {
                VStack(spacing: 17) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18).fill(PixelTheme.secondary.opacity(0.16)).frame(width: 76, height: 76)
                        PixelIcon(symbol: .clock, color: PixelTheme.primary, size: 44)
                    }
                    Text("小张时钟").pixelFont(.title).foregroundStyle(PixelTheme.text)
                    Text("在每一个重要时刻，\n遇见一点像素的光。")
                        .pixelFont(.body).multilineTextAlignment(.center).lineSpacing(8).foregroundStyle(PixelTheme.muted)
                    Rectangle().fill(PixelTheme.border).frame(height: 1)
                    HStack {
                        Text("版本").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                        Spacer()
                        Text(version).pixelFont(.body).foregroundStyle(PixelTheme.text)
                    }
                    HStack {
                        Text("构建").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                        Spacer()
                        Text(build).pixelFont(.body).foregroundStyle(PixelTheme.text)
                    }
            Text("以原生技术精心打造").pixelFont(.caption).foregroundStyle(PixelTheme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private func pageTitle(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
        Text(title).pixelFont(.title).foregroundStyle(PixelTheme.text)
        Text(subtitle).pixelFont(.body).foregroundStyle(PixelTheme.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
