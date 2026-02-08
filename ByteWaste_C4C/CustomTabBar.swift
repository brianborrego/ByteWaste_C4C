//
//  CustomTabBar.swift
//  ByteWaste_C4C
//
//  Custom bottom navigation bar with centered add button
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case pantry = 0
    case recipes = 1
    case shopping = 2
    case sustainability = 3

    var icon: String {
        switch self {
        case .pantry:
            return "cabinet.fill"
        case .recipes:
            return "book.fill"
        case .shopping:
            return "cart.fill"
        case .sustainability:
            return "leaf.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Binding var showAddMenu: Bool
    let onScanTapped: () -> Void
    let onManualAddTapped: () -> Void

    var body: some View {
        ZStack {
            // Main tab bar - floating icons with no background
            HStack(spacing: 0) {
                // Left tabs (Pantry, Recipes)
                TabBarButton(tab: .pantry, selectedTab: $selectedTab)
                TabBarButton(tab: .recipes, selectedTab: $selectedTab)

                // Spacer for the plus button
                Spacer()
                    .frame(width: 120)

                // Right tabs (Shopping, Sustainability)
                TabBarButton(tab: .shopping, selectedTab: $selectedTab)
                TabBarButton(tab: .sustainability, selectedTab: $selectedTab)
            }
            .padding(.horizontal, 30)
            .frame(height: 70)
            .offset(y: -10)

            // Centered plus button
            VStack {
                Spacer()
                ZStack {
                    // Plus button (much larger)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showAddMenu.toggle()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimaryGreen)
                                .frame(width: 76, height: 76)
                                .shadow(color: Color.appPrimaryGreen.opacity(0.4), radius: 12, x: 0, y: 6)

                            Image(systemName: showAddMenu ? "xmark" : "plus")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(showAddMenu ? 90 : 0))
                        }
                    }
                    .offset(y: -32)

                    // Expanded menu
                    if showAddMenu {
                        VStack(spacing: 12) {
                            AddMenuButton(
                                icon: "barcode.viewfinder",
                                title: "Scan",
                                color: .appPrimaryGreen
                            ) {
                                print("🔍 Scan button tapped")
                                withAnimation {
                                    showAddMenu = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("🔍 Calling onScanTapped()")
                                    onScanTapped()
                                }
                            }

                            AddMenuButton(
                                icon: "plus.circle.fill",
                                title: "Add Manually",
                                color: .appPrimaryGreen
                            ) {
                                print("➕ Add Manually button tapped")
                                withAnimation {
                                    showAddMenu = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("➕ Calling onManualAddTapped()")
                                    onManualAddTapped()
                                }
                            }
                        }
                        .padding(.bottom, 120)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .frame(height: 80)
    }
}

// MARK: - Tab Bar Button
private struct TabBarButton: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 24))
                .foregroundColor(selectedTab == tab ? .appPrimaryGreen : .appIconGray)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Add Menu Button
private struct AddMenuButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(12)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    CustomTabBar(
        selectedTab: .constant(.pantry),
        showAddMenu: .constant(false),
        onScanTapped: {},
        onManualAddTapped: {}
    )
}
