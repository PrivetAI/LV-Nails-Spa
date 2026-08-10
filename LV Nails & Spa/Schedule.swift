import Foundation
import Combine

/// A quarter of the day. The salon books by chair rather than by name, so the useful
/// unit here is "how much of the morning is left", not "which person is free".
enum PartOfDay: String, CaseIterable, Identifiable {
    case morning, afternoon, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    var window: (from: Int, to: Int) {
        switch self {
        case .morning: return (0, 12 * 60)
        case .afternoon: return (12 * 60, 17 * 60)
        case .evening: return (17 * 60, 24 * 60)
        }
    }

    func contains(_ minutes: Int) -> Bool {
        minutes >= window.from && minutes < window.to
    }
}

struct ChairTime: Identifiable, Equatable {
    let minutes: Int
    /// How many of the salon's chairs are still free at this time.
    let chairsFree: Int

    var id: Int { minutes }
    var isFree: Bool { chairsFree > 0 }
    var label: String { Salon.clock(minutes) }
}

struct Reservation: Identifiable, Codable, Equatable {
    let id: UUID
    var treatmentId: String
    var day: Date
    var minutes: Int
    /// Add-ons booked alongside the main set — the salon's own suggestion, and the reason
    /// a reservation can run longer than its headline treatment.
    var extraIds: [String]

    init(id: UUID = UUID(), treatmentId: String, day: Date, minutes: Int, extraIds: [String]) {
        self.id = id
        self.treatmentId = treatmentId
        self.day = day
        self.minutes = minutes
        self.extraIds = extraIds
    }

    /// Read field by field with defaults, so adding a property later cannot make an older
    /// saved list fail to decode and quietly wipe somebody's appointments.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        treatmentId = try box.decodeIfPresent(String.self, forKey: .treatmentId) ?? ""
        day = try box.decodeIfPresent(Date.self, forKey: .day) ?? Date()
        minutes = try box.decodeIfPresent(Int.self, forKey: .minutes) ?? 0
        extraIds = try box.decodeIfPresent([String].self, forKey: .extraIds) ?? []
    }

    var treatment: Treatment? { Salon.treatment(treatmentId) }
    var extras: [Treatment] { extraIds.compactMap { Salon.treatment($0) } }

    var totalCents: Int {
        (treatment?.priceCents ?? 0) + extras.reduce(0) { $0 + $1.priceCents }
    }

    var totalMinutes: Int {
        (treatment?.minutes ?? 0) + extras.reduce(0) { $0 + $1.minutes }
    }

    var start: Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                              second: 0, of: day) ?? day
    }
}

/// Chair occupancy that behaves like a real book: identical between launches, and moving
/// together across the room so a busy hour is a busy hour rather than four coin flips.
enum ChairLoad {
    /// FNV-1a. `String.hashValue` is seeded per process and would reshuffle the whole
    /// week on every launch — the 2:30 chair taken this morning must still be taken now.
    static func digest(_ text: String) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x100000001b3
        }
        return value
    }

    static func unit(_ text: String) -> Double {
        Double(digest(text) % 10_000) / 10_000
    }

    static func chairsFree(dayKey: String, minutes: Int) -> Int {
        let pressure = unit("room|\(dayKey)|\(minutes)")
        // Saturday afternoons and the run-up to the evening fill first.
        let lateness = max(0, Double(minutes - 12 * 60)) / Double(7 * 60)
        let busy = 0.28 + pressure * 0.5 + lateness * 0.2
        var free = 0
        for chair in 0..<Salon.chairCount {
            if unit("chair|\(dayKey)|\(minutes)|\(chair)") > busy { free += 1 }
        }
        return free
    }
}

final class Schedule: ObservableObject {
    @Published private(set) var reservations: [Reservation] = []

    private let storageKey = "lvnails.reservations.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Reservation].self, from: raw) {
            reservations = decoded
        }
    }

    static func dayKey(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }

    /// Every quarter hour the salon is open, with the number of chairs still free. A
    /// treatment only fits if a chair stays free for its whole run.
    func chairTimes(on day: Date, runningFor minutes: Int) -> [ChairTime] {
        let weekday = Calendar.current.component(.weekday, from: day)
        let hours = Salon.hours(for: weekday)
        let key = Schedule.dayKey(day)

        var result: [ChairTime] = []
        var start = hours.opensAt
        while start + minutes <= hours.closesAt {
            var free = Salon.chairCount
            var step = start
            while step < start + minutes {
                free = min(free, ChairLoad.chairsFree(dayKey: key, minutes: step))
                step += 15
            }
            if isHeld(day: day, from: start, to: start + minutes) { free = 0 }
            result.append(ChairTime(minutes: start, chairsFree: free))
            start += 30
        }
        return result
    }

    func chairTimes(on day: Date, runningFor minutes: Int, part: PartOfDay) -> [ChairTime] {
        chairTimes(on: day, runningFor: minutes).filter { part.contains($0.minutes) }
    }

    /// The soonest chair inside the next fortnight, or nil if the salon is full.
    func soonest(for minutes: Int) -> (day: Date, time: ChairTime)? {
        let calendar = Calendar.current
        let now = Date()
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            for time in chairTimes(on: day, runningFor: minutes) where time.isFree {
                if offset == 0 {
                    let nowMinutes = calendar.component(.hour, from: now) * 60
                        + calendar.component(.minute, from: now)
                    if time.minutes <= nowMinutes { continue }
                }
                return (day, time)
            }
        }
        return nil
    }

    private func isHeld(day: Date, from: Int, to: Int) -> Bool {
        let key = Schedule.dayKey(day)
        return reservations.contains { held in
            guard Schedule.dayKey(held.day) == key else { return false }
            let heldEnd = held.minutes + max(15, held.totalMinutes)
            return from < heldEnd && to > held.minutes
        }
    }

    func reserve(_ treatment: Treatment, extras: [Treatment], day: Date, minutes: Int) {
        reservations.append(Reservation(treatmentId: treatment.id,
                                        day: day,
                                        minutes: minutes,
                                        extraIds: extras.map { $0.id }))
        persist()
    }

    func drop(_ reservation: Reservation) {
        reservations.removeAll { $0.id == reservation.id }
        persist()
    }

    var upcoming: [Reservation] {
        reservations.filter { $0.start >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.start < $1.start }
    }

    var past: [Reservation] {
        reservations.filter { $0.start < Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.start > $1.start }
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(reservations) {
            UserDefaults.standard.set(raw, forKey: storageKey)
        }
    }
}

/// Open or closed, worked out from the salon's own hours. Seven days means this never
/// has to say "closed all day" — only "not yet" or "not any more".
enum DoorState {
    case open(until: Int)
    case closingSoon(until: Int)
    case beforeOpening(at: Int)
    case shut(day: String, at: Int)

    static func now(_ moment: Date = Date()) -> DoorState {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: moment)
        let minutes = calendar.component(.hour, from: moment) * 60
            + calendar.component(.minute, from: moment)
        let today = Salon.hours(for: weekday)

        if minutes < today.opensAt { return .beforeOpening(at: today.opensAt) }
        if minutes < today.closesAt {
            return today.closesAt - minutes <= 60 ? .closingSoon(until: today.closesAt)
                                                  : .open(until: today.closesAt)
        }
        let nextDay = weekday % 7 + 1
        return .shut(day: "tomorrow", at: Salon.hours(for: nextDay).opensAt)
    }

    var isOpen: Bool {
        switch self {
        case .open, .closingSoon: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .open(let until): return "OPEN UNTIL \(Salon.clock(until).uppercased())"
        case .closingSoon(let until): return "CLOSING AT \(Salon.clock(until).uppercased())"
        case .beforeOpening(let at): return "OPENS \(Salon.clock(at).uppercased())"
        case .shut(let day, let at): return "OPENS \(day.uppercased()) \(Salon.clock(at).uppercased())"
        }
    }
}

enum Mark {
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func number(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
