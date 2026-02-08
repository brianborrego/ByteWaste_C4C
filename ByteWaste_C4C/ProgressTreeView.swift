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
                    Text("Level \(level) / 10")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .padding(.top, 30)

                    TreeViewRepresentable(
                        growth: growthValue(level: level),
                        animate: shouldAnimate
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    // Buttons just above the tab bar
                    HStack {
                        Button {
                            if level < 10 {
                                level += 1
                                UserDefaults.standard.set(level, forKey: "treeLevel")
                            }
                        } label: {
                            Label("Level Up", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 15)
                                .background(.green.opacity(0.85))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .disabled(level >= 10)

                        Spacer()

                        Button {
                            level = 0
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
                level = UserDefaults.standard.integer(forKey: "treeLevel")
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
