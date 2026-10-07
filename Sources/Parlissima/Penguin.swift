import SwiftUI

// MARK: - Pingvinen: gullig som i en animerad film, men med framtidsdetaljer.
// Tre varianter: visir, hörlurar och robot.

struct PenguinView: View {
    enum Variant: CaseIterable { case visor, headphones, robot }
    @ObservedObject var model: HUDModel
    var variant: Variant = .headphones
    var iconStyle = false
    @State private var hover = false
    @State private var blink = false

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
    private var accent: Color {
        if iconStyle { return Brand.sky }
        switch mood {
        case .listening: return Brand.coral
        case .worried: return Color(red: 1, green: 0.75, blue: 0.42)
        case .writing, .happy: return Brand.sky
        case .idle: return Color.white.opacity(0.32)      // vila: nästan släckt
        }
    }
    private let yellow = Color(red: 1, green: 0.75, blue: 0.42)

    static let size = CGSize(width: 136, height: 156)

    // Färger
    private let feather = [Color(red: 0x3a/255, green: 0x32/255, blue: 0x6e/255), Color(red: 0x15/255, green: 0x11/255, blue: 0x2c/255)]
    private let chrome = [Color(red: 0xee/255, green: 0xf0/255, blue: 0xff/255), Color(red: 0x9a/255, green: 0x9f/255, blue: 0xd6/255)]
    private let beakColor = [Color(red: 1, green: 0.78, blue: 0.45), Color(red: 0.96, green: 0.55, blue: 0.36)]
    private let ink = Color(red: 0x1b/255, green: 0x14/255, blue: 0x34/255)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Brand.coral.opacity(0.5), .clear], center: .center, startRadius: 14, endRadius: 70))
                .scaleEffect(mood == .listening ? 1 + level * 0.4 : 0.6)
                .opacity(mood == .listening ? 1 : 0)
            if mood == .listening && variant == .headphones { soundWaves }
            figure
                .offset(y: mood == .listening ? -level * 4 : 0)            // gungar med rösten
                .scaleEffect(hover ? 1.05 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hover)
                .animation(.easeOut(duration: 0.1), value: level)
            if !iconStyle { badge.offset(x: 46, y: -58) }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .help(mood == .listening ? "Lyssnar – klicka när du är klar" : "Klicka och prata · högerklicka för menyn")
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard mood == .idle else { return }
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
            }
        }
    }

    // MARK: Tydliga lägesmärken

    /// Ljudvågor som strömmar ut från mikrofonen medan pingvinen lyssnar.
    private var soundWaves: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t * 1.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    WaveArc().stroke(Brand.coral.opacity((1 - phase) * (0.5 + Double(level) * 0.5)),
                                     style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 14 + phase * 26, height: 22 + phase * 30)
                        .offset(x: -34 - phase * 16, y: 9)
                }
            }
        }
    }

    @ViewBuilder private var badge: some View {
        switch mood {
        case .listening:
            // Röd inspelningsprick som pulserar
            TimelineView(.animation) { ctx in
                let pulse = 0.75 + 0.25 * sin(ctx.date.timeIntervalSinceReferenceDate * 5)
                ZStack {
                    Circle().fill(Brand.coral.opacity(0.35)).frame(width: 24 * pulse, height: 24 * pulse)
                    Circle().fill(Color(red: 1, green: 0.32, blue: 0.4)).frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                }
            }
        case .writing:
            // Tankebubbla med prickar som skrivs fram
            TimelineView(.periodic(from: .now, by: 0.35)) { ctx in
                let n = Int(ctx.date.timeIntervalSinceReferenceDate / 0.35) % 4
                ZStack {
                    Capsule().fill(Color.white).frame(width: 38, height: 22)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    Circle().fill(Color.white).frame(width: 7, height: 7).offset(x: -14, y: 15)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle().fill(Brand.graphite.opacity(i < n ? 1 : 0.25)).frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .offset(x: -4, y: 2)
        case .happy:
            ZStack {
                Circle().fill(Brand.sky).frame(width: 26, height: 26)
                    .shadow(color: Brand.sky.opacity(0.8), radius: 6)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Brand.night)
            }
        case .worried:
            ZStack {
                Circle().fill(yellow).frame(width: 26, height: 26).shadow(color: yellow.opacity(0.8), radius: 6)
                Text("!").font(.system(size: 16, weight: .heavy)).foregroundStyle(Brand.night)
            }
        case .idle:
            EmptyView()
        }
    }

    private var figure: some View {
        ZStack {
            // Fötter
            HStack(spacing: 14) {
                Ellipse().fill(LinearGradient(colors: beakColor, startPoint: .top, endPoint: .bottom)).frame(width: 22, height: 10)
                Ellipse().fill(LinearGradient(colors: beakColor, startPoint: .top, endPoint: .bottom)).frame(width: 22, height: 10)
            }.offset(y: 66)

            // Vingar
            Ellipse().fill(LinearGradient(colors: variant == .robot ? chrome : feather, startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 46).rotationEffect(.degrees(18)).offset(x: -44, y: 22)
            Ellipse().fill(LinearGradient(colors: variant == .robot ? chrome : feather, startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 46).rotationEffect(.degrees(-18)).offset(x: 44, y: 22)

            // Kropp: rund, med mjukt ljus uppifrån för 3D-känsla
            Ellipse()
                .fill(LinearGradient(colors: variant == .robot ? chrome : feather, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 88, height: 112).offset(y: 10)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
            Ellipse()
                .fill(RadialGradient(colors: [Color.white.opacity(variant == .robot ? 0.7 : 0.28), .clear],
                                     center: UnitPoint(x: 0.3, y: 0.18), startRadius: 2, endRadius: 46))
                .frame(width: 88, height: 112).offset(y: 10)

            // Mage
            if variant == .robot {
                RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Brand.night, Brand.graphite], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 40).offset(y: 36)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent.opacity(0.6), lineWidth: 1.5).frame(width: 48, height: 40).offset(y: 36))
                equalizer.offset(y: 36)
            } else {
                Ellipse().fill(LinearGradient(colors: [Color.white, Color(red: 0.88, green: 0.88, blue: 0.97)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 74).offset(y: 26)
            }

            // Ansiktsmask
            if variant != .robot {
                HStack(spacing: -10) {
                    Ellipse().fill(Color.white).frame(width: 36, height: 40)
                    Ellipse().fill(Color.white).frame(width: 36, height: 40)
                }.offset(y: -16)
            } else {
                Capsule().fill(LinearGradient(colors: [Brand.night, Brand.graphite], startPoint: .top, endPoint: .bottom))
                    .frame(width: 62, height: 32).offset(y: -16)
            }

            // Ögon
            HStack(spacing: variant == .robot ? 12 : 8) { eye; eye }.offset(y: -16)

            // Kinder
            if variant != .robot {
                HStack(spacing: 40) {
                    Circle().fill(Brand.coral.opacity(0.28)).frame(width: 10, height: 10)
                    Circle().fill(Brand.coral.opacity(0.28)).frame(width: 10, height: 10)
                }.offset(y: -2)
            }

            // Näbb
            beak.offset(y: 2)

            // Tillbehör
            switch variant {
            case .visor: visor
            case .headphones: headphones
            case .robot: antenna
            }
        }
    }

    // MARK: Delar

    @ViewBuilder private var eye: some View {
        if variant == .robot {
            // LED-ögon
            Group {
                switch mood {
                case .happy:
                    Arc().stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 14, height: 6)
                default:
                    Capsule().fill(accent).frame(width: 12, height: mood == .writing ? 4 : 16)
                }
            }
            .shadow(color: accent, radius: 5)
        } else {
            ZStack {
                if mood == .worried {
                    Capsule().fill(ink).frame(width: 12, height: 2.4).offset(y: -17)
                }
                switch mood {
                case .happy:
                    Arc().stroke(ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round)).frame(width: 13, height: 6)
                default:
                    Ellipse().fill(LinearGradient(colors: [Color(red: 0.3, green: 0.24, blue: 0.55), ink], startPoint: .top, endPoint: .bottom))
                        .frame(width: 17, height: 20)
                        .offset(x: mood == .writing ? 3 : 0, y: mood == .writing ? -4 : 0)
                    Circle().fill(.white).frame(width: 6, height: 6).offset(x: 3, y: -4)
                    Circle().fill(.white.opacity(0.7)).frame(width: 2.5, height: 2.5).offset(x: -3, y: 4)
                }
            }
            .scaleEffect(x: 1, y: blink ? 0.12 : 1)
        }
    }

    @ViewBuilder private var beak: some View {
        if mood == .listening && variant != .robot {
            VStack(spacing: 1 + level * 4) {
                BeakHalf().fill(LinearGradient(colors: beakColor, startPoint: .top, endPoint: .bottom)).frame(width: 16, height: 7)
                BeakHalf().fill(beakColor[1]).frame(width: 12, height: 5).rotationEffect(.degrees(180))
            }
        } else if variant == .robot {
            Capsule().fill(accent.opacity(0.85)).frame(width: 14, height: 4).shadow(color: accent, radius: 3).offset(y: 6)
        } else {
            BeakHalf().fill(LinearGradient(colors: beakColor, startPoint: .top, endPoint: .bottom)).frame(width: 16, height: 10)
        }
    }

    private var visor: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [accent.opacity(0.55), accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 70, height: 24)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.2))
                .shadow(color: accent.opacity(0.8), radius: 6)
            Capsule().fill(Color.white.opacity(0.5)).frame(width: 30, height: 3).offset(x: -12, y: -6)
        }
        .offset(y: -16)
        .overlay(antenna)
    }

    private var headphones: some View {
        ZStack {
            Band().stroke(Brand.graphite, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 92, height: 44).offset(y: -42)
            cup.offset(x: -44, y: -18)
            cup.offset(x: 44, y: -18)
            Boom().stroke(Brand.graphite, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 30, height: 22).offset(x: -30, y: -2)
            Capsule().fill(mood == .listening ? Brand.coral : Brand.graphite).frame(width: 9, height: 6)
                .offset(x: -14, y: 9).shadow(color: mood == .listening ? Brand.coral : .clear, radius: 4)
        }
    }

    private var cup: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(red: 0x4a/255, green: 0x3f/255, blue: 0x8a/255), Brand.night], startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 32)
            RoundedRectangle(cornerRadius: 8).strokeBorder(accent, lineWidth: mood == .listening ? 3 : 2).frame(width: 13, height: 23)
                .shadow(color: (mood == .idle && !iconStyle) ? .clear : accent.opacity(0.95), radius: mood == .listening ? 7 : 4)
        }
    }

    private var antenna: some View {
        ZStack {
            Capsule().fill(Brand.graphite).frame(width: 2.5, height: 14).offset(y: -52)
            Circle().fill(accent).frame(width: 9, height: 9).offset(y: -62).shadow(color: accent, radius: 5)
        }
    }

    private var equalizer: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { i in
                let base: [CGFloat] = [0.35, 0.7, 1, 0.8, 0.5, 0.3]
                Capsule().fill(accent)
                    .frame(width: 4, height: 6 + (mood == .listening ? (8 + level * 18) * base[i] : 6 * base[i]))
                    .shadow(color: accent.opacity(0.8), radius: 2)
            }
        }
    }
}

private struct BeakHalf: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY + 2))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 2), control: CGPoint(x: r.midX, y: r.minY - 2))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX - 1, y: r.midY + 2))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + 2), control: CGPoint(x: r.minX + 1, y: r.midY + 2))
            p.closeSubpath()
        }
    }
}
private struct Band: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.minX, y: r.minY - 12), control2: CGPoint(x: r.maxX, y: r.minY - 12))
        }
    }
}
private struct Boom: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.minX + 2, y: r.maxY))
        }
    }
}
private struct Arc: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        }
    }
}

private struct WaveArc: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.minX - r.width * 0.2, y: r.midY))
        }
    }
}
