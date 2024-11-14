//
//  InfoView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI

struct InfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Retrieve the build version and version number
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("About BioPulse")
                    .font(.largeTitle)
                    .padding()
                
                // Additional Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Created by: Connor Frank")
                        .font(.title3)
                    
                    Text("Build: \(appVersion) (\(buildNumber))") // Display version and build
                        .font(.title3)
                }
                .padding(.top, 10)
                
                // GitHub Button
                Button(action: {
                    if let url = URL(string: "https://github.com/conjfrnk/biopulse") { // Replace with your GitHub link
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.slash.chevron.right") // GitHub/source control logo
                        Text("View on GitHub")
                    }
                    .font(.title3)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss() // Dismiss the view
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.blue) // Customize the color
                    }
                }
            }
        }
    }
}
