//
//  VPNViewModel.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 30.01.2025.
//

import Foundation
import Network
import Combine

class VPNViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Отключено"
    
    private let vlessConfig = VLESSConfig(
        id: "iD--V2RAXX",
        host: "fastlyipcloudflaretamiz.fast.hosting-ip.com",
        port: 80,
        path: "/Telegram,V2RAXX,Telegram,V2RAXX?ed=443",
        type: "ws",
        encryption: "none"
    )
    
    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    private func connect() {
        // Здесь будет логика подключения
        connectionStatus = "Подключение..."
        // TODO: Реализовать VLESS подключение
    }
    
    private func disconnect() {
        // Здесь будет логика отключения
        connectionStatus = "Отключено"
        isConnected = false
    }
}
