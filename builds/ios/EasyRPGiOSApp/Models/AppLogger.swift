import Foundation

enum AppLogger {
    private static let queue = DispatchQueue(label: "org.easyrpg.ios.logger", qos: .utility)
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static var logURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("easyrpg-ios-debug.log")
    }

    static func log(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let ts = isoFormatter.string(from: Date())
        let entry = "[\(ts)] [\(file):\(line)] \(function) - \(message)\n"
        queue.async {
            do {
                let data = Data(entry.utf8)
                if FileManager.default.fileExists(atPath: logURL.path) {
                    let handle = try FileHandle(forWritingTo: logURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: logURL, options: .atomic)
                }
            } catch {
                print("[AppLogger] write failed: \(error)")
            }
        }
        print(entry, terminator: "")
    }
}
