//
//  TrafficManager.swift
//  VPNTunnelProvider
//
//  Created by Anton Rasen on 06.02.2025.
//
import Foundation
import Network
import NetworkExtension

class TrafficManager {
    private let queue = DispatchQueue(label: "com.vpn.traffic", qos: .userInitiated)
    private let bufferSize = 64 * 1024 // 64KB буфер
    private var packetBuffer: [Data] = []
    private var totalUpload: Int64 = 0
    private var totalDownload: Int64 = 0
    private let lock = NSLock()
    
    func processPackets(_ packets: [NEPacket], completion: @escaping (Data) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                var batchSize: Int64 = 0
                
                // Подсчитываем размер входящих данных
                for packet in packets {
                    batchSize += Int64(packet.data.count)
                    self.packetBuffer.append(packet.data)
                }
                
                // Атомарно обновляем статистику входящего трафика
                self.lock.lock()
                self.totalDownload += batchSize
                self.lock.unlock()
                
                // Проверяем необходимость сброса буфера
                if self.packetBuffer.count >= self.bufferSize {
                    self.flushBuffer { processedData in
                        // Атомарно обновляем статистику исходящего трафика
                        self.lock.lock()
                        self.totalUpload += Int64(processedData.count)
                        self.lock.unlock()
                        
                        completion(processedData)
                    }
                }
            }
        }
    }
    
    private func flushBuffer(_ completion: @escaping (Data) -> Void) {
        lock.lock()
        let data = packetBuffer.reduce(Data()) { $0 + $1 }
        packetBuffer.removeAll(keepingCapacity: true)
        lock.unlock()
        
        completion(data)
    }
    
    func getStats() -> (upload: Int64, download: Int64) {
        lock.lock()
        let stats = (upload: totalUpload, download: totalDownload)
        lock.unlock()
        return stats
    }
    
    // Метод для сброса статистики
    func resetStats() {
        lock.lock()
        totalUpload = 0
        totalDownload = 0
        lock.unlock()
    }
}
