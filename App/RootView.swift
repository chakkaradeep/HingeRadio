import SwiftUI
import UIKit

/// Lays out each pose: in flex the dial on the half above the fold and the plate on the half
/// below; in book the standby face in two panels either side of the fold; in tent the standby
/// face on the outer screen; in flat and shut the pose card, centred on the outer screen and on
/// the inner one kept to the upper half in portrait or the left panel in landscape.
struct RootView: View {
    let model: RadioModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            Group {
                switch model.radio.pose {
                case .shut, .flat:
                    if model.screen == .outer {
                        PoseCard(model: model, em: Face.em(forWidth: size.width))
                            .padding(insets)
                            .frame(width: size.width, height: size.height)
                    } else if model.landscape {
                        panels(size: size, insets: insets) {
                            PoseCard(model: model, em: Face.em(forWidth: size.width / 2))
                        } right: {
                            Spacer(minLength: 0)
                        }
                    } else {
                        halves(size: size, insets: insets) {
                            PoseCard(model: model, em: Face.em(forWidth: size.width))
                        } bottom: {
                            Spacer(minLength: 0)
                        }
                    }
                case .book:
                    StandbyView(model: model, twoPanels: true)
                case .tent:
                    StandbyView(model: model, twoPanels: false)
                case .flex:
                    let em = Face.em(forWidth: size.width)
                    halves(size: size, insets: insets) {
                        DialView(model: model, em: em)
                    } bottom: {
                        PlateView(model: model, em: em)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            model.window(width: size.width, height: size.height)
        }
        .background(Face.face)
        .preferredColorScheme(.light)
        .statusBarHidden()
        .hingeReadings(into: model)
        .onChange(of: model.radio.isLive, initial: true) { _, live in
            UIApplication.shared.isIdleTimerDisabled = live
        }
    }

    /// The inner screen's layout: one view on the half above the fold and one on the half below.
    /// The halves split the whole screen, not the safe area; each keeps to the safe area on its
    /// own outer edge and leaves a clear band at the fold.
    private func halves(size: CGSize, insets: EdgeInsets,
                        @ViewBuilder top: () -> some View,
                        @ViewBuilder bottom: () -> some View) -> some View {
        VStack(spacing: 0) {
            top()
                .padding(EdgeInsets(top: insets.top, leading: insets.leading,
                                    bottom: Face.foldClearance, trailing: insets.trailing))
                .frame(width: size.width, height: size.height / 2)
                .clipped()
            VStack(spacing: 0) { bottom() }
                .padding(EdgeInsets(top: Face.foldClearance, leading: insets.leading,
                                    bottom: insets.bottom, trailing: insets.trailing))
                .frame(width: size.width, height: size.height / 2)
                .clipped()
        }
    }

    /// The inner screen in landscape: one view on the panel left of the fold and one on the
    /// panel right of it, split like `halves` but down the middle.
    private func panels(size: CGSize, insets: EdgeInsets,
                        @ViewBuilder left: () -> some View,
                        @ViewBuilder right: () -> some View) -> some View {
        HStack(spacing: 0) {
            left()
                .padding(EdgeInsets(top: insets.top, leading: insets.leading,
                                    bottom: insets.bottom, trailing: Face.foldClearance))
                .frame(width: size.width / 2, height: size.height)
                .clipped()
            HStack(spacing: 0) { right() }
                .padding(EdgeInsets(top: insets.top, leading: Face.foldClearance,
                                    bottom: insets.bottom, trailing: insets.trailing))
                .frame(width: size.width / 2, height: size.height)
                .clipped()
        }
    }
}
