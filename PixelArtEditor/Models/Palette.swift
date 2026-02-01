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

    static let nes = Palette(id: "nes", name: "NES", colors: [
        UIColor(red: 0, green: 0, blue: 0, alpha: 1),
        UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1),
        UIColor(red: 0.74, green: 0.74, blue: 0.74, alpha: 1),
        UIColor(red: 0.38, green: 0.38, blue: 0.38, alpha: 1),
        UIColor(red: 0.94, green: 0.16, blue: 0.16, alpha: 1),
        UIColor(red: 0.13, green: 0.54, blue: 0.13, alpha: 1),
        UIColor(red: 0.13, green: 0.25, blue: 0.85, alpha: 1),
        UIColor(red: 0.94, green: 0.82, blue: 0.16, alpha: 1),
        UIColor(red: 0.94, green: 0.5, blue: 0.13, alpha: 1),
        UIColor(red: 0.54, green: 0.16, blue: 0.54, alpha: 1),
        UIColor(red: 0.25, green: 0.69, blue: 0.82, alpha: 1),
        UIColor(red: 0.94, green: 0.54, blue: 0.54, alpha: 1),
    ])

    static let gameBoy = Palette(id: "gameboy", name: "Game Boy", colors: [
        UIColor(red: 0.06, green: 0.22, blue: 0.06, alpha: 1),
        UIColor(red: 0.19, green: 0.38, blue: 0.19, alpha: 1),
        UIColor(red: 0.55, green: 0.67, blue: 0.06, alpha: 1),
        UIColor(red: 0.61, green: 0.74, blue: 0.06, alpha: 1),
    ])

    static let allPalettes: [Palette] = [classic16, pastel, earthTones, nes, gameBoy]
}
