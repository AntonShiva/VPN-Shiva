//
//  VLESSConfig.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 30.01.2025.
//

import Foundation

struct VLESSConfig: Codable {
    let id: String
    let host: String
    let port: Int
    let type: String
    let encryption: String
    let wsPath: String?
    let wsHost: String?
    let security: String?
    let sni: String?
    let pbk: String?     // Добавляем поля для REALITY
    let fp: String?      // Fingerprint
    let sid: String?     // ShortID
}
