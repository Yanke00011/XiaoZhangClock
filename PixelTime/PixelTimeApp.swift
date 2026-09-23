import SwiftUI
import SwiftData

@main
struct PixelTimeApp: App {
    private let container: ModelContainer

    init() {
        PixelFontRegistrar.registerBundledFont()
        do {
            container = try ModelContainer(for: Countdown.self)
        } catch {
            // Keep the app usable if the on-disk store is damaged or unavailable.
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: Countdown.self, configurations: fallback)
            } catch {
                fatalError("Pixel Time could not initialize its countdown store: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView().modelContainer(container).preferredColorScheme(.dark)
                .frame(minWidth: 390, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 620, height: 780)
    }
}
