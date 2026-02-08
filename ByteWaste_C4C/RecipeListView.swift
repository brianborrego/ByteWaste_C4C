//
//  RecipeListView.swift
//  ByteWaste_C4C
//
//  Recipe list + detail views
//

import SwiftUI

struct RecipeListView: View {
    @ObservedObject var viewModel: RecipeViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.recipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Recipes Yet")
                            .font(.headline)
                        Text("Add items to your pantry to discover recipes using your ingredients")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    ZStack {
                        List {
                            ForEach(viewModel.recipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                    RecipeRowView(recipe: recipe)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.deleteRecipe(viewModel.recipes[index])
                                }
                            }
                        }
                        .listStyle(.plain)

                        // Loading overlay when generating new recipes
                        if viewModel.isGenerating {
                            ZStack {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()

                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.3)
                                    Text("Finding recipes...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadRecipes()
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
}

// MARK: - Recipe Row View

struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            // Recipe image
            if let imageURL = recipe.image, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .clipped()
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 32))
                    .frame(width: 80, height: 80)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .foregroundColor(.gray)
            }

            // Recipe info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.label)
                    .font(.headline)
                    .lineLimit(2)

                Text(recipe.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Time badge
                if let totalTime = recipe.totalTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(recipe.formattedTime)
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }

                // Pantry match indicator
                if !recipe.pantryItemsUsed.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("\(recipe.pantryItemsUsed.count) ingredients")
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                }
            }

            Spacer()

            // Source indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.openURL) var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero image
                if let imageURL = recipe.image, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            ProgressView()
                                .frame(height: 250)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .background(Color(.systemGray6))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 250)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(recipe.label)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Metadata
                    HStack(spacing: 16) {
                        if let yield = recipe.yield {
                            VStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                Text("\(yield)")
                                    .font(.caption)
                            }
                        }

                        if let totalTime = recipe.totalTime {
                            VStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text(recipe.formattedTime)
                                    .font(.caption)
                            }
                        }

                        if let source = recipe.sourcePublisher {
                            VStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .foregroundColor(.green)
                                Text(source)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }

                    Divider()

                    // Ingredients
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredients")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(recipe.ingredientLines, id: \.self) { ingredient in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                        .font(.caption)

                                    Text(ingredient)
                                        .font(.body)
                                        .lineLimit(2)

                                    Spacer()
                                }
                            }
                        }
                    }

                    Divider()

                    // Pantry items used
                    if !recipe.pantryItemsUsed.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Pantry Items Used")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(recipe.pantryItemsUsed, id: \.self) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)

                                        Text(item)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Spacer()
                                    }
                                }
                            }
                        }

                        Divider()
                    }

                    // View Full Recipe button
                    if let sourceUrl = recipe.sourceUrl, let url = URL(string: sourceUrl) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("View Full Recipe")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    RecipeListView(
        viewModel: {
            let vm = RecipeViewModel()
            vm.recipes = [
                Recipe(
                    label: "Chicken Fried Rice",
                    image: "https://edamam-product-images.s3.amazonaws.com/web-prod/d1e4d60f87a0a4f08ca5f9f6f988ebf3",
                    sourceUrl: "https://example.com/recipe",
                    sourcePublisher: "BBC Good Food",
                    yield: 4,
                    totalTime: 30,
                    ingredientLines: ["2 chicken breasts", "3 cups cooked rice", "2 eggs"],
                    pantryItemsUsed: ["chicken", "rice"],
                    generatedFrom: ["chicken", "rice", "eggs"]
                )
            ]
            return vm
        }()
    )
}
