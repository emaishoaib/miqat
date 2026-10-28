import SwiftUI
import WidgetKit

struct AppearancePicker: View {
    @AppStorage(Appearance.key, store: Appearance.store) private var appearance = Appearance.sun

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(Appearance.allCases, id: \.self) { option in
                Text(option.name)
                    .tag(option)
            }
        }
        #if os(macOS)
        .pickerStyle(.radioGroup)
        #endif
        .onChange(of: appearance) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

struct VersionRow: View {
    var body: some View {
        LabeledContent("Version", value: "\(Self.info("CFBundleShortVersionString")) (\(Self.info("CFBundleVersion")))")
    }

    private static func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
