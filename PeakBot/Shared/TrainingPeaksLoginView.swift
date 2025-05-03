// TrainingPeaksLoginView.swift
// PeakBot
//
// Secure TrainingPeaks login using TPConnector

import SwiftUI
import AppKit

struct TrainingPeaksLoginView: View {
    let onLoginSuccess: () -> Void
    let onLoginFailure: (String) -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var status = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Connect TrainingPeaks") {
                TPConnector.shared.saveCredentials(email: email, password: password)
                Task {
                    do {
                        try await TPConnector.shared.syncLatest()
                        status = "Sync started!"
                        onLoginSuccess()
                    } catch {
                        status = "Error: \(error.localizedDescription)"
                        onLoginFailure("Error: \(error.localizedDescription)")
                    }
                }
            }
            Text(status)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 200)
    }
}
