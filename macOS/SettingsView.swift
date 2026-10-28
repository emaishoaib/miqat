import SwiftUI

struct SettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Settings")
        .sheet(isPresented: $isPresented) {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    AppearancePicker()
                }
                Section {
                    VersionRow()
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 320)
        .font(.body)
        .foregroundStyle(.primary)
        .tint(nil)
    }
}
