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
    private var vlessConfig: VLESSConfig?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
         guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
               let host = providerConfig["host"] as? String,
               let port = providerConfig["port"] as? Int,
               let id = providerConfig["id"] as? String,
               let path = providerConfig["path"] as? String else {
             completionHandler(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing configuration"]))
             return
         }
        // Создаем конфигурацию
         vlessConfig = VLESSConfig(
             id: id,
             host: host,
             port: port,
             path: path,
             type: "ws",
             encryption: "none"
         )
         
         let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: host)
         networkSettings.ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.1"], subnetMasks: ["255.255.255.0"])
         networkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
         
         setTunnelNetworkSettings(networkSettings) { [weak self] error in
             guard let self = self else { return }
             
             if let error = error {
                 completionHandler(error)
                 return
             }
             
             // Безопасно инициализируем сессию
             let session = VLESSSession()
             session.initialize(withPacketFlow: self.packetFlow)
             session.start(host: host, port: port, id: id, path: path)
             self.vlessSession = session
             
             // Начинаем читать пакеты
             self.startPacketForwarding()
             completionHandler(nil)
         }
     }
    
    private func startPacketForwarding() {
         packetFlow.readPackets { [weak self] packets, protocols in
             guard let self = self,
                   let vlessSession = self.vlessSession,
                   let config = self.vlessConfig else {
                 print("Missing required session or configuration")
                 return
             }
             
             for (index, packet) in packets.enumerated() {
                 vlessSession.sendDataToTunnel(packet, uuid: config.id)
             }
             
             // Продолжаем чтение пакетов
             self.startPacketForwarding()
         }
     }
     
     override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
         vlessSession?.stop()
         completionHandler()
     }
}
