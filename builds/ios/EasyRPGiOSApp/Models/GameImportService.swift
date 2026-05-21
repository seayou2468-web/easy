import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

@MainActor
final class GameImportService: ObservableObject {
    @Published var lastResultMessage: String?

    func importArchives(urls: [URL], into rootFolder: URL?) {
        guard let rootFolder else {
            lastResultMessage = "EasyRPGフォルダが未設定です。先にフォルダを設定してください。"
            return
        }

        let gamesDir = rootFolder.appendingPathComponent("games", isDirectory: true)
        try? FileManager.default.createDirectory(at: gamesDir, withIntermediateDirectories: true)

        var imported = 0
        var skipped7z = 0
        var failed = 0

        for sourceURL in urls {
            let ext = sourceURL.pathExtension.lowercased()
            if ext == "zip" {
                do {
                    try importZip(sourceURL: sourceURL, destinationGamesDir: gamesDir)
                    imported += 1
                } catch {
                    AppLogger.log("ZIP import failed path=\(sourceURL.path) error=\(error.localizedDescription)")
                    failed += 1
                }
            } else if ext == "7z" {
                skipped7z += 1
            } else {
                failed += 1
            }
        }

        lastResultMessage = "インポート完了: 成功\(imported) / 7z未対応\(skipped7z) / 失敗\(failed)"
    }

    private func importZip(sourceURL: URL, destinationGamesDir: URL) throws {
        let hasScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try unzipArchive(at: sourceURL, to: tempDir)

        let extractedGameRoots = discoverGameFolders(in: tempDir)
        if extractedGameRoots.isEmpty {
            throw NSError(domain: "GameImport", code: 1)
        }

        for gameRoot in extractedGameRoots {
            let target = uniqueDestination(baseName: gameRoot.lastPathComponent, in: destinationGamesDir)
            try FileManager.default.copyItem(at: gameRoot, to: target)
        }
    }

    private func discoverGameFolders(in root: URL) -> [URL] {
        var matches: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                if hasMarkerFiles(in: url) {
                    matches.append(url)
                    enumerator.skipDescendants()
                }
            }
        }
        return matches
    }

    private func hasMarkerFiles(in directory: URL) -> Bool {
        ["RPG_RT.ldb", "RPG_RT.lmt", "RPG_RT.ini", "easyrpg-player-manifest.json"]
            .contains(where: { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) })
    }

    private func uniqueDestination(baseName: String, in parent: URL) -> URL {
        var candidate = parent.appendingPathComponent(baseName, isDirectory: true)
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = parent.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
        }
        return candidate
    }

    private func unzipArchive(at sourceURL: URL, to destinationURL: URL) throws {
        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            throw NSError(domain: "GameImport", code: 2)
        }

        for entry in archive {
            let entryPath = entry.path.replacingOccurrences(of: "\\", with: "/")
            let outputURL = destinationURL.appendingPathComponent(entryPath)

            let outputDir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            _ = try archive.extract(entry, to: outputURL)
        }
    }
}
