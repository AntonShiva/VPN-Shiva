//
//  VPNViewModel.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 30.01.2025.
//

import SwiftUI
import NetworkExtension


class VPNViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Отключено"
    private var providerManager: NETunnelProviderManager?
       
       init() {
           loadProviderManager()
       }
    
    // Добавляем конфигурацию VLESS
       private let vlessConfig = VLESSConfig(
           id: "iD--V2RAXX",
           host: "fastlyipcloudflaretamiz.fast.hosting-ip.com",
           port: 80,
           path: "/Telegram,V2RAXX,Telegram,V2RAXX?ed=443",
           type: "ws",
           encryption: "none"
       )
       
       private func loadProviderManager() {
           NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
               if let error = error {
                   print("Ошибка загрузки VPN конфигурации: \(error.localizedDescription)")
                   return
               }
               
               let manager: NETunnelProviderManager
               if let existingManager = managers?.first {
                   manager = existingManager
               } else {
                   manager = NETunnelProviderManager()
                   self?.setupVPNConfiguration(manager)
               }
               
               self?.providerManager = manager
           }
       }
    
    private func setupVPNConfiguration(_ manager: NETunnelProviderManager) {
         let tunnelProtocol = NETunnelProviderProtocol()
         tunnelProtocol.providerBundleIdentifier = "com.Anton-Reasin.VPN-Shiva.VPNTunnelProvider"
         tunnelProtocol.serverAddress = vlessConfig.host
         
         // Конфигурация VLESS
         tunnelProtocol.providerConfiguration = [
             "id": vlessConfig.id,
             "host": vlessConfig.host,
             "port": vlessConfig.port,
             "path": vlessConfig.path,
             "type": vlessConfig.type,
             "encryption": vlessConfig.encryption
         ]
         
         manager.protocolConfiguration = tunnelProtocol
         manager.localizedDescription = "VPN Shiva"
         manager.isEnabled = true
         
         manager.saveToPreferences { [weak self] error in
             if let error = error {
                 print("Ошибка сохранения конфигурации: \(error.localizedDescription)")
                 return
             }
             self?.providerManager = manager
         }
     }
    
    private func monitorVPNStatus() {
        NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let status = self?.providerManager?.connection.status else { return }
            
            switch status {
            case .connected:
                print("✅ VPN Connected")
                self?.isConnected = true
                self?.connectionStatus = "Подключено"
            case .connecting:
                print("🔄 VPN Connecting...")
                self?.connectionStatus = "Подключение..."
            case .disconnecting:
                print("🔄 VPN Disconnecting...")
                self?.connectionStatus = "Отключение..."
            case .disconnected:
                print("❌ VPN Disconnected")
                self?.isConnected = false
                self?.connectionStatus = "Отключено"
            case .invalid:
                print("⚠️ VPN Configuration Invalid")
                self?.connectionStatus = "Ошибка конфигурации"
            default:
                break
            }
        }
    }
    
    func toggleConnection() {
        guard let manager = providerManager else { return }
        
        if manager.connection.status == .connected {
            manager.connection.stopVPNTunnel()
        } else {
            do {
                try manager.connection.startVPNTunnel()
            } catch {
                print("Ошибка запуска VPN: \(error.localizedDescription)")
            }
        }
    }
}
