//
//  SettingsView.swift
//  PeakBot
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey    = KeychainHelper.intervalsApiKey ?? ""
    @State private var athleteID = KeychainHelper.athleteID       ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Intervals.icu credentials")) {
                    TextField("API key",    text: $apiKey)
                    TextField("Athlete ID", text: $athleteID)
                }

                Button("Save") {
                    KeychainHelper.intervalsApiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    KeychainHelper.athleteID       = athleteID.trimmingCharacters(in: .whitespaces)
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
