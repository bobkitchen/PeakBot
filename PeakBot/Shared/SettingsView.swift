//
//  SettingsView.swift
//  PeakBot
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey    = KeychainHelper.shared.intervalsApiKey ?? ""
    @State private var athleteID = KeychainHelper.shared.athleteID       ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervals.icu credentials") {
                    TextField("API key",    text: $apiKey)
                    TextField("Athlete ID", text: $athleteID)
                        .keyboardType(.numberPad)
                }

                Button("Save") {
                    KeychainHelper.shared.intervalsApiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    KeychainHelper.shared.athleteID       = athleteID.trimmingCharacters(in: .whitespaces)
                    dismiss()
                }
                .disabled(apiKey.isEmpty || athleteID.isEmpty)
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }}
        }
        .frame(minWidth: 320, minHeight: 180)
    }
}
