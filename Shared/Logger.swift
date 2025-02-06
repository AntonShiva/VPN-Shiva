//
//  Logger.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 06.02.2025.
//

import Foundation

class Logger {
    private static let queue = DispatchQueue(label: "com.Anton-Reasin.VPN-Shiva.Logger", qos: .utility)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static func log(_ message: String, type: LogType = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(type.rawValue)] \(message)"
        
        queue.async {
            print(logMessage)
            writeToFile(logMessage)
        }
    }
    
    private static func writeToFile(_ message: String) {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else { return }
        let logFile = sharedContainer.appendingPathComponent("vpn.log")
        
        if !FileManager.default.fileExists(atPath: logFile.path) {
            try? "".write(to: logFile, atomically: true, encoding: .utf8)
        }
        
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            if let data = (message + "\n").data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        }
    }
}

enum LogType: String {
    case info = "INFO"
    case error = "ERROR"
    case debug = "DEBUG"
}
