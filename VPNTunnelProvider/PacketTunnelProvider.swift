//
//  PacketTunnelProvider.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 30.01.2025.
//

import NetworkExtension
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var vlessSession: VLESSSession?
    private let trafficManager = TrafficManager()
    private let queue = DispatchQueue(label: "com.vpn.tunnel", qos: .userInitiated)
    // Добавляем обработчик сообщений
    private var messageHandler: ((Data, ((Data?) -> Void)?) -> Void)?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Logger.log("⭐️ Запуск туннеля в провайдере...")
        
        // Убираем проверку status, так как такого свойства нет
        Logger.log("📡 Инициализация пакетного туннеля")
        
        guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else {
            let error = NSError(domain: "com.Anton-Reasin.VPN-Shiva", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing configuration"])
            Logger.log("❌ Отсутствует конфигурация", type: .error)
            completionHandler(error)
            return
        }
        Logger.log("📦 Конфигурация получена")
        
        let config = VLESSConfig(
            id: providerConfig["id"] as? String ?? "",
            host: providerConfig["host"] as? String ?? "",
            port: providerConfig["port"] as? Int ?? 0,
            type: providerConfig["type"] as? String ?? "tcp",
            encryption: providerConfig["encryption"] as? String ?? "none",
            wsPath: providerConfig["wsPath"] as? String,
            wsHost: providerConfig["wsHost"] as? String,
            security: providerConfig["security"] as? String,
            sni: providerConfig["sni"] as? String,
            pbk: providerConfig["pbk"] as? String,
            fp: providerConfig["fp"] as? String,
            sid: providerConfig["sid"] as? String
        )
        Logger.log("🔧 VLESS конфигурация создана: host=\(config.host), port=\(config.port)")
        
        setupNetworkSettings(config: config, completion: { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("❌ Ошибка настройки сети: \(error.localizedDescription)", type: .error)
                completionHandler(error)
                return
            }
            
            Logger.log("✅ Сетевые настройки применены")
            
            self.vlessSession = VLESSSession()
            Logger.log("🔄 VLESSSession создана")
            
            self.vlessSession?.initialize(withPacketFlow: self.packetFlow)
            Logger.log("🔄 VLESSSession инициализирована")
            
            self.vlessSession?.start(config: config, completion: { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("❌ Ошибка запуска VLESSSession: \(error)", type: .error)
                    completionHandler(error)
                    return
                }
                
                Logger.log("🚀 VLESSSession запущена")
                
                self.startPacketForwarding()
                Logger.log("📡 Начата обработка пакетов")
                
                completionHandler(nil)
            })
        })
    }
    

 private func setupNetworkSettings(config: VLESSConfig, completion: @escaping (Error?) -> Void) {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.host)
        
        // Оптимизированные настройки MTU
        networkSettings.mtu = NSNumber(value: 1420)  // Оптимальное значение для VPN
        networkSettings.tunnelOverheadBytes = NSNumber(value: 80)  // Правильное имя свойства
        
        // IPv4 настройки
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings
        
        // IPv6 настройки (опционально)
        let ipv6Settings = NEIPv6Settings(addresses: ["fd12:3456:789a:1::1"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        networkSettings.ipv6Settings = ipv6Settings
        
        // DNS настройки
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""] // Применяем ко всем доменам
        networkSettings.dnsSettings = dnsSettings
        
        Logger.log("Применяем сетевые настройки...")
        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                Logger.log("Ошибка применения сетевых настроек: \(error)", type: .error)
            } else {
                Logger.log("Сетевые настройки применены успешно")
            }
            completion(error)
        }
    }
    
    private func startPacketForwarding() {
        queue.async { [weak self] in
            self?.readPackets()
        }
    }
    
    private func readPackets() {
        packetFlow.readPacketObjects { [weak self] packets in
            guard let self = self else { return }
            
            if !packets.isEmpty {
                Logger.log("Получено пакетов: \(packets.count)")
                
                self.trafficManager.processPackets(packets) { processedData in
                    autoreleasepool {
                        self.vlessSession?.sendDataToTunnel(processedData) { error in
                            if let error = error {
                                Logger.log("Ошибка отправки данных: \(error)", type: .error)
                            }
                        }
                    }
                }
            }
            
            // Немедленно запрашиваем следующую порцию пакетов
            self.queue.async {
                self.readPackets()
            }
        }
    }
    
    private func updateStats(upload: Int64, download: Int64) {
        guard let defaults = Constants.sharedUserDefaults else { return }  
        
        defaults.set(Int(upload), forKey: "upload")
        defaults.set(Int(download), forKey: "download")
        defaults.synchronize()
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger.log("Остановка туннеля")
        vlessSession?.stop()
        updateStats(upload: 0, download: 0)
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
        
        Logger.log("📨 Получено сообщение: \(message)")
        
        switch message {
        case "stats":
            let stats = trafficManager.getStats()
            let response = "\(stats.upload),\(stats.download)".data(using: .utf8)
            Logger.log("📊 Отправка статистики: upload=\(stats.upload), download=\(stats.download)")
            completionHandler?(response)
            
        default:
            Logger.log("❓ Неизвестное сообщение: \(message)", type: .error)
            completionHandler?(nil)
        }
    }
}
