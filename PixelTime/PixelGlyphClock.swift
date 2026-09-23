import SwiftUI

struct PixelGlyphClock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    var color: Color = PixelTheme.primary
    var collapseProgress: Double? = nil
    @State private var previousValue = ""
    @State private var progress: Double = 1
    @State private var transitionTask: Task<Void, Never>?
    private let transitionDuration = 0.38
    private let frameRate = 30.0

    private static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "#....", "####.", "....#", "....#", "####."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        ":": [".....", ".....", "..#..", ".....", ".....", "..#..", "....."],
        ".": [".....", ".....", ".....", ".....", ".....", "..#..", "..#.."],
        "d": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        " ": Array(repeating: ".....", count: 7)
    ]

    var body: some View {
        Canvas { context, size in
            let columns = max(1, value.count * 6 - 1)
            let cell = min(size.height / 7, size.width / CGFloat(columns))
            let width = CGFloat(columns) * cell
            let left = (size.width - width) / 2
            let top = (size.height - 7 * cell) / 2
            let progress = reduceMotion ? 1 : self.progress
            let oldCharacters = Array(previousValue)
            let characters = Array(value)

            for row in 0..<7 {
                for characterIndex in characters.indices {
                    let newPattern = Self.glyphs[characters[characterIndex]] ?? Array(repeating: ".....", count: 7)
                    let oldPattern: [String] = characterIndex < oldCharacters.count
                        ? (Self.glyphs[oldCharacters[characterIndex]] ?? Array(repeating: ".....", count: 7))
                        : Array(repeating: ".....", count: 7)
                    for column in 0..<5 {
                        let oldFilled = Array(oldPattern[row])[column] == "#"
                        let newFilled = Array(newPattern[row])[column] == "#"
                        guard oldFilled || newFilled else { continue }
                        let flatIndex = characterIndex * 35 + row * 5 + column
                        let delay = Double((flatIndex * 37 + 11) % 17) / 100
                        let local = min(1, max(0, (progress - delay) / 0.22))
                        let x = left + CGFloat(characterIndex * 6 + column) * cell
                        let y = top + CGFloat(row) * cell
                        let rect = CGRect(x: x + cell * 0.12, y: y + cell * 0.12, width: cell * 0.76, height: cell * 0.76)
                        let distanceX = Double(characterIndex * 6 + column - columns / 2)
                        let distanceY = Double(row - 3) * 2
                        let radius = sqrt(distanceX * distanceX + distanceY * distanceY)
                        let maxRadius = max(1, sqrt(Double(columns * columns + 36)) / 2)
                        let collapseDelay = max(0, 1 - radius / maxRadius) * 0.68
                        let collapseAlpha: Double
                        if let collapseProgress {
                            collapseAlpha = max(0, 1 - max(0, collapseProgress - collapseDelay) / 0.22)
                        } else { collapseAlpha = 1 }
                        if oldFilled && !newFilled && local < 1 {
                            context.fill(Path(rect), with: .color(color.opacity((1 - local) * collapseAlpha)))
                        }
                        if newFilled && collapseAlpha > 0 {
                            let alpha = oldFilled ? 1 : local
                            let inset = oldFilled ? 0 : cell * (0.32 * (1 - local))
                            let entering = rect.insetBy(dx: inset, dy: inset)
                            context.fill(Path(entering), with: .color(color.opacity(alpha * collapseAlpha)))
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel(value)
        .onAppear { previousValue = value }
        .onChange(of: value) { oldValue, _ in
            previousValue = oldValue
            guard !reduceMotion else { progress = 1; return }
            transitionTask?.cancel()
            let totalFrames = max(1, Int(transitionDuration * frameRate))
            progress = 0
            transitionTask = Task { @MainActor in
                for frame in 1...totalFrames {
                    try? await Task.sleep(for: .milliseconds(Int(1000.0 / frameRate)))
                    guard !Task.isCancelled else { return }
                    progress = Double(frame) / Double(totalFrames)
                }
            }
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
        .shadow(color: color.opacity(0.12), radius: 7)
    }

    var height: CGFloat = 72
}
