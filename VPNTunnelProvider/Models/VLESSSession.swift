//
//  VLESSSession.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 30.01.2025.
//

import Foundation
import Network
import NetworkExtension
import Security

class VLESSSession {
    private var connection: NWConnection?
    private var wsConnection: WebSocketConnection?
    
    func start(host: String, port: Int, id: String, path: String) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
           
           // Параметры для WebSocket поверх TLS
           let parameters = NWParameters(tls: NWProtocolTLS.Options(), tcp: NWProtocolTCP.Options())
           
           // WebSocket как дополнительный протокол
           let wsOptions = NWProtocolWebSocket.Options()
           wsOptions.autoReplyPing = true
           parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
           
           connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.setupWebSocket(path: path, id: id)
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    private func setupWebSocket(path: String, id: String) {
        // Создаем WebSocket соединение
        wsConnection = WebSocketConnection()
        
        // Формируем заголовки для WebSocket
        let headers: [String: String] = [
            "Host": "V2RAXX.IR",  // Используем значение из host параметра VLESS URL
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
            "Upgrade": "websocket",
            "Connection": "Upgrade",
            "Sec-WebSocket-Version": "13",
            "Sec-WebSocket-Key": generateWebSocketKey()
        ]
        
        // Создаем URL для WebSocket соединения
        var components = URLComponents()
        components.scheme = "wss"  // Используем WSS так как поверх TLS
        components.path = path
        
        guard let url = components.url else {
            print("Ошибка создания URL для WebSocket")
            return
        }
        
        // Устанавливаем соединение
        wsConnection?.connect(url: url, headers: headers)
        
        // Начинаем прослушивание данных
        wsConnection?.onMessage = { [weak self] data in
            self?.handleWebSocketData(data)
        }
        
        wsConnection?.onError = { error in
            print("WebSocket error: \(error.localizedDescription)")
        }
    }
    
    // Вспомогательный метод для генерации WebSocket ключа
    private func generateWebSocketKey() -> String {
        let length = 16
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomString = (0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] }
        let data = String(randomString).data(using: .utf8)!
        return data.base64EncodedString()
    }
    
    // Обработка входящих данных
    private func handleWebSocketData(_ data: Data) {
        // Здесь будет обработка данных VLESS протокола
        // Пока просто логируем
        print("Received WebSocket data: \(data.count) bytes")
    }
    
    func stop() {
        wsConnection?.close()
        connection?.cancel()
    }
}
