// Fork credit shown in the About panel

import AppKit

enum AboutCredits {

    static var text: String {
        String(localized: """
        Neutron by Fly Media is a fork of NotProton by NotProtonNot (https://github.com/NotProtonNot/NotProton), \
        released under GPLv3. It is not affiliated with or endorsed by NotProton, Valve, Apple or Highball. \
        Highball integration is adapted from Proton-ish by MagnusPladsen (https://github.com/MagnusPladsen/Proton-ish). It uses Highball's HighballKit (GPLv3) and highball-db game data (CC0) by Gauthier Piarrette \
        (https://github.com/gauthierpiarrette/highball).
        """)
    }

    @MainActor
    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: text)
        ])
        NSApplication.shared.activate()
    }
}
