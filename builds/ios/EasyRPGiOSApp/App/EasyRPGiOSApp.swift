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
                Group {
                    if config.hasCompletedOnboarding {
                        GameBrowserView(
                            onOpenSettings: { path.append(.settings) },
                            onPlay: { game in path.append(.player(game)) },
                            library: library
                        )
                    } else {
                        InitView(showContinueToBrowserButton: true)
                    }
                }
                    .onAppear {
                        AppLogger.log("Root view appeared")
                        // Initialize everything
                        mappingStore.applyToPlayer()
                        for button in layoutStore.buttons {
                            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: button.x, y: button.y)
                        }
                    }
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .initScreen:
                            InitView(showContinueToBrowserButton: true)

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
