//
//  Constants.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 06.02.2025.
//

import Foundation

enum Constants {
    static let appGroupId = "group.com.Anton-Reasin.VPN-Shiva"
    static let tunnelBundleId = "com.Anton-Reasin.VPN-Shiva.VPNTunnelProvider"
    
    static var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }
}


