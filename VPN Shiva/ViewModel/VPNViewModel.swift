//
//  VPNViewModel.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 30.01.2025.
//

import SwiftUI
import NetworkExtension

class VPNViewModel: ObservableObject {
    @Published var connectionStatus: String = "Отключено"
    @Published var isConnected: Bool = false
    @Published private(set) var connectionStats: ConnectionStats = .zero
    
    private var providerManager: NETunnelProviderManager?
    private var vlessConfig: VLESSConfig?
    private var statsTimer: Timer?
    
    private let vlessURL = "vless://26f1320c-e993-4149-d9b4-8edf783530b9@70.34.207.32:443?security=tls&type=ws&sni=vkvd127.mycdn.me&alpn=http%2F1.1&allowInsecure=1&host=vrynpv1.sassanidempire.com&path=%2Fcpi&ed=2048&eh=Sec-Websocket-Protocol&fp=chrome#%F0%9F%92%B0%F0%9F%92%A5%F0%9F%87%B8%F0%9F%87%AA%20SE%2070.34.207.32%20%E2%97%88%20ws%3A443%20%E2%97%88%20The%20Constant%20Company%20%2F%20Vultr%20%E2%97%88%2044850"
    
    init() {
        self.vlessConfig = VLESSConfig.parse(from: vlessURL)
        loadProviderManager()
        observeVPNStatus()
        startObservingStats()
    }
    
    
    
    private func startObservingStats() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchStats()
        }
    }

    private func fetchStats() {
        guard let session = providerManager?.connection as? NETunnelProviderSession else { return }
        
        do {
            try session.sendProviderMessage("stats".data(using: .utf8)!) { [weak self] responseData in
                guard let responseData = responseData,
                      let response = String(data: responseData, encoding: .utf8) else {
                    Logger.log("Ошибка получения данных статистики", type: .error)
                    return
                }
                
                let components = response.split(separator: ",")
                guard components.count == 2,
                      let uploadValue = Int(components[0]),
                      let downloadValue = Int(components[1]) else {
                    Logger.log("Ошибка парсинга значений статистики", type: .error)
                    return
                }
                
                DispatchQueue.main.async {
                    self?.connectionStats = ConnectionStats(
                        upload: uploadValue,
                        download: downloadValue
                    )
                }
            }
        } catch {
            Logger.log("Ошибка получения статистики: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func checkAppGroups() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else {
            Logger.log("Ошибка доступа к App Groups в основном приложении", type: .error)
            return
        }
        
        let testFile = container.appendingPathComponent("test.txt")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            Logger.log("App Groups работает корректно в основном приложении", type: .info)
        } catch {
            Logger.log("Ошибка работы с App Groups в основном приложении: \(error)", type: .error)
        }
    }

    
    deinit {
        statsTimer?.invalidate()
    }
    
    private func loadProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            if let error = error {
                Logger.log("Ошибка загрузки менеджеров: \(error.localizedDescription)", type: .error)
                return
            }
            
            let manager: NETunnelProviderManager
            
            if let existingManager = managers?.first {
                manager = existingManager
            } else {
                manager = NETunnelProviderManager()
                self?.setupVPNConfiguration(manager) // Важно: вызываем настройку конфигурации
            }
            
            manager.isEnabled = true
            
            manager.saveToPreferences { error in
                if let error = error {
                    Logger.log("Ошибка сохранения настроек: \(error.localizedDescription)", type: .error)
                    return
                }
                
                manager.loadFromPreferences { error in
                    if let error = error {
                        Logger.log("Ошибка загрузки настроек: \(error.localizedDescription)", type: .error)
                        return
                    }
                    
                    self?.providerManager = manager
                    Logger.log("VPN менеджер успешно инициализирован")
                }
            }
        }
    }
    
    private func observeVPNStatus() {
        NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] notification in
            guard let connection = notification.object as? NETunnelProviderSession else { return }
            
            switch connection.status {
            case .connected:
                self?.isConnected = true
                self?.connectionStatus = "Подключено"
            case .connecting:
                self?.isConnected = false
                self?.connectionStatus = "Подключение..."
            case .disconnecting:
                self?.isConnected = false
                self?.connectionStatus = "Отключение..."
            case .disconnected:
                self?.isConnected = false
                self?.connectionStatus = "Отключено"
            default:
                self?.isConnected = false
                self?.connectionStatus = "Ошибка"
            }
        }
    }
    
    private func setupVPNConfiguration(_ manager: NETunnelProviderManager) {
        guard let config = vlessConfig else { return }
        
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = Constants.tunnelBundleId
        tunnelProtocol.serverAddress = config.host
        
        var providerConfig = [String: Any]()
        providerConfig["id"] = config.id
        providerConfig["host"] = config.host
        providerConfig["port"] = config.port
        providerConfig["type"] = config.type
        providerConfig["encryption"] = config.encryption
        providerConfig["security"] = config.security
        providerConfig["sni"] = config.sni
        providerConfig["pbk"] = config.pbk
        providerConfig["fp"] = config.fp
        providerConfig["sid"] = config.sid
        
        tunnelProtocol.providerConfiguration = providerConfig
        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "VPN Shiva"
    }
    
    func toggleConnection() {
        guard let manager = providerManager else {
            print("❌ VPN менеджер не инициализирован")
            return
        }
        
        print("📱 Текущий статус: \(manager.connection.status.rawValue)")
        
        if manager.connection.status == .disconnected {
            do {
                try manager.connection.startVPNTunnel()
                print("🚀 Запрос на подключение отправлен")
            } catch {
                print("❌ Ошибка запуска туннеля: \(error.localizedDescription)")
            }
        } else {
            manager.connection.stopVPNTunnel()
            print("🛑 Запрос на отключение отправлен")
        }
    }
    
    func updateConfig(_ config: VLESSConfig) {
        self.vlessConfig = config
        loadProviderManager()
    }
}



enum VPNStatus {
    case disconnected
    case connecting
    case connected
    case disconnecting
}


