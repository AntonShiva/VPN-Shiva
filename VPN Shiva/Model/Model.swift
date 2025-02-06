//
//  Model.swift
//  VPN Shiva
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
    
    // Добавляем поля для REALITY
    let pbk: String?     // Публичный ключ
    let fp: String?      // Fingerprint
    let sni: String?     // SNI
    let sid: String?     // ShortID
    
    static func parse(from url: String) -> VLESSConfig? {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host,
              let userInfo = urlComponents.user,
              let port = urlComponents.port else {
            return nil
        }
        
        let queryItems = urlComponents.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
        
        return VLESSConfig(
            id: userInfo,
            host: host,
            port: port,
            type: params["type"] ?? "tcp",
            encryption: params["encryption"] ?? "none",
            wsPath: params["path"],
            wsHost: params["host"],
            security: params["security"],
            pbk: params["pbk"],
            fp: params["fp"],
            sni: params["sni"],
            sid: params["sid"]
        )
    }
}
