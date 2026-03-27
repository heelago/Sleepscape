import SwiftUI

struct Palette: Identifiable {
    let id: String
    let name: String
    let background: Color
    let inks: [Color]

    static let all: [Palette] = [
        Palette(
            id: "moonlit", name: "moonlit",
            background: Color(hex: "#04030a"),
            inks: [
                Color(hex: "#c4b8e8"), Color(hex: "#5fcfcf"), Color(hex: "#a8c8f0"),
                Color(hex: "#d9768a"), Color(hex: "#6ecba8"), Color(hex: "#d4a96a"),
                Color(hex: "#e8d5b0"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "dusk", name: "dusk",
            background: Color(hex: "#06040e"),
            inks: [
                Color(hex: "#b8d4c8"), Color(hex: "#8fb8a8"), Color(hex: "#a8c8b8"),
                Color(hex: "#c8b8d8"), Color(hex: "#b8a8c8"), Color(hex: "#d8c8e0"),
                Color(hex: "#c0d0c8"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "slate", name: "slate",
            background: Color(hex: "#050810"),
            inks: [
                Color(hex: "#b8c8d8"), Color(hex: "#98a8c0"), Color(hex: "#a8b8c8"),
                Color(hex: "#d8c8b8"), Color(hex: "#c8b8a8"), Color(hex: "#c0c8d0"),
                Color(hex: "#d8d0c8"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "amber", name: "amber",
            background: Color(hex: "#080400"),
            inks: [
                Color(hex: "#d4b896"), Color(hex: "#c8a888"), Color(hex: "#e8d4b8"),
                Color(hex: "#d8c0a0"), Color(hex: "#e0c898"), Color(hex: "#c8b890"),
                Color(hex: "#f0dcc0"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "sakura", name: "sakura",
            background: Color(hex: "#08040a"),
            inks: [
                Color(hex: "#ffb7c5"), Color(hex: "#ff8fab"), Color(hex: "#ffc8dd"),
                Color(hex: "#ffafcc"), Color(hex: "#bde0fe"), Color(hex: "#a2d2ff"),
                Color(hex: "#e2b4bd"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "forest", name: "forest",
            background: Color(hex: "#010803"),
            inks: [
                Color(hex: "#74c69d"), Color(hex: "#52b788"), Color(hex: "#95d5b2"),
                Color(hex: "#a9def9"), Color(hex: "#d8f3dc"), Color(hex: "#e4c1f9"),
                Color(hex: "#b7e4c7"), Color(hex: "#ffffff"),
            ]
        ),
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
