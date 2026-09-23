import SwiftUI
import CoreText

enum PixelTheme {
    static let background = Color(red: 0.025, green: 0.032, blue: 0.068)
    static let surface = Color(red: 0.054, green: 0.066, blue: 0.12)
    static let elevated = Color(red: 0.087, green: 0.09, blue: 0.17)
    static let primary = Color(red: 0.34, green: 0.86, blue: 1.0)
    static let secondary = Color(red: 0.65, green: 0.51, blue: 1.0)
    static let accentPink = Color(red: 1.0, green: 0.43, blue: 0.72)
    static let accentOrange = Color(red: 1.0, green: 0.65, blue: 0.34)
    static let success = Color(red: 0.48, green: 0.94, blue: 0.69)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.34)
    static let critical = Color(red: 1.0, green: 0.39, blue: 0.51)
    static let text = Color(red: 0.95, green: 0.96, blue: 1.0)
    static let muted = Color(red: 0.60, green: 0.64, blue: 0.75)
    static let border = Color.white.opacity(0.075)
    static let corner: CGFloat = 15
}

typealias PixelColorTheme = PixelTheme

struct PixelTimeMood {
    let title: String
    let accent: Color
    let particleCount: Int
    static func at(_ date: Date) -> PixelTimeMood {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: PixelTimeMood(title: "早晨", accent: PixelTheme.primary, particleCount: 17)
        case 12..<17: PixelTimeMood(title: "午后", accent: PixelTheme.secondary, particleCount: 20)
        case 17..<21: PixelTimeMood(title: "黄昏", accent: PixelTheme.accentOrange, particleCount: 24)
        default: PixelTimeMood(title: "夜晚", accent: Color(red: 0.56, green: 0.69, blue: 1.0), particleCount: 27)
        }
    }
}

enum PixelTimeZoneName {
    static func chineseCity(for timeZone: TimeZone) -> String {
        let cities: [String: String] = [
            "Asia/Shanghai": "上海", "Asia/Tokyo": "东京", "Asia/Hong_Kong": "香港",
            "Asia/Taipei": "台北", "Asia/Singapore": "新加坡", "Asia/Seoul": "首尔",
            "Europe/London": "伦敦", "Europe/Paris": "巴黎", "America/New_York": "纽约",
            "America/Los_Angeles": "洛杉矶", "America/Chicago": "芝加哥", "Australia/Sydney": "悉尼"
        ]
        if let city = cities[timeZone.identifier] { return city }
        return timeZone.localizedName(for: .shortGeneric, locale: Locale(identifier: "zh_CN")) ?? timeZone.identifier
    }
}

enum PixelTypography {
    enum Style { case display, hero, title, headline, body, button, caption, micro, mono, countdown }
    static let postScriptName = "Fusion-Pixel-10px-Mono-zh_hans-Regular"

    static func font(_ style: Style) -> Font {
        let size: CGFloat = switch style {
        case .display: 76
        case .hero: 92
        case .title: 27
        case .headline: 22
        case .body: 17
        case .button: 16
        case .caption: 14
        case .micro: 12
        case .mono: 15
        case .countdown: 48
        }
        return .custom(postScriptName, size: size, relativeTo: .body)
    }
}

extension View {
    func pixelFont(_ style: PixelTypography.Style) -> some View { font(PixelTypography.font(style)) }
}

enum PixelFontRegistrar {
    static func registerBundledFont() {
        guard let url = Bundle.main.url(forResource: "fusion-pixel-10px-monospaced-zh_hans", withExtension: "ttf", subdirectory: "Fonts") else {
            assertionFailure("Bundled Fusion Pixel font is missing from Resources/Fonts")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
           let error = error?.takeRetainedValue() {
            NSLog("Pixel Time font registration failed: %@", error.localizedDescription as NSString)
        }
    }
}

struct PixelWorldBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tone: Color = PixelTheme.primary
    var particleCount = 22
    var isAnimated = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion || !isAnimated)) { timeline in
            Canvas { context, size in
                let step: CGFloat = 36
                var grid = Path()
                stride(from: CGFloat(0), through: size.width, by: step).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat(0), through: size.height, by: step).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.022)), lineWidth: 0.5)

                let time = reduceMotion || !isAnimated ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<particleCount {
                    let seed = Double(index)
                    let baseX = (seed * 0.61803398875).truncatingRemainder(dividingBy: 1)
                    let baseY = (seed * 0.41421356237 + 0.19).truncatingRemainder(dividingBy: 1)
                    let x = (baseX + sin(time * 0.12 + seed) * 0.012).truncatingRemainder(dividingBy: 1)
                    let y = (baseY + cos(time * 0.10 + seed * 1.7) * 0.014).truncatingRemainder(dividingBy: 1)
                    let twinkle = 0.045 + (sin(time * 0.7 + seed * 2.1) + 1) * 0.026
                    let side: CGFloat = index.isMultiple(of: 4) ? 3 : 2
                    let rect = CGRect(x: x * size.width, y: y * size.height, width: side, height: side)
                    let palette: [Color] = [tone, PixelTheme.primary, PixelTheme.secondary, PixelTheme.accentPink]
                    context.fill(Path(rect), with: .color(palette[index % palette.count].opacity(twinkle)))
                }
            }
        }
        .background(PixelTheme.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PixelSurface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .background {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 22).fill(.clear).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
                } else {
                    RoundedRectangle(cornerRadius: 22).fill(PixelTheme.surface.opacity(0.96))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

struct PixelIcon: View {
    enum Symbol { case clock, plus, play, pause, reset, trash, location, timer, stopwatch, sparkle, capsule, dots, settings, about, timeline }
    var symbol: Symbol
    var color: Color = PixelTheme.primary
    var size: CGFloat = 16

    private var rows: [String] {
        switch symbol {
        case .clock: [".#####.", "#.....#", "#..#..#", "#..#..#", "#..###.", "#.....#", ".#####."]
        case .plus: [".......", "...#...", "...#...", ".#####.", "...#...", "...#...", "......."]
        case .play: ["#......", "##.....", "###....", "####...", "###....", "##.....", "#......"]
        case .pause: ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##"]
        case .reset: ["..####.", ".#....#", "#......", "#..##..", "#...#..", ".#..#..", "..####."]
        case .trash: ["..###..", ".#####.", "..#.#..", "..#.#..", "..#.#..", "..#.#..", ".#####."]
        case .location: ["...#...", "..###..", ".##.##.", ".##.##.", "..###..", "...#...", "...#..."]
        case .timer: ["...#...", "..###..", ".#...#.", "#.....#", "#..##.#", "#...#.#", ".#####."]
        case .stopwatch: ["...#...", "..###..", ".#...#.", "#.....#", "#..##.#", "#.#...#", ".#####."]
        case .sparkle: ["...#...", "...#...", "#..#..#", ".#####.", "#..#..#", "...#...", "...#..."]
        case .capsule: ["..###..", ".#...#.", "#.....#", "#..#..#", "#.....#", ".#...#.", "..###.."]
        case .dots: [".......", ".......", "#...#..", ".......", "#...#..", ".......", "#...#.."]
        case .settings: ["..###..", ".#...#.", "##.#.##", "#..#..#", "##.#.##", ".#...#.", "..###.."]
        case .about: ["..###..", ".#...#.", "...#...", "...#...", "...#...", ".......", "...#..."]
        case .timeline: [".......", ".......", "#.#.#.#", "..#.#..", ".#...#.", ".......", "......."]
        }
    }
    var body: some View {
        Canvas { context, _ in
            let unit = size / 7
            for (row, line) in rows.enumerated() {
                for (column, pixel) in line.enumerated() where pixel == "#" {
                    context.fill(Path(CGRect(x: CGFloat(column) * unit, y: CGFloat(row) * unit, width: unit * 0.84, height: unit * 0.84)), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PixelCorners: Shape {
    var size: CGFloat = 9
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = min(size, min(rect.width, rect.height) / 3)
        p.move(to: CGPoint(x: 0, y: s)); p.addLine(to: CGPoint(x: s, y: s)); p.addLine(to: CGPoint(x: s, y: 0))
        p.move(to: CGPoint(x: rect.maxX - s, y: 0)); p.addLine(to: CGPoint(x: rect.maxX - s, y: s)); p.addLine(to: CGPoint(x: rect.maxX, y: s))
        p.move(to: CGPoint(x: 0, y: rect.maxY - s)); p.addLine(to: CGPoint(x: s, y: rect.maxY - s)); p.addLine(to: CGPoint(x: s, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX - s, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY - s)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - s))
        return p
    }
}

struct PixelButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.015 : 1))
            .brightness(configuration.isPressed ? 0.08 : (isHovered ? 0.035 : 0))
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
    }
}
