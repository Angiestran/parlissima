import SwiftUI

// MARK: - Cybergumman: Talas figur. Silverlila knut med antenn, cyberglasögon som lyser
// ljusblått i vila och korall när hon lyssnar, headset-mikrofon och indigo kofta.

struct GrannyView: View {
    @ObservedObject var model: HUDModel
    @State private var hover = false
    @State private var antennaOn = true

    enum Mood { case idle, listening, writing, happy, worried }
    private var mood: Mood {
        switch model.phase {
        case .listening, .waiting: return .listening
        case .writing: return .writing
        case .done: return .happy
        case .problem: return .worried
        case .hidden: return .idle
        }
    }
    private var level: CGFloat { CGFloat(model.levels.suffix(4).max() ?? 0) }

    static let size = CGSize(width: 136, height: 156)

    private let skinTop = Color(red: 0xf7/255, green: 0xdc/255, blue: 0xcb/255)
    private let skinBottom = Color(red: 0xe6/255, green: 0xb6/255, blue: 0x9e/255)
    private let hairTop = Color(red: 0xe4/255, green: 0xdf/255, blue: 0xf7/255)
    private let hairBottom = Color(red: 0xa8/255, green: 0x9e/255, blue: 0xd6/255)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Brand.coral.opacity(0.5), .clear], center: .center,
                                     startRadius: 14, endRadius: 70))
                .scaleEffect(mood == .listening ? 1 + level * 0.4 : 0.6)
                .opacity(mood == .listening ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: level)

            figure
                .scaleEffect(hover ? 1.05 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hover)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .help(mood == .listening ? "Klicka när du är klar" : "Klicka och prata")
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.4)) { antennaOn.toggle() }
        }
    }

    private var figure: some View {
        ZStack {
            // Kofta med hög krage och korallnål
            UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44)
                .fill(LinearGradient(colors: [Color(red: 0x4a/255, green: 0x3f/255, blue: 0x8a/255), Brand.night],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .frame(width: 112, height: 44)
                .offset(y: 56)
            Collar().fill(Color(red: 0x5c/255, green: 0x50/255, blue: 0xa6/255)).frame(width: 46, height: 16).offset(y: 40)
            Circle().fill(Brand.coral).frame(width: 7, height: 7).offset(x: 22, y: 52)
                .shadow(color: Brand.coral.opacity(0.8), radius: 3)

            // Hals
            RoundedRectangle(cornerRadius: 6).fill(skinBottom).frame(width: 22, height: 18).offset(y: 30)

            // Hår bakom huvudet
            Ellipse().fill(LinearGradient(colors: [hairTop, hairBottom], startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 70).offset(y: -12)

            // Knut och antenn
            Circle().fill(LinearGradient(colors: [hairTop, hairBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34).offset(y: -56)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1).frame(width: 34, height: 34).offset(y: -56))
            Capsule().fill(Brand.graphite).frame(width: 2.5, height: 16).offset(y: -79)
            Circle().fill(mood == .idle ? Brand.sky : Brand.coral).frame(width: 8, height: 8).offset(y: -88)
                .shadow(color: (mood == .idle ? Brand.sky : Brand.coral).opacity(0.9), radius: 5)
                .opacity(mood == .listening ? 1 : (antennaOn ? 1 : 0.35))

            // Huvud
            Ellipse().fill(LinearGradient(colors: [skinTop, skinBottom], startPoint: .top, endPoint: .bottom))
                .frame(width: 66, height: 72).offset(y: -4)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            // Lugg
            Fringe().fill(LinearGradient(colors: [hairTop, hairBottom.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                .frame(width: 72, height: 30).offset(y: -30)

            // Kinder
            HStack(spacing: 36) {
                Circle().fill(Brand.coral.opacity(0.22)).frame(width: 12, height: 12)
                Circle().fill(Brand.coral.opacity(0.22)).frame(width: 12, height: 12)
            }.offset(y: 12)

            // Mun
            mouth.offset(y: 20)

            // Cyberglasögon
            glasses.offset(y: -2)

            // Headset: hörlur + bygel till munnen
            RoundedRectangle(cornerRadius: 4).fill(Brand.graphite).frame(width: 9, height: 18).offset(x: -35, y: -2)
            HeadsetBoom().stroke(Brand.graphite, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 26, height: 26).offset(x: -24, y: 13)
            Circle().fill(mood == .listening ? Brand.coral : Brand.graphite).frame(width: 7, height: 7)
                .offset(x: -11, y: 24)
                .shadow(color: mood == .listening ? Brand.coral : .clear, radius: 4)

            // Örhänge
            Circle().fill(Brand.sky).frame(width: 5, height: 5).offset(x: 34, y: 12)
        }
    }

    // MARK: Delar

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .listening:
            Ellipse().fill(Color(red: 0x8c/255, green: 0x3b/255, blue: 0x4a/255))
                .frame(width: 10, height: 4 + level * 8)
                .animation(.easeOut(duration: 0.1), value: level)
        case .happy:
            Smile().stroke(Color(red: 0x8c/255, green: 0x3b/255, blue: 0x4a/255), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 18, height: 6)
        case .worried:
            Capsule().fill(Color(red: 0x8c/255, green: 0x3b/255, blue: 0x4a/255)).frame(width: 9, height: 2.4)
        default:
            Smile().stroke(Color(red: 0x8c/255, green: 0x3b/255, blue: 0x4a/255), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 12, height: 4)
        }
    }

    private var glasses: some View {
        HStack(spacing: 5) { lens; lens }
            .overlay(Capsule().fill(Brand.graphite).frame(width: 7, height: 2.5))
    }

    private var lensColor: Color {
        switch mood {
        case .listening: return Brand.coral
        case .worried: return Color(red: 0xff/255, green: 0xc0/255, blue: 0x6b/255)
        default: return Brand.sky
        }
    }

    @ViewBuilder private var lens: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [lensColor.opacity(0.95), lensColor.opacity(0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(mood == .listening ? 0.7 + Double(level) * 0.3 : 0.9)
            switch mood {
            case .writing:
                ScanLine().clipShape(Circle())
            case .happy:
                Smile().stroke(Brand.night, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 11, height: 5).rotationEffect(.degrees(180))
            case .worried:
                Circle().fill(Brand.night).frame(width: 6, height: 6).offset(y: 2)
            default:
                Circle().fill(Brand.night).frame(width: 7, height: 7)
                    .overlay(Circle().fill(.white).frame(width: 2.5, height: 2.5).offset(x: 1.5, y: -1.5))
            }
            Circle().fill(LinearGradient(colors: [Color.white.opacity(0.55), .clear], startPoint: .topLeading, endPoint: .center))
                .padding(3)
        }
        .frame(width: 24, height: 24)
        .overlay(Circle().strokeBorder(Brand.graphite, lineWidth: 2.6))
        .shadow(color: mood == .idle ? .clear : lensColor.opacity(0.85), radius: 6)
    }
}

/// Ljus linje som sveper över glasen medan hon skriver.
private struct ScanLine: View {
    @State private var down = false
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.85)).frame(height: 2.5)
            .offset(y: down ? 9 : -9)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { down = true } }
    }
}

private struct Fringe: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.9))
            p.addQuadCurve(to: CGPoint(x: r.midX + 4, y: r.midY + 2), control: CGPoint(x: r.maxX - 10, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.minX + 14, y: r.midY - 2))
            p.closeSubpath()
        }
    }
}
private struct Collar: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - 8, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY - 7))
            p.addLine(to: CGPoint(x: r.minX + 8, y: r.minY))
            p.closeSubpath()
        }
    }
}
private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 2))
        }
    }
}
private struct HeadsetBoom: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.minX, y: r.maxY))
        }
    }
}
