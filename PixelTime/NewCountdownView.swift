import SwiftUI
import SwiftData

struct NewCountdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let timeEngine: TimeEngine
    @State private var title = ""
    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var showError = false
    @State private var capsuleMode = false
    @State private var dateMode = false
    @State private var allDay = false
    @State private var style: CountdownStyle = .classic
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now.addingTimeInterval(86_400)
    private var duration: Int { days * 86_400 + hours * 3_600 + minutes * 60 + seconds }
    private let maxDuration = 365 * 86_400

    init(timeEngine: TimeEngine, isCapsule: Bool = false) {
        self.timeEngine = timeEngine
        _capsuleMode = State(initialValue: isCapsule)
    }

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
            if !capsuleMode {
                HStack(spacing: 6) {
                    modeButton("按时长", selected: !dateMode) { dateMode = false }
                    modeButton("按日期", selected: dateMode) { dateMode = true }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("名称")
                TextField("例如：周末旅行", text: $title).textFieldStyle(.plain).pixelFont(.body).foregroundStyle(PixelTheme.text)
                    .padding(12).background(PixelTheme.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PixelTheme.border, lineWidth: 1))
            }
            if capsuleMode || dateMode {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel(capsuleMode ? "胶囊开启时间" : "目标日期")
                    DatePicker("日期", selection: $targetDate, in: timeEngine.now..., displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden().environment(\.font, PixelTypography.font(.body))
                    if !capsuleMode {
                        Toggle(isOn: $allDay) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("全天事件").pixelFont(.body).foregroundStyle(PixelTheme.text)
                                Text("按日历日期计算，不指定时刻").pixelFont(.caption).foregroundStyle(PixelTheme.muted)
                            }
                        }.toggleStyle(.switch).tint(PixelTheme.primary)
                    }
                    if !allDay || capsuleMode {
                        DatePicker("时间", selection: $targetDate, in: timeEngine.now..., displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact).labelsHidden().environment(\.font, PixelTypography.font(.body))
                    }
                    Text(capsuleMode ? "到达这个时刻，胶囊便会开启。" : (allDay ? "目标日期按当前日历和时区计算。" : "进入最后 24 小时后，将显示时分秒。"))
                        .pixelFont(.caption).foregroundStyle(PixelTheme.muted)
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
                Text(capsuleMode || dateMode ? "请填写名称，并选择未来的日期或时间。" : "请填写名称和时长（1 秒至 365 天）。")
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
    private func create() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isScheduledDate = !capsuleMode && dateMode
        let selectedTarget = capsuleMode || isScheduledDate ? targetDate : nil
        let normalizedTarget: Date?
        if isScheduledDate && allDay, let selectedTarget {
            normalizedTarget = Calendar.current.startOfDay(for: selectedTarget)
        } else {
            normalizedTarget = selectedTarget
        }
        let targetDuration = normalizedTarget?.timeIntervalSince(timeEngine.now) ?? 0
        guard !cleanTitle.isEmpty,
              ((capsuleMode || isScheduledDate) ? targetDuration > 0 : duration > 0),
              capsuleMode || isScheduledDate || duration <= maxDuration else { showError = true; return }
        let item = Countdown(title: cleanTitle,
                             duration: capsuleMode || isScheduledDate ? targetDuration : TimeInterval(duration),
                             style: style,
                             isCapsule: capsuleMode,
                             targetDate: normalizedTarget,
                             isDateBased: isScheduledDate,
                             isAllDay: isScheduledDate && allDay,
                             createdAt: timeEngine.now)
        if capsuleMode || isScheduledDate { item.isRunning = true }
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
