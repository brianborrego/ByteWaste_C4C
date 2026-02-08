//
//  ContentView.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .pantry
    @State private var showAddMenu = false
    @StateObject private var pantryViewModel = PantryViewModel()

    var body: some View {
        ZStack {
            // Persistent cream background (prevents flashing)
            Color.appCream.ignoresSafeArea()

            // Main content area
            VStack(spacing: 0) {
                // Tab content with smoother transition
                ZStack {
                    if selectedTab == .pantry {
                        PantryView(viewModel: pantryViewModel)
                            .transition(.opacity)
                    } else if selectedTab == .recipes {
                        RecipesPlaceholderView()
                            .transition(.opacity)
                    } else if selectedTab == .shopping {
                        ShoppingListView()
                            .transition(.opacity)
                    } else if selectedTab == .sustainability {
                        SustainabilityView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selectedTab)

                Spacer(minLength: 0)
            }

            // Dim background when add menu is open (MUST be before tab bar in Z-order)
            if showAddMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showAddMenu = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Custom tab bar overlay (MUST be on top with higher zIndex)
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: $selectedTab,
                    showAddMenu: $showAddMenu,
                    onScanTapped: {
                        print("📸 ContentView: Setting isPresentingScannerSheet = true")
                        pantryViewModel.isPresentingScannerSheet = true
                        print("📸 ContentView: isPresentingScannerSheet = \(pantryViewModel.isPresentingScannerSheet)")
                    },
                    onManualAddTapped: {
                        print("✏️ ContentView: Setting isPresentingAddSheet = true")
                        pantryViewModel.isPresentingAddSheet = true
                        print("✏️ ContentView: isPresentingAddSheet = \(pantryViewModel.isPresentingAddSheet)")
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .zIndex(2)
        }
        // Add sheets here so they respond to state changes
        .sheet(isPresented: $pantryViewModel.isPresentingAddSheet) {
            print("📋 Sheet presenting: AddPantryItemView")
            return AddPantryItemView(
                viewModel: pantryViewModel,
                initialBarcode: pantryViewModel.barcodeForManualEntry
            )
        }
        .onChange(of: pantryViewModel.isPresentingAddSheet) { oldValue, newValue in
            print("📋 isPresentingAddSheet changed: \(oldValue) -> \(newValue)")
            if !newValue {
                pantryViewModel.barcodeForManualEntry = nil
            }
        }
        .sheet(isPresented: $pantryViewModel.isPresentingScannerSheet) {
            print("📸 Sheet presenting: RealtimeCameraView")
            return RealtimeCameraView(viewModel: pantryViewModel)
        }
        .onChange(of: pantryViewModel.isPresentingScannerSheet) { oldValue, newValue in
            print("📸 isPresentingScannerSheet changed: \(oldValue) -> \(newValue)")
        }
    }
}

// MARK: - Placeholder Views
private struct RecipesPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.appCream.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.appPrimaryGreen)

                Text("Recipes")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
