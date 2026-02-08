import SwiftUI

struct TreeViewRepresentable: UIViewRepresentable {
    let growth: CGFloat
    let animate: Bool

    func makeUIView(context: Context) -> TreeView {
        TreeView()
    }

    func updateUIView(_ uiView: TreeView, context: Context) {
        if animate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.animateToGrowth(growth)
            }
        }
    }
}

struct ProgressTreeView: View {
    @State private var level: Int = UserDefaults.standard.integer(forKey: "treeLevel")
    @State private var sustainabilityPoints: Int = UserDefaults.standard.integer(forKey: "sustainabilityPoints")
    @State private var shouldAnimate = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background image
                Image("TreeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        // Sustainability counter in top left
                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#405C2C"))  // Dark green

                            Text("\(sustainabilityPoints)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .padding(.leading, 20)

                        Spacer()
                    }
                    .padding(.top, 20)

                    Text("\(level) / 10")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .padding(.top, 10)

                    TreeViewRepresentable(
                        growth: growthValue(level: level),
                        animate: shouldAnimate
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    // Buttons just above the tab bar
                    HStack {
                        Button {
                            if sustainabilityPoints < 100 {
                                sustainabilityPoints += 10
                                UserDefaults.standard.set(sustainabilityPoints, forKey: "sustainabilityPoints")
                                // Update level based on points
                                level = sustainabilityPoints / 10
                                UserDefaults.standard.set(level, forKey: "treeLevel")
                            }
                        } label: {
                            Label("Add Points", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 15)
                                .background(.green.opacity(0.85))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .disabled(sustainabilityPoints >= 100)

                        Spacer()

                        Button {
                            sustainabilityPoints = 0
                            level = 0
                            UserDefaults.standard.set(0, forKey: "sustainabilityPoints")
                            UserDefaults.standard.set(0, forKey: "treeLevel")
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 15)
                                .background(.red.opacity(0.75))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Load sustainability points and calculate level
                sustainabilityPoints = UserDefaults.standard.integer(forKey: "sustainabilityPoints")
                level = sustainabilityPoints / 10
                // Sync level with calculated value
                UserDefaults.standard.set(level, forKey: "treeLevel")

                shouldAnimate = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    shouldAnimate = true
                }
            }
            .onDisappear {
                shouldAnimate = false
            }
        }
    }
}

#Preview {
    ProgressTreeView()
}
