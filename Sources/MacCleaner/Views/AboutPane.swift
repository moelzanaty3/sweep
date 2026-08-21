import AppKit
import SwiftUI

struct AboutPane: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                SweepMark(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Brand.name)
                        .uiFont(19, .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(Brand.tagline)
                        .uiFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Version \(Brand.version)")
                        .uiFont(11, design: .monospaced)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            Text(Brand.origin)
                .uiFont(12)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Built and engineered by")
                    .uiFont(11, .heavy)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
                Text(Brand.authorName)
                    .uiFont(14, .bold)
                    .foregroundStyle(Theme.signature)
                Text(Brand.authorRole)
                    .uiFont(12)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 8) {
                link("GitHub", icon: "chevron.left.forwardslash.chevron.right", url: Brand.githubURL)
                link("LinkedIn", icon: "person.crop.square", url: Brand.linkedInURL)
                link("Website", icon: "globe", url: Brand.websiteURL)
                link("Report an issue", icon: "exclamationmark.bubble", url: Brand.issuesURL)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    @ViewBuilder
    private func link(_ title: String, icon: String, url: String) -> some View {
        if !url.isEmpty {
            Button {
                if let target = URL(string: url) { NSWorkspace.shared.open(target) }
            } label: {
                Label(title, systemImage: icon).fixedSize()
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }
}
