import SwiftUI
import UIKit

struct HingeProbeView: View {
    @State private var angleText = "waiting"
    @State private var statusText = "waiting"
    @State private var updates = 0
    @State private var size = CGSize.zero
    @State private var orientation = "?"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            line("angle", angleText)
            line("status", statusText)
            line("updates", "\(updates)")
            line("size", "\(Int(size.width)) x \(Int(size.height)) pt")
            line("orientation", orientation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Color.black)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0; orientation = Self.interfaceOrientationName() }
        .onHingeChange { _, new in
            updates += 1
            if let hinge = new.hinge {
                angleText = String(format: "%.2f", hinge.angle.degrees)
                statusText = Self.name(hinge.status)
            } else {
                angleText = "no hinge"
                statusText = "none"
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 22, weight: .medium)).foregroundStyle(.yellow)
            Text(value).font(.system(size: 44, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
                .minimumScaleFactor(0.5)
        }
    }

    private static func interfaceOrientationName() -> String {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        default: return "unknown"
        }
    }

    private static func name(_ s: DeviceHinge.Status) -> String {
        if s == .closed { return "closed" }
        if s == .partiallyOpen { return "partiallyOpen" }
        if s == .fullyOpen { return "fullyOpen" }
        return "unknown"
    }
}
