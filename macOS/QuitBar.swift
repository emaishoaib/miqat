import AppKit
import SwiftUI

struct QuitBar: View {
    var body: some View {
        HStack {
            Spacer()
            Button("Quit Miqat") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
                .buttonStyle(.borderless)
                .foregroundStyle(Palette.ink.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
