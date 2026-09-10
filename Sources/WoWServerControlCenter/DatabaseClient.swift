import Foundation

struct DatabaseClient {
    let executable: String
    let port: Int

    func query(database: String, sql: String) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = ["--protocol=TCP", "-h", "127.0.0.1", "-P", "\(port)", "-u", "wowcc", "--batch", "--skip-column-names", database, "-e", sql]
        var env = ProcessInfo.processInfo.environment
        env["MYSQL_PWD"] = "wowcc"
        p.environment = env
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        try p.run(); p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        if p.terminationStatus != 0 {
            let raw = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "mysql failed"
            let cleaned = raw
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.contains("Using a password on the command line interface can be insecure") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "WoWCC.DB", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: cleaned.isEmpty ? "MySQL query failed" : cleaned])
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func execute(database: String, sql: String) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = ["--protocol=TCP", "-h", "127.0.0.1", "-P", "\(port)",
                       "-u", "wowcc", "--batch", "--skip-column-names",
                       database, "-e", sql]
        var env = ProcessInfo.processInfo.environment
        env["MYSQL_PWD"] = "wowcc"
        p.environment = env

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        try p.run()
        p.waitUntilExit()

        if p.terminationStatus != 0 {
            let raw = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? "mysql failed"
            let cleaned = raw
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.contains("Using a password on the command line interface can be insecure") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "WoWCC.DB",
                code: Int(p.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey:
                    cleaned.isEmpty ? "MySQL update failed" : cleaned]
            )
        }
    }
}
