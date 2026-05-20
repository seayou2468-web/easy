import Foundation
import UIKit

enum ProjectType: Int {
    case unknown = 0
    case supported = 1
    case unsupported = 2
}

struct Game: Identifiable, Hashable {
    let id: String
    let title: String
    let displayTitle: String
    let path: String
    let savePath: String
    let gameFolderName: String
    let author: String
    var favorite: Bool
    var projectType: ProjectType
    var customTitle: String?
    var titleImage: UIImage?
    var encoding: String

    init(
        title: String,
        displayTitle: String = "",
        path: String,
        savePath: String = "",
        gameFolderName: String = "",
        author: String = "Unknown",
        favorite: Bool = false,
        projectType: ProjectType = .supported,
        customTitle: String? = nil,
        titleImage: UIImage? = nil,
        encoding: String = "auto"
    ) {
        self.id = path
        self.title = title
        self.displayTitle = displayTitle.isEmpty ? title : displayTitle
        self.path = path
        self.savePath = savePath
        self.gameFolderName = gameFolderName
        self.author = author
        self.favorite = favorite
        self.projectType = projectType
        self.customTitle = customTitle
        self.titleImage = titleImage
        self.encoding = encoding
    }

    func getDisplayTitle(labelMode: Int) -> String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        if labelMode == 0 && !title.isEmpty {
            return title
        }
        return gameFolderName
    }
}

enum AppScreen: Hashable {
    case initScreen
    case browser
    case player(Game)
    case settings
}

@MainActor
final class GameLibrary: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published var isScanning = false

    private let fileManager = FileManager.default
    private let configManager = ConfigManager.shared
    private let favoritesKey = "ios.favoriteGames"

    func reloadGames(forceScan: Bool = false) {
        isScanning = true

        let easyRPGFolder = configManager.easyRPGFolderURL
        let labelMode = configManager.gameBrowserLabelMode

        DispatchQueue.global(qos: .userInitiated).async { [weak self, easyRPGFolder, labelMode] in
            guard let self = self else { return }

            var found: [Game] = []
            let favoritePaths = self.loadFavoritePaths()

            if let folder = easyRPGFolder {
                let discovered = self.discoverGames(in: folder)
                found.append(contentsOf: discovered.map { base in
                    self.loadGameMetadata(at: base, isFavorite: favoritePaths.contains(base.path))
                })
            }

            let unique = Dictionary(grouping: found, by: { $0.path }).compactMap { $0.value.first }
            let sorted = unique.sorted { game1, game2 in
                // Favorites first
                if game1.favorite != game2.favorite {
                    return game1.favorite
                }
                // Unsupported games last
                if game1.projectType != game2.projectType {
                    if game1.projectType == .supported {
                        return true
                    }
                    return false
                }
                return game1.getDisplayTitle(labelMode: labelMode)
                    .localizedCaseInsensitiveCompare(game2.getDisplayTitle(labelMode: labelMode)) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.games = sorted
                self.isScanning = false
            }
        }
    }

    func toggleFavorite(_ game: Game) {
        var updated = loadFavoritePaths()
        if updated.contains(game.path) {
            updated.remove(game.path)
        } else {
            updated.insert(game.path)
        }
        UserDefaults.standard.set(Array(updated), forKey: favoritesKey)
        reloadGames()
    }

    func setCustomTitle(_ title: String, for game: Game) {
        configManager.setCustomGameTitle(title, for: game.id)
        reloadGames()
    }

    private func loadGameMetadata(at url: URL, isFavorite: Bool) -> Game {
        let folderName = url.lastPathComponent
        var title = folderName
        var savePath = ""
        var projectType = ProjectType.supported
        var encoding = "auto"
        var titleImage: UIImage? = nil

        // Load from RPG_RT.ini
        if let iniPath = findFile(in: url, named: "RPG_RT.ini"),
           let iniContent = try? String(contentsOfFile: iniPath, encoding: .utf8) {
            title = parseIniValue(iniContent, key: "Title") ?? title
            savePath = parseIniValue(iniContent, key: "SavePath") ?? ""
            encoding = parseIniValue(iniContent, key: "Encoding") ?? "auto"
        }

        // Try to load title image
        if let titlePath = findFile(in: url, named: "Title"),
           let image = UIImage(contentsOfFile: titlePath) {
            titleImage = image
        }

        let customTitle = ConfigManager.shared.getCustomGameTitle(for: url.path)

        return Game(
            title: title,
            path: url.path,
            savePath: savePath,
            gameFolderName: folderName,
            favorite: isFavorite,
            projectType: projectType,
            customTitle: customTitle,
            titleImage: titleImage,
            encoding: encoding
        )
    }

    private func loadFavoritePaths() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
    }

    private func discoverGames(in root: URL) -> [URL] {
        var matches: [URL] = []
        
        if let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) {
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                if containsRpgMarkerFiles(in: url) {
                    matches.append(url)
                    enumerator.skipDescendants()
                }
            }
        }
        
        return matches
    }

    private func containsRpgMarkerFiles(in directory: URL) -> Bool {
        let candidates = ["RPG_RT.ldb", "RPG_RT.lmt", "RPG_RT.ini", "easyrpg-player-manifest.json"]
        return candidates.contains(where: { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) })
    }

    private func findFile(in directory: URL, named: String) -> String? {
        let path = directory.appendingPathComponent(named).path
        if fileManager.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private func parseIniValue(_ content: String, key: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.starts(with: key + "=") {
                let value = String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
