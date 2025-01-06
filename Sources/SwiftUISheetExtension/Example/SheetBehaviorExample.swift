//
//  SheetBehaviorExample.swift
//  SwiftUISheetExtension
//
//  Created by yuki on 2025/01/06.
//

import SwiftUI

struct IdentifiableString: Identifiable {
    var id: String { self.content }
    
    let content: String
}

/// The sheet is displayed again when `item` is changed.
struct RootView: View {
    @State var builtin: IdentifiableString? = nil
    @State var library: IdentifiableString? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Sheet Behavior - item update")
                .font(.title)
            
            Button("Show Sheet (builtin)") {
                self.builtin = IdentifiableString(content: "Item 1")
            }
            .sheet_(item: self.$builtin) { item in
                VStack {
                    Text(item.content)
                    
                    if item.content != "Item 2" {
                        Button("Show Another Sheet") {
                            self.builtin = IdentifiableString(content: "Item 2")
                            self.builtin = IdentifiableString(content: "Item 3")
                        }
                    }
                }
            }
            
            Button("Show Sheet (library)") {
                self.library = IdentifiableString(content: "Item 1")
            }
            .sheet_(item: self.$library) { item in
                VStack {
                    Text(item.content)
                    
                    if item.content != "Item 2" {
                        Button("Show Another Sheet") {
                            self.library = IdentifiableString(content: "Item 2")
                            self.library = IdentifiableString(content: "Item 3")
                        }
                    }
                }
            }
            
        }
    }
}

#Preview {
    RootView()
}

