//
//  ContentView.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PantryView()
                .tabItem { Label("Pantry", systemImage: "cabinet") }
            Text("Recipes (coming soon)")
                .tabItem { Label("Recipes", systemImage: "book") }
            Text("Progress Tab (coming soon)")
                .tabItem { Label("Progress", systemImage: "tree") }
            ShoppingListView()
                .tabItem { Label("Shopping", systemImage: "cart") }
        }
    }
}

#Preview {
    ContentView()
}
