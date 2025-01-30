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
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Получаем конфигурацию из protocolConfiguration
            guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
                  let host = providerConfig["host"] as? String,
                  let port = providerConfig["port"] as? Int,
                  let id = providerConfig["id"] as? String,
                  let path = providerConfig["path"] as? String else {
                completionHandler(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing configuration"]))
                return
            }
        
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: host)
        networkSettings.ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            self?.vlessSession = VLESSSession()
            self?.vlessSession?.start(host: host, port: port, id: id, path: path)
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        vlessSession?.stop()
        completionHandler()
    }
}
