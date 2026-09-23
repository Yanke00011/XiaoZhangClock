import Foundation
import Network
import Observation

@MainActor
enum TimePresentation {
    private static let twentyFourHourFormatter = makeFormatter("HH:mm:ss")
    private static let twelveHourFormatter = makeFormatter("h:mm:ss")
    private static let periodFormatter = makeFormatter("a")
    private static let longDateFormatter = makeFormatter("EEEE · yyyy年M月d日", calendar: Calendar(identifier: .gregorian))
    private static let shortDateFormatter = makeFormatter("yyyy年M月d日")

    static func clock(_ date: Date, uses24HourTime: Bool, timeZone: TimeZone) -> String {
        let formatter = uses24HourTime ? twentyFourHourFormatter : twelveHourFormatter
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    static func period(_ date: Date, timeZone: TimeZone) -> String {
        periodFormatter.timeZone = timeZone
        return periodFormatter.string(from: date)
    }

    static func longDate(_ date: Date, timeZone: TimeZone) -> String {
        longDateFormatter.timeZone = timeZone
        return longDateFormatter.string(from: date)
    }

    static func shortDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        shortDateFormatter.timeZone = timeZone
        return shortDateFormatter.string(from: date)
    }

    static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        twentyFourHourFormatter.timeZone = timeZone
        return twentyFourHourFormatter.string(from: date)
    }

    private static func makeFormatter(_ format: String, calendar: Calendar? = nil) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar ?? .current
        formatter.dateFormat = format
        return formatter
    }
}

enum TimeSource: String, CaseIterable, Identifiable {
    case local
    case network

    var id: String { rawValue }
    var title: String { self == .local ? "本地时间" : "实时时间" }
}

enum TimeSyncState: Equatable {
    case idle
    case syncing
    case synchronized
    case unavailable(String)

    var title: String {
        switch self {
        case .idle: "尚未同步"
        case .syncing: "正在同步…"
        case .synchronized: "已同步"
        case .unavailable(let message): message
        }
    }
}

@MainActor
@Observable
final class TimeEngine {
    static let shared = TimeEngine()

    private(set) var now = Date.now
    private(set) var monotonicNow = ContinuousClock().now
    private(set) var networkOffset: TimeInterval = 0
    private(set) var lastSynchronizedAt: Date?
    private(set) var syncState: TimeSyncState = .idle
    var source: TimeSource {
        didSet {
            UserDefaults.standard.set(source.rawValue, forKey: Self.sourcePreferenceKey)
            refreshNow()
            if source == .network {
                Task { await synchronize() }
            } else {
                scheduledSyncTask?.cancel()
                scheduledSyncTask = nil
            }
        }
    }

    private(set) var wantsHundredthUpdates = false
    private(set) var stopwatchAccumulated: TimeInterval = 0
    private(set) var stopwatchLaps: [TimeInterval] = []
    private var stopwatchStartedAt: ContinuousClock.Instant?
    private let clock = ContinuousClock()
    private var updateTask: Task<Void, Never>?
    private var stopwatchUpdateTask: Task<Void, Never>?
    private var scheduledSyncTask: Task<Void, Never>?
    private let server = SNTPTimeServer()
    private static let sourcePreferenceKey = "pixelTimeSource"

    private init() {
        source = TimeSource(rawValue: UserDefaults.standard.string(forKey: Self.sourcePreferenceKey) ?? "local") ?? .local
    }

    func start() {
        guard updateTask == nil else {
            if wantsHundredthUpdates { startStopwatchUpdateLoop() }
            return
        }
        refreshNow()
        startUpdateLoop()
        if wantsHundredthUpdates { startStopwatchUpdateLoop() }
        if source == .network { Task { await synchronize() } }
    }

    private func startUpdateLoop() {
        updateTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let fraction = self.now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
                let milliseconds = max(5, Int(((1 - fraction) * 1_000).rounded(.up)))
                let wait = Duration.milliseconds(milliseconds)
                try? await self.clock.sleep(for: wait)
                guard !Task.isCancelled else { return }
                self.refreshNow()
            }
        }
    }

    private func startStopwatchUpdateLoop() {
        guard stopwatchUpdateTask == nil, updateTask != nil else { return }
        stopwatchUpdateTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await self.clock.sleep(for: .milliseconds(33))
                guard !Task.isCancelled else { return }
                self.monotonicNow = self.clock.now
            }
        }
    }

    func stop() {
        updateTask?.cancel()
        updateTask = nil
        stopwatchUpdateTask?.cancel()
        stopwatchUpdateTask = nil
        scheduledSyncTask?.cancel()
        scheduledSyncTask = nil
    }

    func setHundredthUpdates(_ enabled: Bool) {
        guard wantsHundredthUpdates != enabled else { return }
        wantsHundredthUpdates = enabled
        if enabled { startStopwatchUpdateLoop() }
        else {
            stopwatchUpdateTask?.cancel()
            stopwatchUpdateTask = nil
        }
    }

    var stopwatchIsRunning: Bool { stopwatchStartedAt != nil }

    var stopwatchElapsed: TimeInterval {
        guard let stopwatchStartedAt else { return stopwatchAccumulated }
        return stopwatchAccumulated + Self.seconds(from: stopwatchStartedAt.duration(to: monotonicNow))
    }

    func startStopwatch() {
        guard stopwatchStartedAt == nil else { return }
        monotonicNow = clock.now
        stopwatchStartedAt = monotonicNow
        setHundredthUpdates(true)
    }

    func pauseStopwatch() {
        guard stopwatchStartedAt != nil else { return }
        monotonicNow = clock.now
        stopwatchAccumulated = stopwatchElapsed
        stopwatchStartedAt = nil
        setHundredthUpdates(false)
    }

    func resetStopwatch() {
        stopwatchStartedAt = nil
        stopwatchAccumulated = 0
        stopwatchLaps.removeAll()
        setHundredthUpdates(false)
    }

    var currentMonotonicNow: ContinuousClock.Instant { clock.now }

    func recordStopwatchLap() {
        guard stopwatchIsRunning else { return }
        stopwatchLaps.insert(stopwatchElapsed, at: 0)
    }

    func synchronize() async {
        guard syncState != .syncing else { return }
        syncState = .syncing
        do {
            let offset = try await server.measuredOffset()
            networkOffset = offset
            lastSynchronizedAt = .now
            syncState = .synchronized
            refreshNow()
            scheduleNextSynchronization()
        } catch {
            let message = lastSynchronizedAt == nil ? "网络不可用 · 使用本地时间" : "网络不可用 · 使用上次校准"
            syncState = .unavailable(message)
        }
    }

    func refreshForForeground() {
        refreshNow()
        if source == .network { Task { await synchronize() } }
    }

    private func scheduleNextSynchronization() {
        scheduledSyncTask?.cancel()
        guard source == .network else { return }
        scheduledSyncTask = Task { [weak self, clock] in
            try? await clock.sleep(for: .seconds(6 * 60 * 60))
            guard !Task.isCancelled, let self, self.source == .network else { return }
            await self.synchronize()
        }
    }

    private func refreshNow() {
        let wallTime = Date.now
        now = source == .network ? wallTime.addingTimeInterval(networkOffset) : wallTime
    }

    private static func seconds(from duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

private struct SNTPTimeServer {
    private let host = "time.google.com"

    func measuredOffset() async throws -> TimeInterval {
        var samples: [TimeInterval] = []
        for _ in 0..<3 {
            if let sample = try? await requestOffset() {
                samples.append(sample)
            }
        }
        guard !samples.isEmpty else { throw TimeServerError.unavailable }
        let sorted = samples.sorted()
        return sorted[sorted.count / 2]
    }

    private func requestOffset() async throws -> TimeInterval {
        let endpoint = NWEndpoint.Host(host)
        guard let port = NWEndpoint.Port(rawValue: 123) else { throw TimeServerError.invalidResponse }
        let connection = NWConnection(host: endpoint, port: port, using: .udp)
        return try await withCheckedThrowingContinuation { continuation in
            let gate = SNTPRequestGate(continuation: continuation)
            gate.setConnection(connection)
            gate.setTimeout(Task {
                try? await ContinuousClock().sleep(for: .seconds(5))
                gate.finish(.failure(TimeServerError.timeout))
            })
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let sentAt = Date.now
                    let request = Self.requestPacket(at: sentAt)
                    connection.send(content: request, completion: .contentProcessed { error in
                        if let error {
                            gate.finish(.failure(error))
                            return
                        }
                        connection.receive(minimumIncompleteLength: 48, maximumLength: 512) { data, _, _, error in
                            if let error {
                                gate.finish(.failure(error))
                            } else if let data, data.count >= 48 {
                                let receivedAt = Date.now
                                do {
                                    let offset = try Self.offset(from: data, sentAt: sentAt, receivedAt: receivedAt, request: request)
                                    gate.finish(.success(offset))
                                } catch {
                                    gate.finish(.failure(error))
                                }
                            } else {
                                gate.finish(.failure(TimeServerError.invalidResponse))
                            }
                        }
                    })
                case .failed(let error): gate.finish(.failure(error))
                case .cancelled: break
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
        }
    }

    private static func requestPacket(at date: Date) -> Data {
        var packet = Data(repeating: 0, count: 48)
        packet[0] = 0x23 // NTP v4 client request
        writeTimestamp(date, into: &packet, at: 40)
        return packet
    }

    private static func offset(from packet: Data, sentAt: Date, receivedAt: Date, request: Data) throws -> TimeInterval {
        let mode = packet[0] & 0x07
        let version = (packet[0] >> 3) & 0x07
        let leap = packet[0] >> 6
        let stratum = packet[1]
        guard mode == 4, version >= 3, leap != 3, (1...15).contains(stratum),
              packet[24..<32] == request[40..<48] else { throw TimeServerError.invalidResponse }

        let serverReceived = readTimestamp(packet, at: 32)
        let serverSent = readTimestamp(packet, at: 40)
        let roundTrip = receivedAt.timeIntervalSince(sentAt)
        guard roundTrip >= 0, roundTrip < 4 else { throw TimeServerError.invalidResponse }
        let offset = ((serverReceived.timeIntervalSince(sentAt)) + (serverSent.timeIntervalSince(receivedAt))) / 2
        guard offset.isFinite, abs(offset) < 86_400 else { throw TimeServerError.invalidResponse }
        return offset
    }

    private static func writeTimestamp(_ date: Date, into data: inout Data, at index: Int) {
        let ntpTime = date.timeIntervalSince1970 + 2_208_988_800
        let seconds = UInt32(ntpTime.rounded(.down))
        let fraction = UInt32((ntpTime - Double(seconds)) * 4_294_967_296)
        for offset in 0..<4 {
            data[index + offset] = UInt8((seconds >> UInt32((3 - offset) * 8)) & 0xFF)
            data[index + 4 + offset] = UInt8((fraction >> UInt32((3 - offset) * 8)) & 0xFF)
        }
    }

    private static func readTimestamp(_ data: Data, at index: Int) -> Date {
        var seconds: UInt32 = 0
        var fraction: UInt32 = 0
        for offset in 0..<4 {
            seconds = (seconds << 8) | UInt32(data[index + offset])
            fraction = (fraction << 8) | UInt32(data[index + 4 + offset])
        }
        return Date(timeIntervalSince1970: Double(seconds) - 2_208_988_800 + Double(fraction) / 4_294_967_296)
    }
}

private enum TimeServerError: Error {
    case invalidResponse
    case timeout
    case unavailable
}

private final class SNTPRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<TimeInterval, Error>?
    private var connection: NWConnection?
    private var timeout: Task<Void, Never>?

    init(continuation: CheckedContinuation<TimeInterval, Error>) {
        self.continuation = continuation
    }

    func setConnection(_ connection: NWConnection) {
        lock.lock(); self.connection = connection; lock.unlock()
    }

    func setTimeout(_ timeout: Task<Void, Never>) {
        lock.lock(); self.timeout = timeout; lock.unlock()
    }

    func finish(_ result: Result<TimeInterval, Error>) {
        lock.lock()
        guard let continuation else { lock.unlock(); return }
        self.continuation = nil
        let connection = self.connection
        let timeout = self.timeout
        self.connection = nil
        self.timeout = nil
        lock.unlock()
        timeout?.cancel()
        connection?.cancel()
        continuation.resume(with: result)
    }
}
