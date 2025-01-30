//
//  WebSocketConnection.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 30.01.2025.
//

import Foundation
import Network

class WebSocketConnection {
    private var connection: NWConnection?
     var onMessage: ((Data) -> Void)?
     var onError: ((Error) -> Void)?
     
    func connect(url: URL, headers: [String: String]) {
        // Параметры для WebSocket
        let parameters = NWParameters.tls
        let wsOptions = NWProtocolWebSocket.Options()
        
        // Преобразуем словарь заголовков в массив кортежей
        let headerArray = headers.map { (name: $0.key, value: $0.value) }
        
        // Устанавливаем заголовки
        wsOptions.setAdditionalHeaders(headerArray)
        
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        // Создаем соединение
        connection = NWConnection(to: .url(url), using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("WebSocket connection ready")
                self?.startReceiving()
            case .failed(let error):
                self?.onError?(error)
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let error = error {
                self?.onError?(error)
                return
            }
            
            if let data = content {
                self?.onMessage?(data)
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    func send(data: Data) {
        // Отправка данных через WebSocket
    }
    
   
    
    func close() {
        connection?.cancel()
        connection = nil
    }
}
