import SwiftUI

struct SetupOverview: View {
    let snapshot: StatusSnapshot
    let status: SystemStatus
    let startSetup: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(snapshot.readyToPlay ? "You're ready to play" : "Your Steam games. Now on Mac.",
                      systemImage: snapshot.readyToPlay ? "checkmark.circle.fill" : "gamecontroller.fill")
                    .font(.title2.bold())
                    .foregroundStyle(snapshot.readyToPlay ? Color.green : Color.accentColor)
                Text(snapshot.readyToPlay
                     ? "Open Steam, pick a Windows game, and click Play. Neutron works in the background."
                     : "Set up once, then play Windows games from the Steam app you already use.")
                if !snapshot.readyToPlay {
                    Text("Setup closes Steam, installs the free game engine, and enables Windows games. macOS may ask you to allow App Management for Neutron.")
                        .foregroundStyle(.secondary)
                }
                if !snapshot.rosettaInstalled {
                    Text("Rosetta is required. Open Steam and follow macOS's Install Rosetta prompt, then return here and refresh.")
                        .foregroundStyle(.orange)
                }
                if case .foreign = snapshot.steam {
                    Text("Another Steam integration is installed. Remove it using that app before setting up Neutron. See Advanced for details.")
                        .foregroundStyle(.orange)
                }
                if snapshot.installContent.blocksInstallation {
                    Text("Installed files need attention. Open Advanced for details before continuing.")
                        .foregroundStyle(.orange)
                }
                HStack {
                    if snapshot.readyToPlay {
                        Button("Open Steam", action: status.openSteam)
                            .buttonStyle(.borderedProminent)
                            .disabled(!status.isIdle)
                    } else if case .steamMissing = snapshot.steam {
                        Link("Get Steam", destination: URL(string: "https://store.steampowered.com/about/")!)
                        Button("Find Steam…") { Task { await status.chooseSteam() } }
                            .disabled(!status.isIdle)
                    } else {
                        Button(status.isSettingUp ? "Setting Up…" : "Set Up Neutron", action: startSetup)
                            .buttonStyle(.borderedProminent)
                            .disabled(!status.canInstall || snapshot.setupBlocked)
                    }
                }
            }
            .padding(.vertical, 8)
            checklist("Steam integration", ready: snapshot.integrationReady,
                      detail: snapshot.integrationReady ? "Installed and verified" : "Setup connects Neutron to Steam")
            checklist("Game engine", ready: snapshot.engineReady,
                      detail: snapshot.engineReady ? "Ready" : "Setup downloads or reuses the free Highball engine")
            if snapshot.readyToPlay {
                Text("The first launch can take a few minutes while Neutron prepares the game. For games with a Mac version, choose Neutron's Highball tool in Steam → Properties → Compatibility to play the Windows version.")
                    .foregroundStyle(.secondary)
                if snapshot.defaultToolRequest == "" {
                    Text("The automatic Windows-game default is off. Choose Highball for each game in Properties → Compatibility, or enable the default in Advanced.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func checklist(_ title: String, ready: Bool, detail: String) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        } icon: {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ready ? Color.green : Color.secondary)
        }
    }
}
