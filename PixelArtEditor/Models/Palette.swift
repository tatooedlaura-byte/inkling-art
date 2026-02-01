import UIKit

struct Palette: Identifiable {
    let id: String
    let name: String
    let colors: [UIColor]
}

extension Palette {
    static let classic16 = Palette(id: "classic16", name: "Classic 16", colors: [
        UIColor(red: 0, green: 0, blue: 0, alpha: 1),
        UIColor(red: 1, green: 1, blue: 1, alpha: 1),
        UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1),
        UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        UIColor(red: 1, green: 0, blue: 0, alpha: 1),
        UIColor(red: 0, green: 1, blue: 0, alpha: 1),
        UIColor(red: 0, green: 0, blue: 1, alpha: 1),
        UIColor(red: 1, green: 1, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.5, blue: 0, alpha: 1),
        UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1),
        UIColor(red: 0, green: 1, blue: 1, alpha: 1),
        UIColor(red: 1, green: 0, blue: 1, alpha: 1),
        UIColor(red: 0.5, green: 0.25, blue: 0, alpha: 1),
        UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),
        UIColor(red: 0, green: 0, blue: 0.5, alpha: 1),
        UIColor(red: 1, green: 0.75, blue: 0.8, alpha: 1),
    ])

    static let pastel = Palette(id: "pastel", name: "Pastel", colors: [
        UIColor(red: 1, green: 0.7, blue: 0.7, alpha: 1),
        UIColor(red: 1, green: 0.85, blue: 0.7, alpha: 1),
        UIColor(red: 1, green: 1, blue: 0.7, alpha: 1),
        UIColor(red: 0.7, green: 1, blue: 0.7, alpha: 1),
        UIColor(red: 0.7, green: 1, blue: 1, alpha: 1),
        UIColor(red: 0.7, green: 0.7, blue: 1, alpha: 1),
        UIColor(red: 1, green: 0.7, blue: 1, alpha: 1),
        UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
        UIColor(red: 0.85, green: 0.75, blue: 0.7, alpha: 1),
        UIColor(red: 0.7, green: 0.85, blue: 0.75, alpha: 1),
        UIColor(red: 0.8, green: 0.7, blue: 0.85, alpha: 1),
        UIColor(red: 1, green: 0.8, blue: 0.85, alpha: 1),
    ])

    static let earthTones = Palette(id: "earth", name: "Earth Tones", colors: [
        UIColor(red: 0.24, green: 0.16, blue: 0.08, alpha: 1),
        UIColor(red: 0.4, green: 0.26, blue: 0.13, alpha: 1),
        UIColor(red: 0.55, green: 0.37, blue: 0.2, alpha: 1),
        UIColor(red: 0.72, green: 0.53, blue: 0.34, alpha: 1),
        UIColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1),
        UIColor(red: 0.34, green: 0.42, blue: 0.18, alpha: 1),
        UIColor(red: 0.48, green: 0.55, blue: 0.27, alpha: 1),
        UIColor(red: 0.6, green: 0.44, blue: 0.33, alpha: 1),
        UIColor(red: 0.76, green: 0.6, blue: 0.42, alpha: 1),
        UIColor(red: 0.93, green: 0.87, blue: 0.73, alpha: 1),
    ])

    static let sunset = Palette(id: "sunset", name: "Sunset", colors: [
        UIColor(red: 0.16, green: 0.09, blue: 0.20, alpha: 1),
        UIColor(red: 0.35, green: 0.11, blue: 0.33, alpha: 1),
        UIColor(red: 0.60, green: 0.15, blue: 0.32, alpha: 1),
        UIColor(red: 0.84, green: 0.24, blue: 0.24, alpha: 1),
        UIColor(red: 0.95, green: 0.45, blue: 0.18, alpha: 1),
        UIColor(red: 1.00, green: 0.67, blue: 0.20, alpha: 1),
        UIColor(red: 1.00, green: 0.85, blue: 0.35, alpha: 1),
        UIColor(red: 1.00, green: 0.95, blue: 0.70, alpha: 1),
    ])

    static let ocean = Palette(id: "ocean", name: "Ocean", colors: [
        UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1),
        UIColor(red: 0.07, green: 0.16, blue: 0.31, alpha: 1),
        UIColor(red: 0.10, green: 0.30, blue: 0.50, alpha: 1),
        UIColor(red: 0.15, green: 0.47, blue: 0.65, alpha: 1),
        UIColor(red: 0.25, green: 0.65, blue: 0.75, alpha: 1),
        UIColor(red: 0.50, green: 0.82, blue: 0.82, alpha: 1),
        UIColor(red: 0.75, green: 0.93, blue: 0.90, alpha: 1),
        UIColor(red: 0.94, green: 0.98, blue: 0.96, alpha: 1),
    ])

    static let neon = Palette(id: "neon", name: "Neon", colors: [
        UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1),
        UIColor(red: 1.00, green: 0.10, blue: 0.40, alpha: 1),
        UIColor(red: 1.00, green: 0.20, blue: 0.80, alpha: 1),
        UIColor(red: 0.40, green: 0.10, blue: 1.00, alpha: 1),
        UIColor(red: 0.10, green: 0.80, blue: 1.00, alpha: 1),
        UIColor(red: 0.10, green: 1.00, blue: 0.50, alpha: 1),
        UIColor(red: 1.00, green: 1.00, blue: 0.20, alpha: 1),
        UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
    ])

    static let berry = Palette(id: "berry", name: "Berry", colors: [
        UIColor(red: 0.18, green: 0.05, blue: 0.15, alpha: 1),
        UIColor(red: 0.40, green: 0.08, blue: 0.28, alpha: 1),
        UIColor(red: 0.62, green: 0.12, blue: 0.40, alpha: 1),
        UIColor(red: 0.80, green: 0.20, blue: 0.50, alpha: 1),
        UIColor(red: 0.90, green: 0.40, blue: 0.55, alpha: 1),
        UIColor(red: 0.95, green: 0.60, blue: 0.65, alpha: 1),
        UIColor(red: 0.55, green: 0.15, blue: 0.55, alpha: 1),
        UIColor(red: 0.35, green: 0.20, blue: 0.55, alpha: 1),
    ])

    static let allPalettes: [Palette] = [classic16, pastel, earthTones, sunset, ocean, neon, berry]
}
