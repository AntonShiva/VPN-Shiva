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
    private var upload: Int64 = 0
    private var download: Int64 = 0
    private let statsLock = NSLock()
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        checkAppGroups() // Проверяем при старте туннеля
        Logger.log("Запуск туннеля в провайдере...")
        
        guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else {
            let error = NSError(domain: "com.Anton-Reasin.VPN-Shiva", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing configuration"])
            Logger.log("Отсутствует конфигурация", type: .error)
            completionHandler(error)
            return
        }
        
        Logger.log("Полученная конфигурация: \(providerConfig)")
        
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
        
        setupNetworkSettings(config: config) { [weak self] error in
            if let error = error {
                Logger.log("Ошибка установки сетевых настроек: \(error.localizedDescription)", type: .error)
                completionHandler(error)
                return
            }
            
            Logger.log("Сетевые настройки применены успешно")
            
            self?.vlessSession = VLESSSession()
            self?.vlessSession?.initialize(withPacketFlow: self?.packetFlow)
            self?.vlessSession?.start(config: config)
            
            self?.startPacketForwarding()
            completionHandler(nil)
        }
    }
    
    private func checkAppGroups() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else {
            Logger.log("Ошибка доступа к App Groups в провайдере", type: .error)
            return
        }
        
        let testFile = container.appendingPathComponent("test.txt")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            Logger.log("App Groups работает корректно в провайдере", type: .info)
        } catch {
            Logger.log("Ошибка работы с App Groups в провайдере: \(error)", type: .error)
        }
    }

    
    private func setupNetworkSettings(config: VLESSConfig, completion: @escaping (Error?) -> Void) {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.host)
        
        // Оптимизируем MTU для лучшей производительности
        networkSettings.mtu = NSNumber(value: 1400) // Изменено с 1420 на 1400
        
        // Настраиваем IPv4
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings
        
        // Добавляем поддержку IPv6
        let ipv6Settings = NEIPv6Settings(addresses: ["fd12:3456:789a:1::1"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        networkSettings.ipv6Settings = ipv6Settings
        
        // Оптимизируем DNS используя Google и Cloudflare
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""] // Все домены
        networkSettings.dnsSettings = dnsSettings
        
        setTunnelNetworkSettings(networkSettings, completionHandler: completion)
    }
    
    private func updateStats() {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        guard let defaults = Constants.sharedUserDefaults else { return }
        defaults.set(Int(upload), forKey: "upload")
        defaults.set(Int(download), forKey: "download")
        defaults.synchronize()
    }
    
    private func startPacketForwarding() {
        packetFlow.readPacketObjects { [weak self] packets in
            guard let self = self else { return }
            
            let totalSize = packets.reduce(0) { $0 + $1.data.count }
            let packetCount = packets.count
            
            Logger.log("Получено пакетов: \(packetCount), общий размер: \(totalSize) байт", type: .debug)
            
            self.statsLock.lock()
            self.download += Int64(totalSize)
            self.statsLock.unlock()
            
            // Группируем пакеты для оптимизации
            let batchSize = 10
            for i in stride(from: 0, to: packets.count, by: batchSize) {
                let end = min(i + batchSize, packets.count)
                let batch = packets[i..<end]
                
                for packet in batch {
                    autoreleasepool {
                        self.vlessSession?.sendDataToTunnel(packet.data)
                    }
                }
            }
            
            self.statsLock.lock()
            self.upload += Int64(totalSize)
            self.statsLock.unlock()
            
            if totalSize > 1024 * 100 {
                self.updateStats()
            }
            
            // Добавляем небольшую задержку для предотвращения перегрузки
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.001) {
                self.startPacketForwarding()
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger.log("Остановка туннеля")
        vlessSession?.stop()
        
        statsLock.lock()
        upload = 0
        download = 0
        statsLock.unlock()
        
        updateStats()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let message = String(data: messageData, encoding: .utf8)
        switch message {
        case "stats":
            statsLock.lock()
            let stats = "\(upload),\(download)".data(using: .utf8)!
            statsLock.unlock()
            completionHandler?(stats)
        default:
            completionHandler?(nil)
        }
    }
}
