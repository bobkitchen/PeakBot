//
//  SettingsView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = KeychainHelper.intervalsApiKey ?? ""
    @State private var athleteID = KeychainHelper.athleteID ?? ""

    var body: some View {
        Form {
            SecureField("Intervals API Key", text: $apiKey)
            TextField("Athlete ID", text: $athleteID)
            HStack {
                Spacer()
                Button("Save") {
                    KeychainHelper.intervalsApiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    KeychainHelper.athleteID      = athleteID.trimmingCharacters(in: .whitespaces)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: 460)
    }
}