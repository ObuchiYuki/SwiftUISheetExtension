//
//  ClosabilityExample.swift
//  SwiftUISheetExtension
//
//  Created by yuki on 2025/01/05.
//

import SwiftUI

struct RootScreen: View {
    @State private var isPresented = false
    
    var body: some View {
        Button("Show Sheet") {
            self.isPresented.toggle()
        }
        .sheet_(isPresented: $isPresented) {
            SheetScreen()
        }
    }
}

enum Closability {
    case none
    case confirmation
    case enabled
}

struct SheetScreen: View {
    @Environment(\.dismissSheet) private var dismissSheet
    
    @State private var closability = Closability.none
    
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
                .ignoresSafeArea()
            
            VStack {
                Text("Closability")
                    .font(.headline)
                    .padding()
                
                Picker("Closability", selection: $closability) {
                    Text("None").tag(Closability.none)
                    Text("Confirmation").tag(Closability.confirmation)
                    Text("Enabled").tag(Closability.enabled)
                }
                .pickerStyle(.segmented)
                
                Group {
                    switch self.closability {
                    case .none:
                        Text("You cannot close this sheet.")
                    case .confirmation:
                        Text("You can close this sheet with confirmation.")
                    case .enabled:
                        Text("You can close this sheet instantly.")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            }
            .padding()
        }
        .interactiveDismissDisabled(
            self.closability == .none || self.closability == .confirmation
        )
        .onInteractiveDismissAttempt_ {
            if self.closability == .confirmation {
                self.showAlert = true
            }
        }
        .alert("Do you want to close?", isPresented: self.$showAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Close", role: .destructive) {
                self.dismissSheet()
            }
        }
    }
}

#Preview{
    RootScreen()
}
