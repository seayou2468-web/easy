import SwiftUI

@main
struct EasyRPGiOSApp: App {
    @State private var path: [AppScreen] = []
    @StateObject private var library = GameLibrary()
    @StateObject private var layoutStore = VirtualControllerLayoutStore.shared
    @StateObject private var mappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    @ViewBuilder
    private var rootScreen: some View {
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

    @ViewBuilder
    private func destinationView(for screen: AppScreen) -> some View {
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

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                rootScreen
                    .onAppear {
                        AppLogger.log("Root view appeared")
                        mappingStore.applyToPlayer()
                        let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
                        for button in layoutStore.buttons(isLandscape: isLandscape) {
                            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: button.x, y: button.y)
                        }
                    }
                    .navigationDestination(for: AppScreen.self) { screen in
                        destinationView(for: screen)
                    }
            }
        }
    }
}
