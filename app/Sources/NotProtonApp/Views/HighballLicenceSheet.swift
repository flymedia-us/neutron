// Apple's D3DMetal licence, shown before Neutron downloads Highball's engine or turns D3DMetal on

import SwiftUI

struct HighballLicenceSheet: View {

    enum Mode: Identifiable {
        case download(bytes: Int64)
        case enable(HighballEngine)

        var id: String {
            switch self {
            case .download: "download"
            case .enable(let engine): "enable-\(engine.id)"
            }
        }
    }

    enum Choice { case accept, decline }

    let mode: Mode
    let licence: String
    let choose: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(intro).fixedSize(horizontal: false, vertical: true)
            Text("Apple's licence for D3DMetal").font(.subheadline.weight(.semibold))
            ScrollView {
                Text(licence)
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 240)
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if case .download = mode {
                    Button("Continue without D3DMetal") { finish(.decline) }
                }
                Button(acceptLabel) { finish(.accept) }
                    .disabled(licence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 580)
    }

    private var title: String {
        switch mode {
        case .download: String(localized: "Set up game graphics")
        case .enable: String(localized: "Enable D3DMetal")
        }
    }

    private var intro: String {
        switch mode {
        case .download(let bytes):
            String(localized: "For the widest game support, enable Apple's D3DMetal graphics translator by accepting its licence below. Without it, some games, including DirectX 12 games, will not start. Setup reuses an installed engine or downloads it (up to \(bytes.formatted(.byteCount(style: .file)))).")
        case .enable(let engine):
            String(localized: "D3DMetal is already part of \(engine.displayName). Accepting Apple's licence below lets games use it.")
        }
    }

    private var acceptLabel: String {
        switch mode {
        case .download: String(localized: "Accept and Set Up")
        case .enable: String(localized: "Accept")
        }
    }

    private func finish(_ choice: Choice) {
        dismiss()
        choose(choice)
    }
}
