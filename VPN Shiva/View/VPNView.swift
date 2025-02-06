//
//  VPNView.swift
//  VPN Shiva
//
//  Created by Anton Rasen on 30.01.2025.
//

import SwiftUI

struct VPNView: View {
    @StateObject private var viewModel = VPNViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.isConnected ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 60))
                .foregroundColor(viewModel.isConnected ? .green : .red)
            
            Text(viewModel.connectionStatus)
                .font(.headline)
            
            Button(action: {
                viewModel.toggleConnection()
            }) {
                Text(viewModel.isConnected ? "Отключить" : "Подключить")
                    .foregroundColor(.white)
                    .padding()
                    .background(viewModel.isConnected ? Color.red : Color.green)
                    .cornerRadius(10)
            }
            .disabled(viewModel.connectionStatus == "Подключение..." ||
                     viewModel.connectionStatus == "Отключение...")
            
            
            // Добавляем отображение статистики
                        if viewModel.isConnected {
                            VStack(spacing: 10) {
                                Text("Статистика:")
                                    .font(.headline)
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("\(formatBytes(viewModel.connectionStats.download))")
                                    }
                                    
                                    VStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("\(formatBytes(viewModel.connectionStats.upload))")
                                    }
                                }
                            }
                            .padding(.top)
                        }
                    }
                    .padding()
                }
                
                private func formatBytes(_ bytes: Int) -> String {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
                    formatter.countStyle = .file
                    return formatter.string(fromByteCount: Int64(bytes))
                }
            }

#Preview {
    VPNView()
}
