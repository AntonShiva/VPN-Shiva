//
//  VPNViewModel.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 30.01.2025.
//

import SwiftUI
import NetworkExtension
import Network

class VPNViewModel: ObservableObject {
    @Published var connectionStatus: String = "Отключено"
    @Published var isConnected: Bool = false
    @Published private(set) var connectionStats: ConnectionStats = .zero
    
    private var providerManager: NETunnelProviderManager?
    private var vlessConfig: VLESSConfig?
    private var statsTimer: Timer?
    
    private let vlessURL = "vless://05519058-d2ac-4f28-9e4a-2b2a1386749e@15.236.36.65:22222?path=/telegram-channel-vlessconfig-ws&security=tls&encryption=none&host=telegram-channel-vlessconfig.sohala.uk&type=ws&sni=telegram-channel-vlessconfig.sohala.uk#Telegram"
    
    init() {
        self.vlessConfig = VLESSConfig.parse(from: vlessURL)
        initializeVPN()
    }
    
    
    
    private func startObservingStats() {
        statsTimer?.invalidate() // Останавливаем предыдущий таймер если есть
        
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let session = self.providerManager?.connection as? NETunnelProviderSession,
                  session.status == .connected else {
                return // Просто выходим без логирования ошибки
            }
            self.fetchStats()
        }
    }
    
    private func initializeVPN() {
        guard checkAppGroups() else {
            Logger.log("❌ Ошибка инициализации App Groups", type: .error)
            connectionStatus = "Ошибка"
            isConnected = false
            return
        }
        
        loadProviderManager()
        observeVPNStatus()
        startObservingStats()
    }

    private func fetchStats() {
        guard let session = providerManager?.connection as? NETunnelProviderSession,
              session.status == .connected else {
            // Убираем лог об отсутствии сессии
            return
        }
        
        do {
            Logger.log("📊 Запрос статистики...")
            try session.sendProviderMessage("stats".data(using: .utf8)!) { [weak self] responseData in
                guard let responseData = responseData,
                      let response = String(data: responseData, encoding: .utf8) else {
                    Logger.log("❌ Нет данных статистики", type: .error)
                    return
                }
                
                Logger.log("📊 Получены данные: \(response)")
                
                let components = response.split(separator: ",")
                guard components.count == 2,
                      let uploadValue = Int(components[0]),
                      let downloadValue = Int(components[1]) else {
                    Logger.log("❌ Неверный формат данных", type: .error)
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
            Logger.log("❌ Ошибка отправки запроса: \(error)", type: .error)
        }
    }
    private func checkAppGroups() -> Bool {
        // Проверяем доступ к App Groups
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else {
            Logger.log("❌ Критическая ошибка: Нет доступа к App Groups. Проверьте настройки Entitlements", type: .error)
            return false
        }
        
        let testFile = container.appendingPathComponent("vpn_test.txt")
        let testString = "VPN Test \(Date())"
        
        do {
            // Пробуем записать
            try testString.write(to: testFile, atomically: true, encoding: .utf8)
            
            // Пробуем прочитать
            let readString = try String(contentsOf: testFile, encoding: .utf8)
            
            // Проверяем содержимое
            guard readString == testString else {
                Logger.log("❌ Ошибка проверки App Groups: данные не совпадают", type: .error)
                return false
            }
            
            // Удаляем тестовый файл
            try FileManager.default.removeItem(at: testFile)
            
            Logger.log("✅ App Groups работает корректно", type: .info)
            return true
            
        } catch {
            Logger.log("❌ Ошибка работы с App Groups: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    
    deinit {
        statsTimer?.invalidate()
    }
    
    private func loadProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Ошибка загрузки менеджеров: \(error.localizedDescription)", type: .error)
                return
            }
            
            let manager: NETunnelProviderManager
            
            if let existingManager = managers?.first {
                manager = existingManager
                self.setupVPNConfiguration(manager) // Обновляем конфигурацию существующего менеджера
            } else {
                manager = NETunnelProviderManager()
                self.setupVPNConfiguration(manager)
            }
            
            manager.isEnabled = true
            
            // Сначала сохраняем
            manager.saveToPreferences { [weak self] error in
                if let error = error {
                    Logger.log("Ошибка сохранения настроек: \(error.localizedDescription)", type: .error)
                    return
                }
                
                // Затем загружаем заново
                manager.loadFromPreferences { [weak self] error in
                    if let error = error {
                        Logger.log("Ошибка загрузки настроек: \(error.localizedDescription)", type: .error)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.providerManager = manager
                        Logger.log("VPN менеджер успешно инициализирован")
                    }
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
    
//    func toggleConnection() {
//        // 1. Проверяем инициализацию менеджера
//        guard let manager = providerManager else {
//            Logger.log("❌ VPN менеджер не инициализирован", type: .error)
//            return
//        }
//        
//        // 2. Проверяем текущий статус
//        Logger.log("📱 Текущий статус: \(manager.connection.status.rawValue)", type: .debug)
//        
//        // 3. Загружаем свежие настройки
//        manager.loadFromPreferences { [weak self] error in
//            if let error = error {
//                Logger.log("❌ Ошибка загрузки настроек: \(error.localizedDescription)", type: .error)
//                return
//            }
//            
//            // 4. Проверяем, что VPN включен
//            if !manager.isEnabled {
//                Logger.log("❌ VPN отключен в настройках", type: .error)
//                // Включаем VPN
//                manager.isEnabled = true
//                manager.saveToPreferences { error in
//                    if let error = error {
//                        Logger.log("❌ Ошибка сохранения настроек: \(error.localizedDescription)", type: .error)
//                        return
//                    }
//                    // Повторяем попытку подключения после включения
//                    self?.toggleConnection()
//                }
//                return
//            }
//            
//            // 5. Проверяем конфигурацию
//            guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
//                Logger.log("❌ Неверная конфигурация протокола", type: .error)
//                return
//            }
//            
//            Logger.log("✅ Проверка конфигурации: \(proto.providerBundleIdentifier ?? "nil")", type: .debug)
//            
//            // 6. Пробуем запустить VPN
//            do {
//                // Важно: добавляем проверку текущего статуса
//                if manager.connection.status == .connected {
//                    manager.connection.stopVPNTunnel()
//                    return
//                }
//                
//                Logger.log("📋 Проверка настроек перед запуском:")
//                Logger.log("- Bundle ID: \(proto.providerBundleIdentifier ?? "nil")")
//                Logger.log("- Server Address: \(proto.serverAddress ?? "nil")")
//                Logger.log("- Enabled: \(manager.isEnabled)")
//                Logger.log("- Connection Status: \(manager.connection.status.rawValue)")
//                Logger.log("- Protocol Type: \(type(of: proto))")
//                
//                if let config = proto.providerConfiguration {
//                    Logger.log("- Config Keys: \(config.keys.joined(separator: ", "))")
//                }
//                
//                try manager.connection.startVPNTunnel()
//                Logger.log("🚀 Запрос на подключение отправлен", type: .info)
//            } catch let error as NSError {
//                Logger.log("❌ Ошибка запуска туннеля: \(error.localizedDescription) (код: \(error.code))", type: .error)
//                
//                switch error.code {
//                case 3:
//                    Logger.log("❌ Неверная конфигурация VPN", type: .error)
//                case 5:
//                    Logger.log("❌ VPN отключен", type: .error)
//                default:
//                    Logger.log("❌ Неизвестная ошибка: \(error.domain)", type: .error)
//                }
//            }
//        }
//    }


    
    func toggleConnection() {
        // 1. Проверяем инициализацию менеджера
        guard let manager = providerManager else {
            Logger.log("❌ VPN менеджер не инициализирован", type: .error)
            return
        }
        
        // 2. Проверяем текущий статус
        Logger.log("📱 Текущий статус: \(manager.connection.status.rawValue)", type: .debug)
        
        // 3. Загружаем свежие настройки
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                Logger.log("❌ Ошибка загрузки настроек: \(error.localizedDescription)", type: .error)
                return
            }
            
            // 4. Проверяем, что VPN включен
            if !manager.isEnabled {
                Logger.log("❌ VPN отключен в настройках", type: .error)
                // Включаем VPN
                manager.isEnabled = true
                manager.saveToPreferences { error in
                    if let error = error {
                        Logger.log("❌ Ошибка сохранения настроек: \(error.localizedDescription)", type: .error)
                        return
                    }
                    // Повторяем попытку подключения после включения
                    self?.toggleConnection()
                }
                return
            }
            
            // 5. Проверяем конфигурацию
            guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                Logger.log("❌ Неверная конфигурация протокола", type: .error)
                return
            }
            
            Logger.log("✅ Проверка конфигурации: \(proto.providerBundleIdentifier ?? "nil")", type: .debug)
            
            // 6. Пробуем запустить VPN
            do {
                Logger.log("📋 Проверка настроек перед запуском:")
                Logger.log("- Bundle ID: \(proto.providerBundleIdentifier ?? "nil")")
                Logger.log("- Server Address: \(proto.serverAddress ?? "nil")")
                Logger.log("- Enabled: \(manager.isEnabled)")
                Logger.log("- Connection Status: \(manager.connection.status.rawValue)")
                Logger.log("- Protocol Type: \(type(of: proto))")

                if let config = proto.providerConfiguration {
                    Logger.log("- Config Keys: \(config.keys.joined(separator: ", "))")
                }
                try manager.connection.startVPNTunnel()
                Logger.log("🚀 Запрос на подключение отправлен", type: .info)
            } catch let error as NSError {
                Logger.log("❌ Ошибка запуска туннеля: \(error.localizedDescription) (код: \(error.code))", type: .error)
                
                // 7. Проверяем специфические ошибки
                switch error.code {
                case 3: // NEVPNError.configurationInvalid
                    Logger.log("❌ Неверная конфигурация VPN", type: .error)
                case 5: // NEVPNError.configurationDisabled
                    Logger.log("❌ VPN отключен", type: .error)
                default:
                    Logger.log("❌ Неизвестная ошибка: \(error.domain)", type: .error)
                }
            }
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


