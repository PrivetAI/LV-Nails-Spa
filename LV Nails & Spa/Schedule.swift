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

    /// A quarter of today that has already gone by. It keeps its place in the grid, so
    /// the shape of the day still reads, but it cannot be taken.
    let isPast: Bool

    var id: Int { minutes }
    var isFree: Bool { chairsFree > 0 }
    var isTakeable: Bool { isFree && !isPast }
    var label: String { Salon.clock(minutes) }
}

/// Date formatting is pinned rather than left to the device. `DateFormatter` otherwise
/// follows the phone's locale and calendar, which would translate the day strip and — far
/// worse — change the day key every chair-load hash is built on, reshuffling the whole
/// fortnight for anyone whose phone is not on English and Gregorian.
enum Fixed {
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func formatter(_ format: String, posix: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: posix ? "en_US_POSIX" : "en_US")
        formatter.calendar = Fixed.gregorian
        formatter.dateFormat = format
        return formatter
    }
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

    /// The string every chair-load hash is seeded from, so it has to be stable whatever
    /// the phone's language and calendar are set to.
    static let keyFormatter = Fixed.formatter("yyyy-MM-dd", posix: true)

    static func dayKey(_ day: Date) -> String {
        keyFormatter.string(from: day)
    }

    /// Minutes from midnight, right now. Used to retire the quarters already spent.
    private static var minutesNow: Int {
        let parts = Fixed.gregorian.dateComponents([.hour, .minute], from: Date())
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Every quarter hour the salon is open, with the number of chairs still free. A
    /// treatment only fits if a chair stays free for its whole run.
    func chairTimes(on day: Date, runningFor minutes: Int) -> [ChairTime] {
        let weekday = Calendar.current.component(.weekday, from: day)
        let hours = Salon.hours(for: weekday)
        let key = Schedule.dayKey(day)
        // Only today has a past; every other day in the strip is open end to end.
        let cutoff = Fixed.gregorian.isDateInToday(day) ? Schedule.minutesNow : -1

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
            result.append(ChairTime(minutes: start, chairsFree: free, isPast: start <= cutoff))
            start += 30
        }
        return result
    }

    func chairTimes(on day: Date, runningFor minutes: Int, part: PartOfDay) -> [ChairTime] {
        chairTimes(on: day, runningFor: minutes).filter { part.contains($0.minutes) }
    }

    /// The soonest chair inside the next fortnight, or nil if the salon is full.
    func soonest(for minutes: Int) -> (day: Date, time: ChairTime)? {
        let now = Date()
        for offset in 0..<14 {
            guard let day = Fixed.gregorian.date(byAdding: .day, value: offset, to: now) else { continue }
            // `isTakeable` already retires the quarters today has spent, so the search no
            // longer has to special-case the first day.
            if let time = chairTimes(on: day, runningFor: minutes).first(where: { $0.isTakeable }) {
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

/// Built once and pinned to English and Gregorian — this app ships in English only, and a
/// day strip that changed language with the phone would not match the salon's own sign.
enum Mark {
    private static let full = Fixed.formatter("EEE d MMM")
    private static let short = Fixed.formatter("EEE")
    private static let figure = Fixed.formatter("d")

    static func day(_ date: Date) -> String { full.string(from: date) }
    static func weekday(_ date: Date) -> String { short.string(from: date) }
    static func number(_ date: Date) -> String { figure.string(from: date) }
}
