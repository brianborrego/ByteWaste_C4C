import SwiftUI

struct ForestPine: Codable, Identifiable {
    let id: UUID
    let hillLayer: Int  // 1-6, where 1 is closest/darkest, 6 is furthest/lightest
    let pineNumber: Int  // 1-6, which pine image to use
    let shouldFlip: Bool  // Random y-axis flip for variety
    let xPosition: CGFloat  // 0.0 to 1.0 (fraction of screen width)
    let yPosition: CGFloat  // 0.5 to 1.0 (fraction of screen height)

    var scale: CGFloat {
        // Hill 1 (closest/darkest): 0.50 scale (~600px if source is 1200px)
        // Each hill back gets progressively smaller, but more gradually
        switch hillLayer {
        case 1: return 0.50  // Closest - full size (2x original)
        case 2: return 0.45  // Very close in size
        case 3: return 0.40  // Gradual decrease
        case 4: return 0.35  // Mid-distance
        case 5: return 0.30  // Further back
        case 6: return 0.25  // Furthest - still visible (5x original!)
        default: return 0.40
        }
    }

    var zIndex: Double {
        // Lower hill number = closer = higher z-index
        // Hill 1 is in front, Hill 6 is in back
        return Double(7 - hillLayer)
    }

    var imageName: String {
        return "pine\(pineNumber)"
    }

    init() {
        self.id = UUID()
        // Randomly choose a hill layer (1-6)
        self.hillLayer = Int.random(in: 1...6)
        // Randomly choose a pine image (1-6)
        self.pineNumber = Int.random(in: 1...6)
        // Random y-axis flip (50% chance)
        self.shouldFlip = Bool.random()

        // Random x position across full width (avoid extreme edges)
        self.xPosition = CGFloat.random(in: 0.15...0.85)

        // Y position depends on hill layer (closer hills are lower on screen)
        switch self.hillLayer {
        case 1: // Darkest/closest hill
            self.yPosition = CGFloat.random(in: 0.75...0.82)
        case 2:
            self.yPosition = CGFloat.random(in: 0.68...0.75)
        case 3:
            self.yPosition = CGFloat.random(in: 0.62...0.68)
        case 4:
            self.yPosition = CGFloat.random(in: 0.56...0.62)
        case 5:
            self.yPosition = CGFloat.random(in: 0.52...0.56)
        case 6: // Lightest/furthest hill
            self.yPosition = CGFloat.random(in: 0.48...0.52)
        default:
            self.yPosition = CGFloat.random(in: 0.55...0.75)
        }
    }
}

struct TreeViewRepresentable: UIViewRepresentable {
    let growth: CGFloat
    let animate: Bool
    let scale: CGFloat  // Default 1.0, use 0.33 for background trees

    init(growth: CGFloat, animate: Bool, scale: CGFloat = 1.0) {
        self.growth = growth
        self.animate = animate
        self.scale = scale
    }

    func makeUIView(context: Context) -> TreeView {
        TreeView()
    }

    func updateUIView(_ uiView: TreeView, context: Context) {
        if animate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.animateToGrowth(growth)
            }
        } else {
            // For non-animating trees (forest trees), draw immediately without animation
            uiView.animateToGrowth(growth)
        }
    }
}

struct ProgressTreeView: View {
    @State private var level: Int = UserDefaults.standard.integer(forKey: "treeLevel")
    @State private var sustainabilityPoints: Int = UserDefaults.standard.integer(forKey: "sustainabilityPoints")
    @State private var shouldAnimate = false
    @State private var forestPines: [ForestPine] = []

    // Load forest pines from UserDefaults
    private func loadForestPines() -> [ForestPine] {
        guard let data = UserDefaults.standard.data(forKey: "forestPines"),
              let pines = try? JSONDecoder().decode([ForestPine].self, from: data) else {
            return []
        }
        return pines
    }

    // Save forest pines to UserDefaults
    private func saveForestPines() {
        if let encoded = try? JSONEncoder().encode(forestPines) {
            UserDefaults.standard.set(encoded, forKey: "forestPines")
        }
    }

    // Add a new pine to the forest
    private func addPineToForest() {
        let newPine = ForestPine()
        forestPines.append(newPine)
        saveForestPines()
        print("🌲 Added pine to forest! Total pines: \(forestPines.count)")
        print("   Pine details: Hill \(newPine.hillLayer), pine\(newPine.pineNumber), flipped: \(newPine.shouldFlip), x: \(newPine.xPosition), y: \(newPine.yPosition), scale: \(newPine.scale)")
    }

    // Helper to load pine image with multiple fallback methods
    private func loadPineImage(_ imageName: String) -> UIImage? {
        // Try 1: Asset catalog with folder prefix
        if let image = UIImage(named: "pines/\(imageName)") {
            print("✅ Loaded image: pines/\(imageName)")
            return image
        }

        // Try 2: Asset catalog without folder prefix
        if let image = UIImage(named: imageName) {
            print("✅ Loaded image: \(imageName)")
            return image
        }

        // Try 3: Bundle resource with .png extension
        if let path = Bundle.main.path(forResource: imageName, ofType: "png", inDirectory: "pines"),
           let image = UIImage(contentsOfFile: path) {
            print("✅ Loaded image from bundle: pines/\(imageName).png")
            return image
        }

        // Try 4: Bundle resource without directory
        if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            print("✅ Loaded image from bundle: \(imageName).png")
            return image
        }

        print("❌ Failed to load image: \(imageName)")
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background image
                Image("TreeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                // Forest pines layer with proper z-ordering
                GeometryReader { geometry in
                    ForEach(forestPines) { pine in
                        Group {
                            // Try multiple approaches to load the image
                            if let uiImage = loadPineImage(pine.imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(x: pine.shouldFlip ? -pine.scale : pine.scale, y: pine.scale)
                                    .frame(height: geometry.size.height * pine.scale)
                                    .position(
                                        x: geometry.size.width * pine.xPosition,
                                        y: geometry.size.height * pine.yPosition
                                    )
                                    .opacity(pine.hillLayer == 1 ? 0.9 : 0.7)  // Closer trees less transparent
                                    .zIndex(pine.zIndex)  // Proper layering
                            } else {
                                // Fallback: show a placeholder if image not found
                                Text("🌲")
                                    .font(.system(size: 50))
                                    .scaleEffect(x: pine.shouldFlip ? -pine.scale : pine.scale, y: pine.scale)
                                    .position(
                                        x: geometry.size.width * pine.xPosition,
                                        y: geometry.size.height * pine.yPosition
                                    )
                                    .opacity(pine.hillLayer == 1 ? 0.9 : 0.7)
                                    .zIndex(pine.zIndex)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
                .zIndex(1)  // Forest layer behind main tree

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
                    .zIndex(100)  // UI elements on top

                    Text("\(level) / 10")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.linearGradient(
                            colors: [.appGradientTop, .appGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .padding(.top, 10)
                        .zIndex(100)  // UI elements on top

                    TreeViewRepresentable(
                        growth: growthValue(level: level),
                        animate: shouldAnimate
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .zIndex(10)  // Main tree in front of forest trees

                    // Buttons just above the tab bar (dev mode only)
                    if Config.isDevMode {
                        // Forest pine count display
                        Text("Forest Pines: \(forestPines.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.bottom, 8)

                        HStack {
                            Button {
                                sustainabilityPoints += 10

                                // Check if we EXCEEDED 100 (not just reached it)
                                if sustainabilityPoints > 100 {
                                    // Add a pine to the forest
                                    addPineToForest()
                                    // Wrap around to remainder
                                    sustainabilityPoints = sustainabilityPoints % 100
                                    if sustainabilityPoints == 0 {
                                        sustainabilityPoints = 100  // If exactly divisible, stay at 100
                                    }
                                }

                                UserDefaults.standard.set(sustainabilityPoints, forKey: "sustainabilityPoints")
                                // Update level based on points
                                level = sustainabilityPoints / 10
                                UserDefaults.standard.set(level, forKey: "treeLevel")
                            } label: {
                                Label("Add Points", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 15)
                                    .background(.green.opacity(0.85))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            Button {
                                sustainabilityPoints = 0
                                level = 0
                                UserDefaults.standard.set(0, forKey: "sustainabilityPoints")
                                UserDefaults.standard.set(0, forKey: "treeLevel")
                                // Clear any stored forest pines
                                UserDefaults.standard.removeObject(forKey: "forestPines")
                                UserDefaults.standard.removeObject(forKey: "forestTrees")
                                forestPines = []
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
                        .zIndex(100)  // Dev buttons on top
                    }
                }
                .zIndex(2)  // Main UI layer above forest
            }
            .navigationBarHidden(true)
            .onAppear {
                // Load forest pines
                forestPines = loadForestPines()
                print("🌲 Loaded \(forestPines.count) pines from forest")

                // Load sustainability points
                sustainabilityPoints = UserDefaults.standard.integer(forKey: "sustainabilityPoints")

                // Ensure points never go below 0
                sustainabilityPoints = max(0, sustainabilityPoints)

                level = sustainabilityPoints / 10
                // Sync values back to UserDefaults
                UserDefaults.standard.set(sustainabilityPoints, forKey: "sustainabilityPoints")
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
