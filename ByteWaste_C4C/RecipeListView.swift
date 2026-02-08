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
            ZStack {
                // Cream background
                Color.appCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom gradient title
                    HStack {
                        Text("Recipes")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading recipes...")
                        Spacer()
                    } else if viewModel.recipes.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.appIconGray.opacity(0.5))
                            Text("No Recipes Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.appIconGray)
                            Text("Add items to your pantry to discover recipes using your ingredients.\nPull down to refresh.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.appIconGray.opacity(0.7))
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        ZStack {
                            List {
                                ForEach(viewModel.recipes) { recipe in
                                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                        RecipeRowView(recipe: recipe)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        viewModel.deleteRecipe(viewModel.recipes[index])
                                    }
                                }
                            }
                            .refreshable {
                                await viewModel.refreshRecipes()
                            }
                            .tint(.black) // Darker refresh spinner
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)

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
                                    .background(Color.appCream)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
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
                            .foregroundColor(.appIconGray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appIconGray.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundColor(.appIconGray.opacity(0.5))
                    )
            }

            // Recipe info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text(recipe.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.appIconGray)

                // Pantry match indicator
                if !recipe.pantryItemsUsed.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("\(recipe.pantryItemsUsed.count) ingredients")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.appPrimaryGreen)
                }
            }

            Spacer()

            // Source indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.appIconGray.opacity(0.5))
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.openURL) var openURL

    var body: some View {
        ZStack {
            // Cream background
            Color.appCream.ignoresSafeArea()

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
                                    .foregroundColor(.appIconGray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 250)
                                    .background(Color.appIconGray.opacity(0.15))
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
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        // Metadata
                        HStack(spacing: 16) {
                            if let yield = recipe.yield {
                                VStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.appPrimaryGreen)
                                    Text("\(yield)")
                                        .font(.caption)
                                        .foregroundColor(.appIconGray)
                                }
                            }

                            if let source = recipe.sourcePublisher {
                                VStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.appPrimaryGreen)
                                    Text(source)
                                        .font(.caption)
                                        .foregroundColor(.appIconGray)
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
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(recipe.ingredientLines, id: \.self) { ingredient in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.appPrimaryGreen)
                                            .font(.caption)

                                        Text(ingredient)
                                            .font(.body)
                                            .foregroundColor(.black)
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
                                    .foregroundStyle(.linearGradient(
                                        colors: [.appGradientTop, .appGradientBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(recipe.pantryItemsUsed, id: \.self) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)

                                            Text(item)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.black)

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
                                .background(Color.appPrimaryGreen)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Recipe Details")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
        }
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
