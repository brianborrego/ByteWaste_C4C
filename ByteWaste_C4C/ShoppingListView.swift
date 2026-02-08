//
//  ShoppingListView.swift
//  ByteWaste_C4C
//

import SwiftUI
import Foundation

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isCompleted: Bool
    let dateAdded: Date
    var sourceRecipeId: String?
    var sourceRecipeName: String?
    var imageURL: String?
    var userId: UUID?

    // Map Swift camelCase to DB snake_case columns
    enum CodingKeys: String, CodingKey {
        case id, name
        case isCompleted = "is_completed"
        case dateAdded = "date_added"
        case sourceRecipeId = "source_recipe_id"
        case sourceRecipeName = "source_recipe_name"
        case imageURL = "image_url"
        case userId = "user_id"
    }

    init(
        id: UUID = UUID(),
        name: String,
        isCompleted: Bool = false,
        dateAdded: Date = Date(),
        sourceRecipeId: String? = nil,
        sourceRecipeName: String? = nil,
        imageURL: String? = nil,
        userId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
        self.dateAdded = dateAdded
        self.sourceRecipeId = sourceRecipeId
        self.sourceRecipeName = sourceRecipeName
        self.imageURL = imageURL
        self.userId = userId
    }
}


struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingAddSheet = false
    @State private var newItemName = ""
    @Binding var triggerAdd: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Cream background
                Color.appCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom gradient title with buttons
                    HStack {
                        Text("Grocery List")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        Spacer()

                        if viewModel.hasCompletedItems {
                            Button("Clear") {
                                viewModel.clearCompleted()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(16)
                        }

                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.appPrimaryGreen)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    } else if viewModel.items.isEmpty {
                        emptyStateView
                    } else {
                        listView
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if showingAddSheet {
                    addItemPopup
                }
            }
            .task {
                await viewModel.loadItems()
            }
            .onChange(of: triggerAdd) { _, newValue in
                if newValue {
                    showingAddSheet = true
                    triggerAdd = false
                }
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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteItem(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }

            // Completed Items Section
            if !viewModel.completedItems.isEmpty {
                Section {
                    ForEach(viewModel.completedItems) { item in
                        ShoppingListItemRow(
                            item: item,
                            onToggle: { viewModel.toggleCompletion(for: item) },
                            onDelete: { viewModel.deleteItem(item) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteItem(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                } header: {
                    Text("Completed")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.linearGradient(
                            colors: [.appGradientTop, .appGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundColor(.appIconGray.opacity(0.5))

            Text("No Items Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.appIconGray)

            Text("Add items to your shopping list")
                .font(.subheadline)
                .foregroundColor(.appIconGray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPrimaryGreen)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        return Spacer()
    }

    // MARK: - Add Item Popup

    private var addItemPopup: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    newItemName = ""
                    showingAddSheet = false
                }

            // Centered popup dialog
            VStack(spacing: 0) {
                // Header
                Text("Add Item")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                // Text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appIconGray)
                        .padding(.leading, 4)

                    ZStack(alignment: .leading) {
                        if newItemName.isEmpty {
                            Text("Enter item name")
                                .foregroundColor(.appPrimaryGreen.opacity(0.6))
                                .padding(.leading, 16)
                        }
                        TextField("", text: $newItemName)
                            .textFieldStyle(.plain)
                            .foregroundColor(.black)
                            .padding(12)
                    }
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Divider
                Divider()

                // Buttons
                HStack(spacing: 0) {
                    // Cancel button
                    Button {
                        newItemName = ""
                        showingAddSheet = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.appIconGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    Divider()
                        .frame(height: 44)

                    // Add button
                    Button {
                        addItem()
                    } label: {
                        Text("Add")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.appPrimaryGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
                }
            }
            .frame(width: 300)
            .background(Color.appCream)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showingAddSheet)
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
                    .foregroundStyle(item.isCompleted ? Color.appPrimaryGreen : Color.appIconGray.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Product Image
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appIconGray.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "cart")
                            .font(.system(size: 20))
                            .foregroundColor(.appIconGray.opacity(0.5))
                    )
            }

            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .appIconGray.opacity(0.6) : .black)

                if let recipeName = item.sourceRecipeName {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 11))
                        Text(recipeName)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.appIconGray.opacity(0.7))
                }
            }

            Spacer()

            // Delete Button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cardStyle()
        .opacity(item.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    ShoppingListView(triggerAdd: .constant(false))
}
