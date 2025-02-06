//
//  ConnectionStats.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 06.02.2025.
//

import Foundation
struct ConnectionStats: Codable {
    let upload: Int
    let download: Int
    
    static let zero = ConnectionStats(upload: 0, download: 0)
}
