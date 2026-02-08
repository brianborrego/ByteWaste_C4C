import SwiftUI

struct PantryView: View {
    @ObservedObject var viewModel: PantryViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isEditMode = false
    @State private var showingProfileSheet = false

    // Category filter state for each storage location
    @State private var selectedCategoryShelf: String? = nil
    @State private var selectedCategoryFridge: String? = nil
    @State private var selectedCategoryFreezer: String? = nil

    private func itemsFor(_ location: StorageLocation) -> [PantryItem] {
        let selectedCategory: String?
        switch location {
        case .shelf:
            selectedCategory = selectedCategoryShelf
        case .fridge:
            selectedCategory = selectedCategoryFridge
        case .freezer:
            selectedCategory = selectedCategoryFreezer
        }

        return viewModel.items
            .filter { $0.storageLocation == location }
            .filter { selectedCategory == nil || $0.category == selectedCategory }
            .sorted { $0.daysUntilExpiration < $1.daysUntilExpiration }
    }

    private func categoriesFor(_ location: StorageLocation) -> [String] {
        let items = viewModel.items.filter { $0.storageLocation == location }
        let categories = Set(items.compactMap { $0.category })
        return categories.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Profile button and Done button bar (no title)
                    HStack {
                        Spacer()

                        if isEditMode {
                            Button("Done") {
                                withAnimation {
                                    isEditMode = false
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.appPrimaryGreen)
                            .cornerRadius(20)
                        } else {
                            // Profile button
                            Button {
                                showingProfileSheet = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.appPrimaryGreen)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading pantry...")
                        Spacer()
                    } else {
                        GeometryReader { geometry in
                            VStack(spacing: 8) {
                                StorageSectionView(
                                    title: "Pantry",
                                    items: itemsFor(.shelf),
                                    isEditMode: isEditMode,
                                    viewModel: viewModel,
                                    availableCategories: categoriesFor(.shelf),
                                    selectedCategory: $selectedCategoryShelf,
                                    onLongPress: { withAnimation(.spring()) { isEditMode = true } }
                                )
                                .frame(height: (geometry.size.height - 16) / 3)

                                StorageSectionView(
                                    title: "Fridge",
                                    items: itemsFor(.fridge),
                                    isEditMode: isEditMode,
                                    viewModel: viewModel,
                                    availableCategories: categoriesFor(.fridge),
                                    selectedCategory: $selectedCategoryFridge,
                                    onLongPress: { withAnimation(.spring()) { isEditMode = true } }
                                )
                                .frame(height: (geometry.size.height - 16) / 3)

                                StorageSectionView(
                                    title: "Freezer",
                                    items: itemsFor(.freezer),
                                    isEditMode: isEditMode,
                                    viewModel: viewModel,
                                    availableCategories: categoriesFor(.freezer),
                                    selectedCategory: $selectedCategoryFreezer,
                                    onLongPress: { withAnimation(.spring()) { isEditMode = true } }
                                )
                                .frame(height: (geometry.size.height - 16) / 3)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadItems()
            }
            .sheet(isPresented: $showingProfileSheet) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

// MARK: - Storage Section View
private struct StorageSectionView: View {
    let title: String
    let items: [PantryItem]
    let isEditMode: Bool
    let viewModel: PantryViewModel
    let availableCategories: [String]
    @Binding var selectedCategory: String?
    let onLongPress: () -> Void

    @State private var showCategoryMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                Spacer()

                // Category filter button (only show if there are categories)
                if !availableCategories.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCategoryMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appIconGray)
                            .rotationEffect(.degrees(showCategoryMenu ? 180 : 0))
                    }
                }
            }
            .padding(.horizontal, 20)

            // Content area - either shows items or category menu
            ZStack {
                // Items list
                if !showCategoryMenu {
                    Group {
                        if items.isEmpty {
                            Text("\(title) is empty!")
                                .font(.subheadline)
                                .foregroundColor(.appIconGray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(items, id: \.id) { item in
                                        ZStack(alignment: .topLeading) {
                                            NavigationLink(destination: PantryItemDetailView(item: item, viewModel: viewModel)) {
                                                PantryItemSquareCard(item: item)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .disabled(isEditMode)
                                            .simultaneousGesture(
                                                LongPressGesture(minimumDuration: 1.0)
                                                    .onEnded { _ in
                                                        onLongPress()
                                                    }
                                            )

                                            // Delete button overlay when in edit mode
                                            if isEditMode {
                                                Button {
                                                    withAnimation {
                                                        viewModel.disposeItem(item, method: .thrownAway)
                                                    }
                                                } label: {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.red)
                                                            .frame(width: 30, height: 30)
                                                        Image(systemName: "minus")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                                .offset(x: 8, y: 8)
                                                .transition(.scale)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .opacity(showCategoryMenu ? 0 : 1)
                    .animation(.easeOut(duration: 0.15), value: showCategoryMenu)
                }

                // Category menu (replaces items when shown)
                if showCategoryMenu {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // "All" option
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCategory = nil
                                    showCategoryMenu = false
                                }
                            } label: {
                                HStack {
                                    Text("All")
                                        .font(.system(size: 18, weight: selectedCategory == nil ? .semibold : .regular))
                                        .foregroundColor(selectedCategory == nil ? .appPrimaryGreen : .black)
                                    Spacer()
                                    if selectedCategory == nil {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.appPrimaryGreen)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedCategory == nil ? Color.appPrimaryGreen.opacity(0.1) : Color.clear)
                            }

                            Divider()
                                .padding(.horizontal, 16)

                            // Category options
                            ForEach(availableCategories, id: \.self) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategory = category
                                        showCategoryMenu = false
                                    }
                                } label: {
                                    HStack {
                                        Text(category)
                                            .font(.system(size: 18, weight: selectedCategory == category ? .semibold : .regular))
                                            .foregroundColor(selectedCategory == category ? .appPrimaryGreen : .black)
                                        Spacer()
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.appPrimaryGreen)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(selectedCategory == category ? Color.appPrimaryGreen.opacity(0.1) : Color.clear)
                                }

                                if category != availableCategories.last {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .opacity(showCategoryMenu ? 1 : 0)
                    .animation(.easeIn(duration: 0.15).delay(0.05), value: showCategoryMenu)
                }
            }
        }
    }
}

// MARK: - Pantry Item Square Card
private struct PantryItemSquareCard: View {
    let item: PantryItem
    private let cardSize: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            // Image area with expiry badge overlay
            ZStack(alignment: .topTrailing) {
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: cardSize, height: cardSize - 34)
                    .clipped()
                } else {
                    Color.appIconGray.opacity(0.15)
                        .frame(width: cardSize, height: cardSize - 34)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(.appIconGray.opacity(0.5))
                        )
                }

                // Expiry badge in top right
                Text(item.isExpired ? "Expired" : item.formattedTimeRemaining)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(item.urgencyColor.opacity(0.9))
                    .cornerRadius(6)
                    .padding(6)
            }

            // Food title
            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            // Status bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 4)

                    Rectangle()
                        .fill(item.amountRemaining > 0.5 ? Color.appPrimaryGreen : item.amountRemaining > 0.25 ? Color.orange : Color.red)
                        .frame(width: geometry.size.width * item.amountRemaining, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(width: cardSize, height: cardSize)
        .background(Color.appWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Pantry Item Detail View
private struct PantryItemDetailView: View {
    let item: PantryItem
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountRemaining: Double
    @State private var showingDisposalAlert = false
    @State private var amountBeforeZero: Double
    @State private var confettiTrigger: Int = 0
    @State private var pointsPopup: PointsPopupData?

    init(item: PantryItem, viewModel: PantryViewModel) {
        self.item = item
        self.viewModel = viewModel
        _amountRemaining = State(initialValue: item.amountRemaining)
        _amountBeforeZero = State(initialValue: item.amountRemaining)
    }

    var body: some View {
        ZStack {
            // Cream background
            Color.appCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Product image at top
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {

                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()      // keeps original aspect ratio
                            } else {
                                Color.gray.opacity(0.2)
                                    .overlay(ProgressView())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipped()
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }

                // Item information
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.linearGradient(
                            colors: [.appGradientTop, .appGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ))

                    if let brand = item.brand {
                        Text(brand)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.appIconGray)
                    }

                    VStack {
                        Text(item.isExpired ? "Expired" : item.formattedTimeRemaining)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(item.isExpired ? .red : item.urgencyColor)
                        Text(item.isExpired ? "Expired" : "Remaining")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appIconGray)
                    }
                    .padding()
                }
                .padding(.horizontal, 16)

                // Amount remaining slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Text("\(Int(amountRemaining * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(amountRemaining > 0.5 ? .green : amountRemaining > 0.25 ? .orange : .red)
                    }

                    Slider(value: $amountRemaining, in: 0...1, step: 0.01)
                        .tint(amountRemaining > 0.5 ? .green : amountRemaining > 0.25 ? .orange : .red)
                        .onChange(of: amountRemaining) { oldValue, newValue in
                            // Update the item in viewModel
                            viewModel.updateItemAmount(item, newAmount: newValue)

                            // If slider reaches 0 and was previously above 0, show disposal alert
                            if newValue == 0 && oldValue > 0 {
                                amountBeforeZero = oldValue  // Capture the value before 0
                                showingDisposalAlert = true
                            }
                        }
                }
                .padding(.horizontal, 16)

                // Done with item button
                Button {
                    // Trigger the disposal alert
                    amountBeforeZero = amountRemaining
                    showingDisposalAlert = true
                } label: {
                    Text("Done with item")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appCream)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PressEffectButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Additional info
                if let category = item.category {
                    Text(category)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.appIconGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                if let notes = item.notes {
                    Text(notes)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.appIconGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                if let sustainabilityNotes = item.sustainabilityNotes, !sustainabilityNotes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.title3)
                            .foregroundColor(.appPrimaryGreen)
                        Text(sustainabilityNotes)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.appIconGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }

                    Spacer()
                }
                .padding(.top)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Item Details")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
        }
        .overlay {
            if showingDisposalAlert {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Cancel on background tap
                        withAnimation(.easeInOut(duration: 0.25)) {
                            amountRemaining = amountBeforeZero
                            viewModel.updateItemAmount(item, newAmount: amountBeforeZero)
                            showingDisposalAlert = false
                        }
                    }

                // Popup card
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 8) {
                        Text("How was this item used?")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        Text("Help us track your sustainability impact")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appIconGray)
                    }

                    // Option buttons
                    VStack(spacing: 12) {
                        DisposalOptionButton(
                            title: "Used Fully",
                            subtitle: "Composted or recycled inedible parts",
                            icon: "checkmark.circle.fill",
                            color: .appPrimaryGreen,
                            isSelected: false
                        ) {
                            // Show confetti and +10 points
                            confettiTrigger += 1
                            pointsPopup = PointsPopupData(points: 10, color: .appSecondaryGreen)

                            // Hide after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                pointsPopup = nil
                            }

                            viewModel.disposeItem(item, method: .usedFully)
                            showingDisposalAlert = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }

                        DisposalOptionButton(
                            title: "Used Partially",
                            subtitle: "Threw away inedible parts",
                            icon: "minus.circle.fill",
                            color: .appDisposalYellow,
                            isSelected: false
                        ) {
                            // Show +5 points (no confetti)
                            pointsPopup = PointsPopupData(points: 5, color: .appSecondaryGreen)

                            // Hide after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                pointsPopup = nil
                            }

                            viewModel.disposeItem(item, method: .usedPartially)
                            showingDisposalAlert = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }

                        DisposalOptionButton(
                            title: "Thrown Away",
                            subtitle: "Item went bad before use",
                            icon: "xmark.circle.fill",
                            color: .appDisposalRed,
                            isSelected: false
                        ) {
                            // Show -10 points in red
                            pointsPopup = PointsPopupData(points: -10, color: .appDisposalRed)

                            // Hide after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                pointsPopup = nil
                            }

                            viewModel.disposeItem(item, method: .thrownAway)
                            showingDisposalAlert = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                    }

                    // Cancel button
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            amountRemaining = amountBeforeZero
                            viewModel.updateItemAmount(item, newAmount: amountBeforeZero)
                            showingDisposalAlert = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appIconGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appCream)
                            .cornerRadius(12)
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingDisposalAlert)
        .overlay {
            // Confetti effect
            ConfettiManager(trigger: $confettiTrigger)
                .allowsHitTesting(false)

            // Points popup
            if let popup = pointsPopup {
                PointsPopupView(data: popup)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Disposal Option Button
struct DisposalOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.appIconGray)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .padding(12)
            .background(Color.appCream.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel

    @State private var name: String = ""
    @State private var additionalContext: String = ""
    @State private var barcode: String = ""
    @State private var showingBarcodeScanner = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?

    // Initial barcode to pre-fill (for barcode-not-found flow)
    var initialBarcode: String?

    init(viewModel: PantryViewModel, initialBarcode: String? = nil) {
        self.viewModel = viewModel
        self.initialBarcode = initialBarcode
        _barcode = State(initialValue: initialBarcode ?? "")
        print("📝 AddPantryItemView initialized with barcode: \(initialBarcode ?? "nil")")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Cream background
                Color.appCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Item Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item Name *")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            ZStack(alignment: .leading) {
                                if name.isEmpty {
                                    Text("Enter food name")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.leading, 4)
                                }
                                TextField("", text: $name)
                                    .foregroundColor(.black)
                                    .textContentType(.none)
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Additional Context
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Context")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $additionalContext)
                                    .foregroundColor(.black)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)

                                if additionalContext.isEmpty {
                                    Text("e.g., organic, 6 count, brand name...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Barcode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Barcode")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            HStack {
                                ZStack(alignment: .leading) {
                                    if barcode.isEmpty {
                                        Text("Scan or enter barcode")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 4)
                                    }
                                    TextField("", text: $barcode)
                                        .foregroundColor(.black)
                                        .keyboardType(.numberPad)
                                }

                                Button {
                                    showingBarcodeScanner = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.title3)
                                        .foregroundColor(.appPrimaryGreen)
                                }
                            }
                            .padding()
                            .cardStyle()
                        }

                        // Photo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photo")
                                .font(.caption)
                                .foregroundStyle(.linearGradient(
                                    colors: [.appGradientTop, .appGradientBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(.horizontal, 16)

                            if let image = selectedImage {
                                HStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Spacer()

                                    Button("Remove") {
                                        selectedImage = nil
                                    }
                                    .foregroundColor(.red)
                                }
                                .padding()
                                .cardStyle()
                            } else {
                                HStack(spacing: 12) {
                                    Button {
                                        showingCamera = true
                                    } label: {
                                        Label("Take Photo", systemImage: "camera")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appPrimaryGreen)

                                    Button {
                                        showingImagePicker = true
                                    } label: {
                                        Label("Library", systemImage: "photo")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appPrimaryGreen)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if viewModel.isAnalyzing {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Add Item Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isAnalyzing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addItem()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalyzing)
                    .foregroundColor(.appPrimaryGreen)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                ManualEntryBarcodeScannerView(scannedBarcode: $barcode)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
        }
    }

    private func addItem() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert UIImage to URL if needed (for now, we'll skip upload and just use nil)
        let imageURL: String? = nil  // TODO: Upload image to storage and get URL

        await viewModel.addFromManualEntry(
            name: trimmedName,
            additionalContext: trimmedContext,
            barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode,
            imageURL: imageURL
        )
    }
}


// MARK: - Manual Entry Barcode Scanner
private struct ManualEntryBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var scannedBarcode: String
    @State private var hasScannedOnce = false

    var body: some View {
        BarcodeScannerView { barcode in
            guard !hasScannedOnce else { return }
            hasScannedOnce = true
            scannedBarcode = barcode
            dismiss()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Press Effect Button Style
struct PressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Points Popup Data
struct PointsPopupData {
    let points: Int
    let color: Color
}

// MARK: - Points Popup View
struct PointsPopupView: View {
    let data: PointsPopupData
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(data.color)

            Text("\(data.points > 0 ? "+" : "")\(data.points)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(data.color)

            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(data.color)
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 2.0)) {
                offset = -150
                opacity = 0
            }
        }
    }
}

#Preview {
    PantryView(viewModel: PantryViewModel())
        .environmentObject(AuthViewModel())
}
