//
//  ContentView.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var pantryViewModel = PantryViewModel()
    @StateObject private var recipeViewModel = RecipeViewModel()
    @State private var selectedTab: AppTab = .pantry
    @State private var showAddMenu = false
    @State private var triggerShoppingAdd = false

    var body: some View {
        ZStack {
            // Persistent cream background (prevents flashing)
            Color.appCream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab content with smoother transition
                ZStack {
                    if selectedTab == .pantry {
                        PantryView(viewModel: pantryViewModel)
                            .transition(.opacity)
                    } else if selectedTab == .recipes {
                        RecipeListView(viewModel: recipeViewModel)
                            .transition(.opacity)
                    } else if selectedTab == .shopping {
                        ShoppingListView(triggerAdd: $triggerShoppingAdd)
                            .transition(.opacity)
                    } else if selectedTab == .sustainability {
                        ProgressTreeView()
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
                    },
                    onShoppingAddTapped: {
                        print("🛒 ContentView: Switching to shopping tab and triggering add")
                        selectedTab = .shopping
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            triggerShoppingAdd = true
                        }
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
        .onChange(of: selectedTab) { _, _ in
            // Close add menu when switching tabs
            if showAddMenu {
                withAnimation {
                    showAddMenu = false
                }
            }
        }
        .onChange(of: pantryViewModel.items) { _, newItems in
            Task {
                await recipeViewModel.generateRecipesIfNeeded(pantryItems: newItems)
            }
        }
        .onAppear {
            // Wire pantry callbacks to recipe generation/pruning
            pantryViewModel.onItemAdded = { items in
                Task { await recipeViewModel.generateRecipesIfNeeded(pantryItems: items) }
            }

            pantryViewModel.onItemsRemoved = { items in
                Task { await recipeViewModel.pruneRecipesIfNeeded(remainingPantryItems: items) }
            }

            // Let RecipeViewModel access current pantry items (for refresh/regeneration)
            recipeViewModel.pantryItemsProvider = { pantryViewModel.items }
        }
        .task {
            await pantryViewModel.loadItems()
            await recipeViewModel.loadRecipes()
        }
    }
}

#Preview {
    ContentView()
}
