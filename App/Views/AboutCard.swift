import SwiftUI

/// The "About the dial" sheet: where the stations, the streams, the town's name and the badge's
/// lettering come from, and whose the station names are. Set in the radio's own colours, in text
/// styles so it grows with the text-size setting.
struct AboutCard: View {
    @Environment(\.dismiss) private var dismiss

    /// One credit: what it is for, and who it is owed to.
    private struct Credit: Identifiable {
        let id: String
        let sentence: String
        init(_ id: String, _ sentence: String) { (self.id, self.sentence) = (id, sentence) }
    }

    /// The HERE build also names its own sources; without HERE the app does not use them.
    private static let credits: [Credit] = {
        var credits = [Credit("Stations", "The FCC's public list of licensed stations gives each station and its frequency.")]
        #if HERE
        credits.append(Credit("Streams", "The streams come from NPR and Radio Browser."))
        credits.append(Credit("Town", "Apple gives the name of the town."))
        #else
        credits.append(Credit("Streams", "The streams come from Radio Browser."))
        #endif
        credits.append(Credit("Lettering", "The badge's lettering is adapted from Yellowtail, used under the Apache 2.0 licence."))
        return credits
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("About the dial")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                Button("Done") { dismiss() }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Face.ink)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Face.shade, in: Capsule())
            }
            .padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Self.credits) { credit in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(credit.id.uppercased())
                                .font(.footnote.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(Face.muted)
                                .accessibilityHidden(true)
                            Text(credit.sentence)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("The station names belong to their broadcasters. Hinge Radio is not affiliated with them.")
                        .foregroundStyle(Face.muted)
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Face.ink)
        .padding(EdgeInsets(top: 28, leading: 24, bottom: 8, trailing: 24))
        .presentationBackground(Face.face)
        .preferredColorScheme(.light)
    }
}
