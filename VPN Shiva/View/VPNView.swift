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
                
            }) {
                Text(viewModel.isConnected ? "Отключить" : "Подключить")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(viewModel.isConnected ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    VPNView()
}
