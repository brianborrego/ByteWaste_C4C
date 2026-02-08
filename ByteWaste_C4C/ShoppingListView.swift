//
//  ShoppingListView.swift
//  ByteWaste_C4C
//

import SwiftUI

struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingAddSheet = false
    @State private var newItemName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }

                if viewModel.hasCompletedItems {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear Completed") {
                            viewModel.clearCompleted()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addItemSheet
            }
            .task {
                await viewModel.loadItems()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            // Active Items Section
            if !viewModel.activeItems.isEmpty {
                Section {
                    ForEach(viewModel.activeItems) { item in
                        ShoppingListItemRow(
                            item: item,
                            onToggle: { viewModel.toggleCompletion(for: item) },
                            onDelete: { viewModel.deleteItem(item) }
                        )
                    }
                }
            }

            // Completed Items Section
            if !viewModel.completedItems.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.completedItems) { item in
                        ShoppingListItemRow(
                            item: item,
                            onToggle: { viewModel.toggleCompletion(for: item) },
                            onDelete: { viewModel.deleteItem(item) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Items Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add items to your shopping list")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Add Item Sheet

    private var addItemSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Item name", text: $newItemName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .font(.headline)

                Spacer()
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newItemName = ""
                        showingAddSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Actions

    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        viewModel.addItem(name: trimmedName)
        newItemName = ""
        showingAddSheet = false
    }
}

// MARK: - Shopping List Item Row

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                if let recipeName = item.sourceRecipeName {
                    Label(recipeName, systemImage: "book")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Delete Button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ShoppingListView()
}
