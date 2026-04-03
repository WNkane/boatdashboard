import SwiftUI

// MARK: - Dragon Boat Icon
// Scalable SwiftUI vector icon — works from 20pt to 1024pt
// Design: dark-gray bg · orange circle · minimal dragon head · 4 nav mini-icons · text label

struct DragonBoatIcon: View {
    var size: CGFloat = 100
    var showLabel: Bool = true

    private let orange   = Color(red: 1.00, green: 0.60, blue: 0.05)
    private let bgColor  = Color(red: 0.10, green: 0.10, blue: 0.10)
    private let headDark = Color(red: 0.09, green: 0.04, blue: 0.00)

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(bgColor)

            Canvas { ctx, sz in
                let w = sz.width, h = sz.height
                let cx = w * 0.50
                let cy = h * 0.42
                let r  = w * 0.36

                // ── 1. Orange circle ────────────────────────────────────
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.00, green: 0.60, blue: 0.05))
                )

                // ── 2. Dragon head silhouette (dark on orange) ──────────
                var head = Path()
                // chin / neck base
                head.move(to: CGPoint(x: cx - r*0.18, y: cy + r*0.22))
                // underside of jaw → snout bottom
                head.addCurve(
                    to:       CGPoint(x: cx + r*0.62, y: cy + r*0.14),
                    control1: CGPoint(x: cx + r*0.15, y: cy + r*0.46),
                    control2: CGPoint(x: cx + r*0.52, y: cy + r*0.34)
                )
                // snout right face
                head.addCurve(
                    to:       CGPoint(x: cx + r*0.60, y: cy - r*0.26),
                    control1: CGPoint(x: cx + r*0.84, y: cy + r*0.10),
                    control2: CGPoint(x: cx + r*0.84, y: cy - r*0.18)
                )
                // brow ridge
                head.addCurve(
                    to:       CGPoint(x: cx + r*0.15, y: cy - r*0.54),
                    control1: CGPoint(x: cx + r*0.52, y: cy - r*0.42),
                    control2: CGPoint(x: cx + r*0.38, y: cy - r*0.60)
                )
                // horn: left slope → tip → right slope
                head.addLine(to: CGPoint(x: cx + r*0.08, y: cy - r*0.60))
                head.addLine(to: CGPoint(x: cx + r*0.16, y: cy - r*0.97))
                head.addLine(to: CGPoint(x: cx - r*0.04, y: cy - r*0.62))
                // back of skull
                head.addCurve(
                    to:       CGPoint(x: cx - r*0.42, y: cy - r*0.40),
                    control1: CGPoint(x: cx - r*0.18, y: cy - r*0.72),
                    control2: CGPoint(x: cx - r*0.40, y: cy - r*0.64)
                )
                // neck back curve → chin
                head.addCurve(
                    to:       CGPoint(x: cx - r*0.18, y: cy + r*0.22),
                    control1: CGPoint(x: cx - r*0.52, y: cy - r*0.16),
                    control2: CGPoint(x: cx - r*0.48, y: cy + r*0.12)
                )
                head.closeSubpath()
                ctx.fill(head, with: .color(Color(red: 0.09, green: 0.04, blue: 0.00)))

                // eye
                let eyeR  = r * 0.08
                let eyePt = CGPoint(x: cx + r*0.30, y: cy - r*0.10)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: eyePt.x - eyeR, y: eyePt.y - eyeR,
                                          width: eyeR * 2, height: eyeR * 2)),
                    with: .color(Color(red: 1.00, green: 0.60, blue: 0.05))
                )

                // mane — 3 curved strokes behind head
                for i in 0 ..< 3 {
                    let baseY = cy - r*0.30 + CGFloat(i) * r*0.22
                    var mane = Path()
                    mane.move(to: CGPoint(x: cx - r*0.38, y: baseY))
                    mane.addCurve(
                        to:       CGPoint(x: cx - r*0.68, y: baseY + r*0.12),
                        control1: CGPoint(x: cx - r*0.48, y: baseY - r*0.06),
                        control2: CGPoint(x: cx - r*0.60, y: baseY + r*0.04)
                    )
                    ctx.stroke(mane,
                               with: .color(Color(red: 0.09, green: 0.04, blue: 0.00)),
                               lineWidth: w * 0.028)
                }

                // ── 3. Four mini-icons (bottom row of circle) ───────────
                let iconY = cy + r * 0.68
                let iS    = r * 0.18
                let white = Color.white.opacity(0.90)
                let acc   = Color(red: 1.00, green: 0.60, blue: 0.05)
                let xs    = [cx - r*0.56, cx - r*0.19, cx + r*0.19, cx + r*0.56]

                // [0] Hamburger — 3 horizontal lines
                for i in 0 ..< 3 {
                    var l = Path()
                    let ly = iconY - iS*0.50 + CGFloat(i) * iS*0.50
                    l.move(to:    CGPoint(x: xs[0] - iS*0.60, y: ly))
                    l.addLine(to: CGPoint(x: xs[0] + iS*0.60, y: ly))
                    ctx.stroke(l, with: .color(white), lineWidth: w * 0.016)
                }

                // [1] House — triangle roof + wall rect + door cutout
                var roof = Path()
                roof.move(to:    CGPoint(x: xs[1],             y: iconY - iS*0.85))
                roof.addLine(to: CGPoint(x: xs[1] - iS*0.62,  y: iconY - iS*0.10))
                roof.addLine(to: CGPoint(x: xs[1] + iS*0.62,  y: iconY - iS*0.10))
                roof.closeSubpath()
                ctx.fill(roof, with: .color(white))
                let wall = CGRect(x: xs[1] - iS*0.42, y: iconY - iS*0.10,
                                  width: iS*0.84, height: iS*0.78)
                ctx.fill(Path(wall), with: .color(white))
                let door = CGRect(x: xs[1] - iS*0.18, y: iconY + iS*0.22,
                                  width: iS*0.36, height: iS*0.46)
                ctx.fill(Path(door), with: .color(acc))

                // [2] Notebook — rounded rect + 3 ruled lines
                let nb = CGRect(x: xs[2] - iS*0.52, y: iconY - iS*0.72,
                                width: iS*1.04, height: iS*1.42)
                ctx.fill(Path(roundedRect: nb, cornerRadius: iS*0.12), with: .color(white))
                for i in 0 ..< 3 {
                    var nl = Path()
                    let ly2 = iconY - iS*0.38 + CGFloat(i) * iS*0.34
                    nl.move(to:    CGPoint(x: xs[2] - iS*0.32, y: ly2))
                    nl.addLine(to: CGPoint(x: xs[2] + iS*0.32, y: ly2))
                    ctx.stroke(nl, with: .color(acc.opacity(0.85)), lineWidth: w * 0.013)
                }

                // [3] Bar chart — 4 bars of varying height
                let barHs: [CGFloat] = [0.50, 0.90, 0.65, 1.00]
                for (i, bh) in barHs.enumerated() {
                    let bx  = xs[3] - iS*0.56 + CGFloat(i) * iS*0.38
                    let bH  = iS * bh
                    let bR  = CGRect(x: bx, y: iconY + iS*0.10 - bH, width: iS*0.30, height: bH)
                    ctx.fill(Path(roundedRect: bR, cornerRadius: iS*0.05), with: .color(white))
                }
            }
            .padding(size * 0.02)

            // ── "Dragon Boat Pro" text ───────────────────────────────────
            if showLabel {
                VStack {
                    Spacer()
                    Text("Dragon Boat Pro")
                        .font(.system(size: size * 0.082, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.bottom, size * 0.048)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - App Icon Export (1024 × 1024, no label for store submission)

struct AppIconExportView: View {
    var body: some View {
        DragonBoatIcon(size: 1024, showLabel: false)
            .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Icon — Large") {
    DragonBoatIcon(size: 300)
        .padding()
        .background(Color.gray.opacity(0.15))
}

#Preview("Icon — Small") {
    HStack(spacing: 16) {
        DragonBoatIcon(size: 80)
        DragonBoatIcon(size: 60, showLabel: false)
        DragonBoatIcon(size: 40, showLabel: false)
    }
    .padding()
    .background(Color.black)
}

#Preview("App Icon Export 1024pt") {
    AppIconExportView()
        .frame(width: 1024, height: 1024)
}
