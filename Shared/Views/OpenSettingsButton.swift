import SwiftUI

struct OpenSettingsButton: View {
    @Environment(\.presentationMode) private var presentationMode

    #if !os(macOS)
        private var navigation: NavigationModel { .shared }
    #endif

    var body: some View {
        let button = Button {
            presentationMode.wrappedValue.dismiss()

            #if os(macOS)
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            #else
                navigation.presentingSettings = true
            #endif
        } label: {
            Label("Open Settings", systemImage: "gearshape.2")
        }
        .buttonStyle(.plain)

        button.buttonStyle(.borderedProminent)
    }
}

struct OpenSettingsButton_Previews: PreviewProvider {
    static var previews: some View {
        OpenSettingsButton()
    }
}
