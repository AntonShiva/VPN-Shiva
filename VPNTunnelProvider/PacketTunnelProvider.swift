//
//  PacketTunnelProvider.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 30.01.2025.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
          // Базовая конфигурация туннеля
          let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
          
          // Настройка IPv4
          networkSettings.ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.1"], subnetMasks: ["255.255.255.0"])
          
          // Настройка DNS
          networkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
          
          // Применяем настройки
          setTunnelNetworkSettings(networkSettings) { error in
              if let error = error {
                  completionHandler(error)
                  return
              }
              completionHandler(nil)
          }
      }
      
      override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
          completionHandler()
      }
}
