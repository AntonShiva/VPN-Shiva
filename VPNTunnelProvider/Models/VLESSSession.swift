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
    private let vlessVersion: UInt8 = 0
    private var packetTunnelFlow: NEPacketTunnelFlow?
    private var config: VLESSConfig?
    private var isRunning: Bool = false
    
    func initialize(withPacketFlow packetFlow: NEPacketTunnelFlow?) {
        self.packetTunnelFlow = packetFlow
    }
    
    func start(config: VLESSConfig) {
        self.config = config
        self.isRunning = true
        
        print("🚀 Запуск VLESSSession")
        print("📍 Хост: \(config.host):\(config.port)")
        print("🔑 ID: \(config.id)")
        print("🔒 Security: \(config.security ?? "none")")
        print("🌐 Type: \(config.type)")
        
        // Настраиваем TLS
        let tlsOptions = NWProtocolTLS.Options()
        
        if config.security == "tls" {
            print("🔐 Настройка TLS...")
            
            // Отключаем проверку сертификата для тестирования
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completionHandler in
                completionHandler(true)
            }, .main)
            
            // Устанавливаем SNI если есть
            if let sni = config.sni {
                print("🔧 Установка SNI: \(sni)")
                if let sniData = sni.data(using: .utf8) {
                    sniData.withUnsafeBytes { buffer in
                        guard let baseAddress = buffer.baseAddress else { return }
                        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, baseAddress)
                    }
                }
            }
        }
        
        // Настраиваем WebSocket
        let wsOptions = NWProtocolWebSocket.Options()
        
        if let wsHost = config.wsHost {
            print("🌐 Установка WebSocket хоста: \(wsHost)")
            let headers = [("Host", wsHost)]
            wsOptions.setAdditionalHeaders(headers)
        }
        
        // Создаем параметры подключения
        let parameters = NWParameters(tls: tlsOptions, tcp: .init())
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        // Создаем endpoint
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(config.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(config.port))
        )
        
        print("🔄 Создание соединения...")
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ TLS соединение установлено")
                self?.startVLESSHandshake()
            case .preparing:
                print("⏳ Подготовка соединения...")
            case .waiting(let error):
                print("⚠️ Ожидание: \(error)")
            case .failed(let error):
                print("❌ Ошибка соединения: \(error)")
            case .cancelled:
                print("🛑 Соединение отменено")
            default:
                print("ℹ️ Статус соединения: \(state)")
            }
        }
        
        print("▶️ Запуск соединения...")
        connection?.start(queue: .global())
    }
    private func startVLESSHandshake() {
        guard let config = config else { return }
        
        var handshake = Data()
        handshake.append(vlessVersion)
        
        // Добавляем UUID
        if let uuid = UUID(uuidString: config.id) {
            withUnsafeBytes(of: uuid.uuid) { buffer in
                handshake.append(contentsOf: buffer)
            }
        }
        
        // Добавляем команду (TCP)
        handshake.append(0x01)
        
        // Добавляем адрес и порт
        if let hostData = config.host.data(using: .utf8) {
            handshake.append(UInt8(hostData.count))
            handshake.append(hostData)
        }
        handshake.append(UInt8(config.port >> 8))
        handshake.append(UInt8(config.port & 0xFF))
        
        print("📤 Отправка VLESS handshake (\(handshake.count) байт)")
        
        connection?.send(content: handshake, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ Ошибка handshake: \(error)")
                return
            }
            print("✅ VLESS handshake отправлен")
            
            // Добавляем ожидание ответа от сервера
            self?.connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] content, _, isComplete, error in
                if let error = error {
                    print("❌ Ошибка получения ответа handshake: \(error)")
                    return
                }
                
                if let responseData = content {
                    print("✅ Получен ответ handshake: \(responseData.count) байт")
                    // После успешного handshake начинаем чтение пакетов
                    self?.readPackets()
                }
            }
        })
    }

    private func handleIncomingData(_ data: Data) {
        guard data.count >= 1 else { return }
        
        print("📥 Получены данные: \(data.count) байт")
        
        // Отправляем данные в туннель
        let success = packetTunnelFlow?.writePackets([data], withProtocols: [NSNumber(value: AF_INET)]) ?? false
        
        if !success {
            print("❌ Ошибка записи в туннель")
        } else {
            print("✅ Данные успешно записаны в туннель")
        }
    }
    
    private func readPackets() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let error = error {
                print("❌ Ошибка чтения: \(error)")
                return
            }
            
            if let data = content {
                self?.handleIncomingData(data)
            }
            
            if !isComplete && self?.isRunning == true {
                self?.readPackets()
            }
        }
    }
    


    // Добавляем публичный метод для отправки данных в туннель
    func sendDataToTunnel(_ data: Data) {
        guard isRunning else {
            Logger.log("Сессия не активна", type: .error)
            return
        }
        
        var packet = Data(capacity: data.count + 2) // Предварительно выделяем память
        packet.append(vlessVersion)
        packet.append(0x01) // TCP команда
        packet.append(data)
        
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                Logger.log("Ошибка отправки: \(error)", type: .error)
            }
        })
    }

    // Добавляем публичный метод для остановки сессии
    func stop() {
        print("🛑 Остановка VLESSSession")
        isRunning = false
        connection?.cancel()
        connection = nil
        wsConnection?.close()
        wsConnection = nil
    }
}
