import SwiftUI
import UIKit

/// The closed card while closed (centred on the outer screen, above the fold on the inner one);
/// otherwise the dial on the half above the fold and the plate on the half below.
struct RootView: View {
    let model: RadioModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let em = Face.em(forWidth: size.width)
            Group {
                if model.radio.isClosed && !model.closedOnInnerScreen {
                    // Outer screen: the card centred, the slider at the bottom.
                    ClosedCard(model: model, em: em)
                        .padding(insets)
                        .overlay(alignment: .bottom) {
                            debugSlider(em: em).padding(.bottom, insets.bottom)
                        }
                        .frame(width: size.width, height: size.height)
                } else if model.radio.isClosed {
                    // Closed by angle with the inner screen still lit: the card above the fold.
                    halves(size: size, insets: insets) {
                        ClosedCard(model: model, em: em)
                    } bottom: {
                        Spacer(minLength: 0)
                        debugSlider(em: em)
                    }
                } else {
                    halves(size: size, insets: insets) {
                        DialView(model: model, em: em, onTitleLongPress: titleLongPress)
                    } bottom: {
                        PlateView(model: model, em: em)
                        debugSlider(em: em)
                    }
                }
            }
        }
        .ignoresSafeArea()
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

    // MARK: - Debug slider (simulator builds only)

    @ViewBuilder private func debugSlider(em: CGFloat) -> some View {
        #if targetEnvironment(simulator)
        if model.debugAngle != nil {
            DebugHingeSlider(model: model, em: em)
        }
        #endif
    }

    private var titleLongPress: (() -> Void)? {
        #if targetEnvironment(simulator)
        return { model.debugAngle = model.debugAngle == nil ? model.angle : nil }
        #else
        return nil
        #endif
    }
}
