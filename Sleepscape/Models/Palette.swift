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
            id: "aurora", name: "aurora",
            background: Color(hex: "#040210"),
            inks: [
                Color(hex: "#7fffd4"), Color(hex: "#40e0d0"), Color(hex: "#9370db"),
                Color(hex: "#da70d6"), Color(hex: "#87ceeb"), Color(hex: "#b0e0e6"),
                Color(hex: "#dda0dd"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "ocean", name: "ocean",
            background: Color(hex: "#010810"),
            inks: [
                Color(hex: "#caf0f8"), Color(hex: "#90e0ef"), Color(hex: "#48cae4"),
                Color(hex: "#ade8f4"), Color(hex: "#0096c7"), Color(hex: "#e0fbfc"),
                Color(hex: "#98c1d9"), Color(hex: "#ffffff"),
            ]
        ),
        Palette(
            id: "ember", name: "ember",
            background: Color(hex: "#0a0300"),
            inks: [
                Color(hex: "#ffcba4"), Color(hex: "#ff9f6b"), Color(hex: "#ffb347"),
                Color(hex: "#ffd93d"), Color(hex: "#ff6b9d"), Color(hex: "#f72585"),
                Color(hex: "#ff4757"), Color(hex: "#ffffff"),
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
