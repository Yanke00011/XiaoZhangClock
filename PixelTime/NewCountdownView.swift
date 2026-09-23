import SwiftUI
import SwiftData

struct NewCountdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var showError = false
    @State private var capsuleMode = false
    @State private var style: CountdownStyle = .classic
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now.addingTimeInterval(86_400)
    @State private var targetDateText = ""
    private var duration: Int { days * 86_400 + hours * 3_600 + minutes * 60 + seconds }
    private let maxDuration = 365 * 86_400

    init(isCapsule: Bool = false) { _capsuleMode = State(initialValue: isCapsule) }

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(capsuleMode ? "新建时间胶囊" : "新建倒计时").pixelFont(.headline).tracking(1).foregroundStyle(PixelTheme.text)
                    Text("为下一段时光取个名字").pixelFont(.caption).tracking(0.6).foregroundStyle(PixelTheme.muted)
                }
                Spacer()
                Button { dismiss() } label: { Text("×").pixelFont(.body).foregroundStyle(PixelTheme.muted).padding(7).background(Color.white.opacity(0.06), in: Circle()) }.buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                modeButton("倒计时", selected: !capsuleMode) { capsuleMode = false }
                modeButton("时间胶囊", selected: capsuleMode) { capsuleMode = true }
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("名称")
                TextField("例如：周末旅行", text: $title).textFieldStyle(.plain).pixelFont(.body).foregroundStyle(PixelTheme.text)
                    .padding(12).background(PixelTheme.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PixelTheme.border, lineWidth: 1))
            }
            if capsuleMode {
                VStack(alignment: .leading, spacing: 9) {
                    fieldLabel("开启时间")
                    TextField("年-月-日 时:分", text: $targetDateText).textFieldStyle(.plain).pixelFont(.body)
                        .foregroundStyle(PixelTheme.text).padding(11)
                        .background(PixelTheme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PixelTheme.border, lineWidth: 1))
                    Text("到达这个时刻，胶囊便会开启。").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                }
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    fieldLabel("时长")
                    HStack(spacing: 6) {
                        durationPicker("天", value: $days, range: 0...365)
                        durationPicker("时", value: $hours, range: 0...23)
                        durationPicker("分", value: $minutes, range: 0...59)
                        durationPicker("秒", value: $seconds, range: 0...59)
                    }
                    fieldLabel("显示样式")
                    HStack(spacing: 6) {
                        ForEach(CountdownStyle.allCases) { item in
                            modeButton(item.title, selected: style == item) { style = item }
                        }
                    }
                }
            }
            if showError {
                Text(capsuleMode ? "请填写名称和未来时间，格式：年-月-日 时:分。" : "请填写名称和时长（1 秒至 365 天）。")
                    .pixelFont(.caption).foregroundStyle(.orange)
            }
            HStack(spacing: 10) {
                Button("取消") { dismiss() }.pixelFont(.button).tracking(0.6).foregroundStyle(PixelTheme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                Button(action: create) {
                    HStack { PixelIcon(symbol: .plus, color: PixelTheme.background, size: 10); Text("创建").pixelFont(.button) }
                        .tracking(0.6).foregroundStyle(PixelTheme.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 12).background(PixelTheme.primary, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(PixelButtonStyle())
            }
        }
        .padding(24).frame(width: 420).background(PixelTheme.surface).preferredColorScheme(.dark)
        .onAppear { targetDateText = formatted(targetDate) }
        .onChange(of: targetDateText) { _, newValue in if let date = parseDate(newValue) { targetDate = date } }
    }

    private func fieldLabel(_ value: String) -> some View {
        Text(value).pixelFont(.caption).tracking(0.6).foregroundStyle(PixelTheme.muted)
    }
    private func durationPicker(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 5) {
            Text(label).pixelFont(.caption).tracking(0.1).foregroundStyle(PixelTheme.muted)
            HStack(spacing: 3) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) } label: { Text("−").pixelFont(.caption).foregroundStyle(PixelTheme.primary) }
                Text(String(format: "%02d", value.wrappedValue)).pixelFont(.caption).foregroundStyle(PixelTheme.text).frame(minWidth: 21)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) } label: { Text("+").pixelFont(.caption).foregroundStyle(PixelTheme.primary) }
            }.buttonStyle(.plain).frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(PixelTheme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
        }
    }
    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).pixelFont(.caption).tracking(0.1).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(selected ? PixelTheme.background : PixelTheme.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(selected ? PixelTheme.primary : PixelTheme.background.opacity(0.72), in: Rectangle())
                .overlay(Rectangle().stroke(selected ? PixelTheme.primary : PixelTheme.border, lineWidth: 1))
        }.buttonStyle(PixelButtonStyle())
    }
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)
    }
    private func create() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let capsuleTarget = capsuleMode ? parseDate(targetDateText) : nil
        if capsuleMode && capsuleTarget == nil { showError = true; return }
        let capsuleDuration = capsuleTarget?.timeIntervalSinceNow ?? 0
        guard !cleanTitle.isEmpty,
              capsuleMode ? capsuleDuration > 0 : duration > 0,
              capsuleMode || duration <= maxDuration else { showError = true; return }
        let item = Countdown(title: cleanTitle,
                             duration: capsuleMode ? capsuleDuration : TimeInterval(duration),
                             style: style,
                             isCapsule: capsuleMode,
                             targetDate: capsuleTarget)
        if capsuleMode { item.isRunning = true }
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
