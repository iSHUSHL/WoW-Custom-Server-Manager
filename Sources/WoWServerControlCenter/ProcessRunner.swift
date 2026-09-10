import Foundation

final class ManagedProcess: @unchecked Sendable {
    private(set) var process: Process?
    private let logURL: URL
    private var inputPipe: Pipe?
    private var intentionalStop = false
    private let stateLock = NSLock()
    private var _lastTerminationSummary: String?
    var lastTerminationSummary: String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _lastTerminationSummary
    }

    init(logURL: URL) { self.logURL = logURL }

    private var crashLogURL: URL {
        logURL.deletingLastPathComponent().appendingPathComponent("world-crash.log")
    }

    private func appendLatestMacOSCrashReport(processName: String, after: Date) {
        let fm = FileManager.default
        let diagnosticDirs = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true),
            URL(fileURLWithPath: "/Library/Logs/DiagnosticReports", isDirectory: true)
        ]
        var candidates: [(URL, Date)] = []
        for dir in diagnosticDirs {
            guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for url in urls {
                let name = url.lastPathComponent.lowercased()
                guard name.hasPrefix(processName.lowercased()),
                      name.hasSuffix(".ips") || name.hasSuffix(".crash") else { continue }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if modified >= after.addingTimeInterval(-10) { candidates.append((url, modified)) }
            }
        }
        guard let newest = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            appendCrashRecord("[macOS crash report] No matching mangosd DiagnosticReports file found.")
            return
        }
        guard let data = try? Data(contentsOf: newest), let text = String(data: data, encoding: .utf8) else {
            appendCrashRecord("[macOS crash report] Found \(newest.path), but could not read it.")
            return
        }
        appendCrashRecord("[macOS crash report] \(newest.path)\n----- BEGIN macOS Diagnostic Report -----\n\(String(text.suffix(120_000)))\n----- END macOS Diagnostic Report -----")
    }

    private func appendCoreBacktrace(executable: URL, after: Date) {
        let fm = FileManager.default
        let searchDirs = [
            URL(fileURLWithPath: "/cores", isDirectory: true),
            logURL.deletingLastPathComponent(),
            fm.homeDirectoryForCurrentUser
        ]

        var candidates: [(URL, Date)] = []
        for dir in searchDirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let name = url.lastPathComponent.lowercased()
                guard name == "core" || name.hasPrefix("core.") else { continue }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let modified = values?.contentModificationDate ?? .distantPast
                if modified >= after.addingTimeInterval(-10) {
                    candidates.append((url, modified))
                }
            }
        }

        guard let coreURL = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            appendCrashRecord("[native backtrace] No fresh core file was produced. Core dumps were requested for this World launch.")
            return
        }

        let lldb = Process()
        lldb.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        lldb.arguments = [
            "lldb",
            "--batch",
            "-c", coreURL.path,
            executable.path,
            "-o", "thread backtrace all"
        ]
        let pipe = Pipe()
        lldb.standardOutput = pipe
        lldb.standardError = pipe

        do {
            try lldb.run()
            lldb.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "(LLDB produced non-UTF8 output)"
            appendCrashRecord("""
            [native backtrace] core=\(coreURL.path)
            ----- BEGIN LLDB BACKTRACE -----
            \(String(output.suffix(120_000)))
            ----- END LLDB BACKTRACE -----
            """)
        } catch {
            appendCrashRecord("[native backtrace] Core found at \(coreURL.path), but LLDB failed: \(error.localizedDescription)")
        }
    }

    private func appendCrashRecord(_ text: String) {
        let line = text + "\n"
        let data = Data(line.utf8)
        let fm = FileManager.default
        if !fm.fileExists(atPath: crashLogURL.path) {
            fm.createFile(atPath: crashLogURL.path, contents: data)
            return
        }
        guard let h = try? FileHandle(forWritingTo: crashLogURL) else { return }
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        _ = try? h.write(contentsOf: data)
    }
    var isRunning: Bool { process?.isRunning == true }
    var pid: Int32? { process?.processIdentifier }

    func start(executable: URL, arguments: [String] = [], currentDirectory: URL? = nil, environment: [String:String]? = nil, interactive: Bool = false, captureCrashWithLLDB: Bool = false) throws {
        guard !isRunning else { return }
        intentionalStop = false
        stateLock.lock()
        _lastTerminationSummary = nil
        stateLock.unlock()
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL); try handle.seekToEnd()
        let p = Process()
        if captureCrashWithLLDB {
            // Run mangosd under LLDB so a SIGSEGV can be captured even when macOS
            // produces neither DiagnosticReports nor a core dump.
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = [
                "lldb",
                "--batch",
                "-o", "settings set target.input-path /dev/stdin",
                "-o", "process handle SIGSEGV -s true -n true -p true",
                "-k", "thread backtrace all",
                "-k", "quit",
                "-o", "run",
                "--",
                executable.path
            ] + arguments
        } else {
            p.executableURL = executable
            p.arguments = arguments
        }
        p.currentDirectoryURL = currentDirectory
        if let environment { p.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new } }
        p.standardOutput = handle; p.standardError = handle
        if interactive { let pipe = Pipe(); p.standardInput = pipe; inputPipe = pipe }

        // Capture exits that never reach CMaNGOS logging (SIGSEGV/SIGABRT/SIGKILL, etc.).
        // Process keeps itself alive until this handler has run.
        let processStartedAt = Date()
        p.terminationHandler = { [weak self] finished in
            guard let self else { return }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let reason: String
            switch finished.terminationReason {
            case .exit: reason = "exit"
            case .uncaughtSignal: reason = "uncaught-signal"
            @unknown default: reason = "unknown"
            }
            let summary = "[\(timestamp)] mangosd PID \(finished.processIdentifier) terminated: reason=\(reason), status=\(finished.terminationStatus), intentional=\(self.intentionalStop)"
            self.stateLock.lock()
            self._lastTerminationSummary = summary
            self.stateLock.unlock()
            self.appendCrashRecord(summary)
            if captureCrashWithLLDB && !self.intentionalStop {
                self.appendCrashRecord("[LLDB live capture] TBC World was launched under LLDB. If the target crashed, the full debugger output is in worldserver.log and is visible in Logs → World.")
            }
            if finished.terminationReason == .uncaughtSignal && !self.intentionalStop {
                let processName = finished.executableURL?.lastPathComponent ?? "mangosd"
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.appendLatestMacOSCrashReport(processName: processName, after: processStartedAt)
                }
            }
            self.inputPipe = nil
        }

        try p.run()
        process = p
        appendCrashRecord("[\(ISO8601DateFormatter().string(from: Date()))] mangosd started: PID \(p.processIdentifier), executable=\(executable.path)")
    }

    func send(_ command: String) throws {
        guard isRunning, let inputPipe else { throw NSError(domain: "WoWCC", code: 20, userInfo: [NSLocalizedDescriptionKey: "World server console is not running"])}
        guard let data = (command + "\n").data(using: .utf8) else { return }
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    func stop(graceSeconds: Double = 5) {
        guard let p = process, p.isRunning else { return }
        intentionalStop = true
        let effectiveGrace = p.executableURL?.path == "/usr/bin/xcrun" ? min(graceSeconds, 1.0) : graceSeconds
        p.terminate(); let deadline = Date().addingTimeInterval(effectiveGrace)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        inputPipe = nil
    }
}
