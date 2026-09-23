import SwiftUI
import Combine

struct ClockView: View {
    var uses24HourTime = true
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var timeZone: TimeZone { .current }
    private var timeString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.timeZone = timeZone; f.dateFormat = uses24HourTime ? "HH:mm:ss" : "h:mm:ss"
        return f.string(from: now)
    }
    private var clockPeriod: String {
        guard !uses24HourTime else { return "" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN"); formatter.timeZone = timeZone; formatter.dateFormat = "a"
        return formatter.string(from: now)
    }
    private var dateString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.calendar = Calendar(identifier: .gregorian); f.timeZone = timeZone; f.dateFormat = "EEEE · yyyy年M月d日"
        return f.string(from: now)
    }
    private var zoneName: String {
        PixelTimeZoneName.chineseCity(for: timeZone)
    }
    private var mood: PixelTimeMood { PixelTimeMood.at(now) }
    private var period: String { mood.title }
    private var accent: Color { mood.accent }
    private var offset: String {
        let value = timeZone.secondsFromGMT(for: now)
        let sign = value >= 0 ? "+" : "−"
        let absolute = abs(value)
        return String(format: "UTC%@%02d:%02d", sign, absolute / 3600, (absolute % 3600) / 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle().fill(accent.opacity(0.55)).frame(width: 14, height: 2)
                Text("像素时钟").pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.muted)
                Rectangle().fill(accent.opacity(0.55)).frame(width: 14, height: 2)
            }
            PixelGlyphClock(value: timeString, color: accent, height: 92).padding(.top, 20)
            HStack(spacing: 8) {
                if !clockPeriod.isEmpty { Text(clockPeriod).pixelFont(.caption).foregroundStyle(accent) }
                Text(period).pixelFont(.caption).tracking(1.4).foregroundStyle(accent)
                Text("·").foregroundStyle(PixelTheme.muted)
                Text(dateString).pixelFont(.caption).tracking(1).foregroundStyle(PixelTheme.secondary.opacity(0.9))
            }.padding(.top, 9)
            HStack(spacing: 8) {
                PixelIcon(symbol: .location, color: PixelTheme.muted, size: 9)
                Text(zoneName).pixelFont(.caption).lineLimit(1)
                Text("·").foregroundStyle(PixelTheme.muted)
                Text(offset).pixelFont(.caption)
            }.tracking(1).foregroundStyle(PixelTheme.muted).padding(.top, 11)
            PixelScanline().stroke(Color.white.opacity(0.025), lineWidth: 1).frame(height: 9).padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in now = .now }
    }
}

private struct PixelScanline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        stride(from: 0, through: rect.width, by: 8).forEach { x in p.addRect(CGRect(x: x, y: rect.midY, width: 3, height: 1)) }
        return p
    }
}
