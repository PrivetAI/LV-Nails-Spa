import Foundation

struct Treatment: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let priceCents: Int
    let minutes: Int
    let isSignature: Bool
}

struct TreatmentGroup: Identifiable, Equatable {
    let id: String
    let name: String
    let note: String?
    let treatments: [Treatment]
}

struct DayHours: Identifiable, Equatable {
    /// 1 = Sunday, matching Calendar's own weekday numbering.
    let weekday: Int
    let opensAt: Int
    let closesAt: Int

    var id: Int { weekday }
    var dayName: String { Salon.weekdayNames[weekday] }
    var rangeLabel: String { "\(Salon.clock(opensAt)) – \(Salon.clock(closesAt))" }
    /// Sunday runs short. It is the row people actually scan for, so it is worth marking.
    var isShortDay: Bool { closesAt - opensAt < 8 * 60 }
}

enum Salon {
    static let name = "LV Nails & Spa"
    static let shortName = "LV Nails"
    static let tagline = "West Hillsborough Avenue. Walk in, or hold your chair from here."
    static let about = "Gel, dip and acrylic, spa pedicures with a proper massage chair, and a "
        + "colour wall that gets restocked every season."
    static let street = "2513 W Hillsborough Ave"
    static let city = "Tampa"
    static let region = "FL"
    static let postalCode = "33614"
    static let phone = "(813) 999-1115"
    /// What this trade calls the person doing the work. Not "stylist", not "barber".
    static let techNoun = "tech"
    /// No named roster here — the salon books by chair, not by person.
    static let chairCount = 4

    static let ratingAverage = 4.9
    static let ratingCount = 132

    static var addressLine: String { "\(street), \(city), \(region) \(postalCode)" }

    static let menu: [TreatmentGroup] = [
        TreatmentGroup(id: "hands", name: "Hands",
                       note: "Every set includes cuticle work and a hand massage.",
                       treatments: [
            Treatment(id: "mani-classic", name: "Classic Manicure",
                      detail: "Shape, cuticles, regular polish.",
                      priceCents: 2500, minutes: 30, isSignature: false),
            Treatment(id: "mani-gel", name: "Gel Manicure",
                      detail: "Two weeks of wear, no chipping.",
                      priceCents: 4000, minutes: 45, isSignature: true),
            Treatment(id: "dip-powder", name: "Dip Powder",
                      detail: "Stronger than gel, three to four weeks.",
                      priceCents: 5000, minutes: 60, isSignature: false),
            Treatment(id: "acrylic-full", name: "Acrylic Full Set",
                      detail: "Length, shape and colour of your choosing.",
                      priceCents: 6000, minutes: 75, isSignature: false),
            Treatment(id: "acrylic-fill", name: "Acrylic Fill",
                      detail: "Every two to three weeks.",
                      priceCents: 4500, minutes: 60, isSignature: false),
            Treatment(id: "polish-change", name: "Polish Change",
                      detail: "Colour only, no shaping.",
                      priceCents: 1500, minutes: 20, isSignature: false)
        ]),
        TreatmentGroup(id: "feet", name: "Feet", note: nil, treatments: [
            Treatment(id: "pedi-classic", name: "Classic Pedicure",
                      detail: "Soak, scrub, shape and polish.",
                      priceCents: 3500, minutes: 45, isSignature: false),
            Treatment(id: "pedi-deluxe", name: "Deluxe Spa Pedicure",
                      detail: "Sugar scrub, mask, hot stones and an extended massage.",
                      priceCents: 5500, minutes: 60, isSignature: true),
            Treatment(id: "pedi-gel", name: "Gel Pedicure",
                      detail: "Classic pedicure finished in gel.",
                      priceCents: 5000, minutes: 60, isSignature: false)
        ]),
        TreatmentGroup(id: "extras", name: "Add-ons", note: "Book alongside any set.",
                       treatments: [
            Treatment(id: "nail-art", name: "Nail Art",
                      detail: "Per hand. Bring a photo.",
                      priceCents: 1000, minutes: 15, isSignature: false),
            Treatment(id: "paraffin", name: "Paraffin Dip",
                      detail: "Hands or feet.",
                      priceCents: 1500, minutes: 20, isSignature: false)
        ])
    ]

    static var allTreatments: [Treatment] { menu.flatMap { $0.treatments } }

    static func treatment(_ id: String) -> Treatment? { allTreatments.first { $0.id == id } }

    static var cheapestCents: Int { allTreatments.map { $0.priceCents }.min() ?? 0 }

    /// Open all seven days. Sunday is the odd one — eleven to five, and the hours table
    /// shows that asymmetry rather than flattening it into one line.
    static let hours: [DayHours] = [
        DayHours(weekday: 1, opensAt: 11 * 60, closesAt: 17 * 60),
        DayHours(weekday: 2, opensAt: 9 * 60 + 30, closesAt: 19 * 60),
        DayHours(weekday: 3, opensAt: 9 * 60 + 30, closesAt: 19 * 60),
        DayHours(weekday: 4, opensAt: 9 * 60 + 30, closesAt: 19 * 60),
        DayHours(weekday: 5, opensAt: 9 * 60 + 30, closesAt: 19 * 60),
        DayHours(weekday: 6, opensAt: 9 * 60 + 30, closesAt: 19 * 60),
        DayHours(weekday: 7, opensAt: 9 * 60 + 30, closesAt: 19 * 60)
    ]

    static func hours(for weekday: Int) -> DayHours {
        hours.first { $0.weekday == weekday } ?? hours[0]
    }

    static var weekOrdered: [DayHours] {
        [2, 3, 4, 5, 6, 7, 1].compactMap { day in hours.first { $0.weekday == day } }
    }

    static let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday",
                               "Thursday", "Friday", "Saturday"]

    static func clock(_ minutes: Int) -> String {
        let hour = minutes / 60, minute = minutes % 60
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return minute == 0 ? "\(hour12) \(suffix)"
                           : String(format: "%d:%02d %@", hour12, minute, suffix)
    }

    static func money(_ cents: Int) -> String {
        cents % 100 == 0 ? "$\(cents / 100)" : String(format: "$%.2f", Double(cents) / 100)
    }

    static func length(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }
}
