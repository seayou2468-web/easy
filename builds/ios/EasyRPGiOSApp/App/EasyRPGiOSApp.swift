import SwiftUI

@main
struct EasyRPGiOSApp: App {
    @State private var path: [AppScreen] = []
    @StateObject private var library = GameLibrary()
    @StateObject private var layoutStore = VirtualControllerLayoutStore()
    @StateObject private var mappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                InitView(onContinue: { path.append(.browser) })
                    .onAppear {
                        // Initialize everything
                        mappingStore.applyToPlayer()
                        for button in layoutStore.buttons {
                            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: button.x, y: button.y)
                        }
                    }
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .initScreen:
                            InitView(onContinue: { path.append(.browser) })

                        case .browser:
                            GameBrowserView(
                                onOpenSettings: { path.append(.settings) },
                                onPlay: { game in path.append(.player(game)) },
                                library: library
                            )

                        case .player(let game):
                            PlayerView(game: game)

                        case .settings:
                            ParitySettingsRootView()
                        }
                    }
            }
        }
    }
}
