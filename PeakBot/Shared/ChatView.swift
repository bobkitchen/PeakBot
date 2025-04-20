//
//  ChatView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

/// Simple chat UI shell (placeholder)
struct ChatView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message")
                .font(.system(size: 64))
            Text("Chat")
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }
}