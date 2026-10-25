import SwiftUI

/// Imprimantă pentru listare și dischetă pentru salvarea PDF.
struct PdfActionLabel: View {
    let title: String
    var prints = false
    var saves = false

    var body: some View {
        Label {
            Text(title)
        } icon: {
            HStack(spacing: 4) {
                if prints {
                    Image(systemName: "printer")
                }
                if saves {
                    FloppyDiskIcon()
                }
            }
        }
    }
}

struct FloppyDiskIcon: View {
    var body: some View {
        FloppyDiskShape()
            .fill(style: FillStyle(eoFill: true))
            .frame(width: 17, height: 17)
            .accessibilityHidden(true)
    }
}

private struct FloppyDiskShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        let x = box.minX
        let y = box.minY
        let w = box.width
        let h = box.height
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + w * 0.68, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.28))
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h))
        path.closeSubpath()
        path.addRect(CGRect(x: x + w * 0.12, y: y + h * 0.08, width: w * 0.50, height: h * 0.20))
        path.addRoundedRect(
            in: CGRect(x: x + w * 0.16, y: y + h * 0.46, width: w * 0.68, height: h * 0.40),
            cornerSize: CGSize(width: w * 0.06, height: w * 0.06)
        )
        return path
    }
}
