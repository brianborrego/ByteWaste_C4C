import UIKit

/// 10 levels: level 0 = seed, level 10 = fully grown
func growthValue(level: Int) -> CGFloat {
    return min(CGFloat(level) / 10.0, 1.0)
}

struct Branch {
    let unlock: CGFloat
    let angle: CGFloat
    let length: CGFloat
    let trunkFraction: CGFloat   // 0 = base, 1 = top of trunk
    let thickness: CGFloat
}

final class TreeView: UIView {

    private let trunkLayer = CAShapeLayer()
    private let trunkBaseLayer = CAShapeLayer()
    private var trunkTextureLayers: [CAShapeLayer] = []
    private var branchLayers: [CAShapeLayer] = []
    private var leafLayers: [CAShapeLayer] = []
    private var currentGrowth: CGFloat = 0
    private var animationGeneration: Int = 0
    private var rng = SeededRNG(seed: 42)

    // Branches unlock progressively — lower branches first, upper ones much later
    // Level 1=0.1, Level 2=0.2, ..., Level 10=1.0
    private let branches = [
        // Level 2-3: first few lower branches sprout
        Branch(unlock: 0.20, angle: -(5 * .pi / 6), length: 90,  trunkFraction: 0.15, thickness: 7),
        Branch(unlock: 0.25, angle: -(.pi / 6),      length: 95,  trunkFraction: 0.20, thickness: 7),
        Branch(unlock: 0.30, angle: -(4 * .pi / 5),  length: 85,  trunkFraction: 0.28, thickness: 6),
        // Level 4: more mid branches
        Branch(unlock: 0.35, angle: -(.pi / 5),       length: 88,  trunkFraction: 0.32, thickness: 6),
        Branch(unlock: 0.40, angle: -(3 * .pi / 4),  length: 78,  trunkFraction: 0.40, thickness: 5.5),
        // Level 5: mid-height branches
        Branch(unlock: 0.45, angle: -(.pi / 4),       length: 80,  trunkFraction: 0.44, thickness: 5.5),
        Branch(unlock: 0.50, angle: -(5 * .pi / 6),  length: 72,  trunkFraction: 0.52, thickness: 5),
        // Level 6: upper-mid branches
        Branch(unlock: 0.55, angle: -(.pi / 6),       length: 74,  trunkFraction: 0.56, thickness: 5),
        Branch(unlock: 0.60, angle: -(4 * .pi / 5),  length: 65,  trunkFraction: 0.63, thickness: 4.5),
        // Level 7: upper branches
        Branch(unlock: 0.65, angle: -(.pi / 5),       length: 68,  trunkFraction: 0.67, thickness: 4.5),
        Branch(unlock: 0.70, angle: -(3 * .pi / 4),  length: 55,  trunkFraction: 0.75, thickness: 4),
        // Level 8: near-top branches
        Branch(unlock: 0.75, angle: -(.pi / 4),       length: 58,  trunkFraction: 0.79, thickness: 4),
        Branch(unlock: 0.80, angle: -(2 * .pi / 3),  length: 45,  trunkFraction: 0.86, thickness: 3.5),
        // Level 9-10: very top branches
        Branch(unlock: 0.85, angle: -(.pi / 3),       length: 48,  trunkFraction: 0.90, thickness: 3.5),
        Branch(unlock: 0.90, angle: -(3 * .pi / 4),  length: 35,  trunkFraction: 0.95, thickness: 3),
        Branch(unlock: 0.95, angle: -(.pi / 4),       length: 35,  trunkFraction: 0.97, thickness: 3),
    ]

    private let leafCount = 1500
    private let trunkTextureCount = 10

    // Tree layout
    private var treeAreaTop: CGFloat { bounds.height * 0.05 }
    private var treeAreaBottom: CGFloat { bounds.height * 0.92 }
    private var trunkBaseY: CGFloat { treeAreaBottom }
    private var trunkTopY: CGFloat { treeAreaTop + (treeAreaBottom - treeAreaTop) * 0.10 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Path helpers

    private func leafPath(at center: CGPoint, size: CGFloat, rotation: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let h = size
        let w = size * 0.42
        path.move(to: CGPoint(x: 0, y: -h / 2))
        path.addQuadCurve(to: CGPoint(x: 0, y: h / 2), controlPoint: CGPoint(x: w, y: -h * 0.1))
        path.addQuadCurve(to: CGPoint(x: 0, y: -h / 2), controlPoint: CGPoint(x: -w, y: -h * 0.1))
        path.close()
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        transform = transform.rotated(by: rotation)
        return path.cgPath.copy(using: &transform) ?? path.cgPath
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        // Trunk base — flared shape
        trunkBaseLayer.fillColor = UIColor.brown.cgColor
        trunkBaseLayer.strokeColor = nil
        trunkBaseLayer.opacity = 0
        layer.addSublayer(trunkBaseLayer)

        // Trunk
        trunkLayer.strokeColor = UIColor.brown.cgColor
        trunkLayer.lineWidth = 26
        trunkLayer.fillColor = nil
        trunkLayer.lineCap = .square
        layer.addSublayer(trunkLayer)

        let textureColors: [UIColor] = [
            UIColor.brown.withAlphaComponent(0.35),
            UIColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 0.30),
            UIColor(red: 0.50, green: 0.35, blue: 0.20, alpha: 0.22),
            UIColor(red: 0.28, green: 0.16, blue: 0.06, alpha: 0.32),
            UIColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 0.18),
        ]
        for i in 0..<trunkTextureCount {
            let tex = CAShapeLayer()
            tex.strokeColor = textureColors[i % textureColors.count].cgColor
            tex.lineWidth = CGFloat.random(in: 1.0...4.0)
            tex.fillColor = nil
            tex.lineCap = .square
            tex.opacity = 0
            layer.addSublayer(tex)
            trunkTextureLayers.append(tex)
        }

        for branch in branches {
            let bl = CAShapeLayer()
            bl.strokeColor = UIColor.brown.withAlphaComponent(0.85).cgColor
            bl.lineWidth = branch.thickness
            bl.fillColor = nil
            bl.lineCap = .round
            bl.lineJoin = .round
            bl.opacity = 0
            layer.addSublayer(bl)
            branchLayers.append(bl)
        }

        let leafColors: [UIColor] = [
            UIColor(red: 0.12, green: 0.52, blue: 0.18, alpha: 1),
            UIColor(red: 0.16, green: 0.60, blue: 0.22, alpha: 1),
            UIColor(red: 0.14, green: 0.55, blue: 0.20, alpha: 1),
            UIColor(red: 0.20, green: 0.68, blue: 0.28, alpha: 1),
            UIColor(red: 0.10, green: 0.48, blue: 0.16, alpha: 1),
            UIColor(red: 0.18, green: 0.62, blue: 0.25, alpha: 1),
            UIColor(red: 0.22, green: 0.72, blue: 0.30, alpha: 1),
        ]
        for i in 0..<leafCount {
            let leaf = CAShapeLayer()
            leaf.fillColor = leafColors[i % leafColors.count].cgColor
            leaf.opacity = 0
            layer.addSublayer(leaf)
            leafLayers.append(leaf)
        }
    }

    // MARK: - Clear

    private func clearAll() {
        layer.removeAnimation(forKey: "sway")
        trunkLayer.removeAllAnimations(); trunkLayer.path = nil
        trunkBaseLayer.removeAllAnimations(); trunkBaseLayer.path = nil; trunkBaseLayer.opacity = 0
        for tex in trunkTextureLayers {
            tex.removeAllAnimations(); tex.path = nil; tex.opacity = 0
        }
        for sub in branchLayers + leafLayers {
            sub.removeAllAnimations(); sub.path = nil; sub.opacity = 0
        }
    }

    // MARK: - Trunk paths

    private func trunkPath(growth: CGFloat) -> CGPath {
        let baseX = bounds.midX
        let baseY = trunkBaseY
        let height = (baseY - trunkTopY) * growth
        let topY = baseY - height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: baseX, y: baseY))
        // Straight trunk — just a vertical line
        path.addLine(to: CGPoint(x: baseX, y: topY))
        return path.cgPath
    }

    private func trunkTexturePath(index: Int, growth: CGFloat) -> CGPath {
        var texRng = SeededRNG(seed: UInt64(index) &* 7 &+ 13)
        let baseX = bounds.midX
        let baseY = trunkBaseY
        let height = (baseY - trunkTopY) * growth
        guard height > 10 else { return UIBezierPath().cgPath }
        // Stay within trunk width (lineWidth 26 → ±12 from center)
        let offset = texRng.nextCGFloat(in: -9...9)
        let segCount = 6 + Int(texRng.nextCGFloat(in: 0...6))
        let path = UIBezierPath()
        let startFrac = texRng.nextCGFloat(in: 0...0.1)
        path.move(to: CGPoint(x: baseX + offset, y: baseY - height * startFrac))
        let endFraction = texRng.nextCGFloat(in: 0.5...1.0)
        for s in 1...segCount {
            let t = startFrac + CGFloat(s) / CGFloat(segCount) * (endFraction - startFrac)
            let y = baseY - height * t
            // Small wobble that stays within trunk bounds
            let wobble = texRng.nextCGFloat(in: -3...3)
            path.addLine(to: CGPoint(x: baseX + offset + wobble, y: y))
        }
        return path.cgPath
    }

    // MARK: - Phase 1: Trunk

    private func animatePhase1(growth: CGFloat) {
        let baseX = bounds.midX
        let baseY = trunkBaseY
        // Trunk stroke extends 13pt below baseY due to lineWidth/2 + .square cap
        let strokeBottom = baseY + 13
        let flareHeight: CGFloat = 18 * growth
        let topHalfWidth: CGFloat = 13
        let bottomHalfWidth: CGFloat = 20 * growth + 13
        let basePath = UIBezierPath()
        // Top of flare aligns with trunk, bottom extends to stroke bottom
        basePath.move(to: CGPoint(x: baseX - topHalfWidth, y: strokeBottom - flareHeight))
        basePath.addQuadCurve(to: CGPoint(x: baseX - bottomHalfWidth, y: strokeBottom),
                              controlPoint: CGPoint(x: baseX - topHalfWidth - 6, y: strokeBottom - flareHeight * 0.25))
        basePath.addLine(to: CGPoint(x: baseX + bottomHalfWidth, y: strokeBottom))
        basePath.addQuadCurve(to: CGPoint(x: baseX + topHalfWidth, y: strokeBottom - flareHeight),
                              controlPoint: CGPoint(x: baseX + topHalfWidth + 6, y: strokeBottom - flareHeight * 0.25))
        basePath.close()
        trunkBaseLayer.path = basePath.cgPath
        let baseFade = CABasicAnimation(keyPath: "opacity")
        baseFade.fromValue = 0; baseFade.toValue = 1; baseFade.duration = 0.5
        trunkBaseLayer.add(baseFade, forKey: "baseFade"); trunkBaseLayer.opacity = 1

        let trunkAnim = CABasicAnimation(keyPath: "path")
        trunkAnim.fromValue = trunkPath(growth: 0)
        trunkAnim.toValue = trunkPath(growth: growth)
        trunkAnim.duration = 0.8
        trunkAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        trunkLayer.add(trunkAnim, forKey: "grow")
        trunkLayer.path = trunkPath(growth: growth)

        for (i, tex) in trunkTextureLayers.enumerated() {
            tex.path = trunkTexturePath(index: i, growth: growth)
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0; fadeIn.toValue = 1; fadeIn.duration = 0.5
            tex.add(fadeIn, forKey: "texFade"); tex.opacity = 1
        }
    }

    // MARK: - Phase 2: Branches (organic curves)

    private func branchWaypoints(for branch: Branch, growth: CGFloat, branchIndex: Int) -> [CGPoint] {
        var bRng = SeededRNG(seed: UInt64(branchIndex) &* 31 &+ 7)
        let trunkHeight = (trunkBaseY - trunkTopY) * growth
        let startY = trunkBaseY - trunkHeight * branch.trunkFraction
        let startPt = CGPoint(x: bounds.midX, y: startY)
        let endPt = CGPoint(x: bounds.midX + cos(branch.angle) * branch.length,
                            y: startY + sin(branch.angle) * branch.length)
        let dx = endPt.x - startPt.x
        let dy = endPt.y - startPt.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return [startPt] }
        let perpX = -dy / len
        let perpY = dx / len
        let segCount = 5
        var points = [startPt]
        for s in 1..<segCount {
            let t = CGFloat(s) / CGFloat(segCount)
            let bx = startPt.x + dx * t
            let by = startPt.y + dy * t
            let midFactor = 1.0 - abs(t - 0.5) * 2.0
            let offset = bRng.nextCGFloat(in: -12...12) * (0.5 + midFactor)
            points.append(CGPoint(x: bx + perpX * offset, y: by + perpY * offset))
        }
        points.append(endPt)
        return points
    }

    private func curvedBranchPath(points: [CGPoint]) -> CGPath {
        let path = UIBezierPath()
        guard points.count >= 2 else { return path.cgPath }
        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
            return path.cgPath
        }
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let midX = (prev.x + curr.x) / 2
            let midY = (prev.y + curr.y) / 2
            path.addQuadCurve(to: CGPoint(x: midX, y: midY), controlPoint: prev)
        }
        path.addLine(to: points.last!)
        return path.cgPath
    }

    private func pointAlongWaypoints(_ pts: [CGPoint], t: CGFloat) -> CGPoint {
        guard pts.count >= 2 else { return pts.first ?? .zero }
        let totalSegs = CGFloat(pts.count - 1)
        let scaledT = t * totalSegs
        let segIdx = min(Int(scaledT), pts.count - 2)
        let localT = scaledT - CGFloat(segIdx)
        let a = pts[segIdx]
        let b = pts[segIdx + 1]
        return CGPoint(x: a.x + (b.x - a.x) * localT, y: a.y + (b.y - a.y) * localT)
    }

    private var computedBranchWaypoints: [[CGPoint]] = []

    private func animatePhase2(growth: CGFloat, gen: Int) {
        computedBranchWaypoints = []
        var visibleCount = 0
        for (i, branch) in branches.enumerated() {
            guard i < branchLayers.count, growth >= branch.unlock else {
                computedBranchWaypoints.append([])
                continue
            }
            let waypoints = branchWaypoints(for: branch, growth: growth, branchIndex: i)
            computedBranchWaypoints.append(waypoints)
            let bl = branchLayers[i]
            let idx = visibleCount; visibleCount += 1
            let path = curvedBranchPath(points: waypoints)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.08) { [weak self] in
                guard let self, self.animationGeneration == gen else { return }
                bl.path = path
                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0; fadeIn.toValue = 1; fadeIn.duration = 0.25
                bl.add(fadeIn, forKey: "fadeIn"); bl.opacity = 1
            }
        }
    }

    // MARK: - Phase 3: Leaves — realistic growth progression
    //
    // Realistic tree growth:
    //   Level 1 (0.1): Sapling — trunk only, no leaves
    //   Level 2 (0.2): First branch sprouts, a handful of leaves
    //   Level 3 (0.3): A few branches, sparse scattered leaves
    //   Level 4 (0.4): More branches, light foliage
    //   Level 5 (0.5): Half-grown, moderate but airy foliage
    //   Level 6 (0.6): Foliage thickening, canopy fill begins
    //   Level 7 (0.7): Dense branches, substantial canopy
    //   Level 8 (0.8): Thick foliage, nearly full
    //   Level 9 (0.9): Very dense, almost complete
    //   Level 10 (1.0): Full majestic tree, maximum density

    private func animatePhase3(growth: CGFloat, gen: Int) {
        guard growth >= 0.20 else { return } // no leaves below level 2
        rng = SeededRNG(seed: 99)

        var positions: [(cx: CGFloat, cy: CGFloat, rot: CGFloat)] = []

        // Leaf density curve: exponential ramp so early levels are sparse
        // growth 0.2 → 2%, 0.3 → 5%, 0.5 → 15%, 0.7 → 40%, 0.9 → 75%, 1.0 → 100%
        let normalizedGrowth = (growth - 0.2) / 0.8  // 0 at level 2, 1 at level 10
        let densityFactor = pow(normalizedGrowth, 2.2) // exponential curve
        let totalLeafTarget = Int(CGFloat(leafCount) * densityFactor)
        guard totalLeafTarget > 0 else { return }

        // --- Part A: Branch-following leaves (always present) ---
        var visibleBranches: [(index: Int, branch: Branch, waypoints: [CGPoint])] = []
        for (i, branch) in branches.enumerated() {
            guard growth >= branch.unlock, i < computedBranchWaypoints.count else { continue }
            let wp = computedBranchWaypoints[i]
            guard wp.count >= 2 else { continue }
            visibleBranches.append((i, branch, wp))
        }

        // At low growth, 100% branch leaves. At high growth, 60% branch + 40% canopy
        let canopyRatio: CGFloat = growth >= 0.6 ? min((growth - 0.6) / 0.4 * 0.40, 0.40) : 0
        let branchBudget = Int(CGFloat(totalLeafTarget) * (1.0 - canopyRatio))
        let canopyBudget = totalLeafTarget - branchBudget

        if !visibleBranches.isEmpty && branchBudget > 0 {
            // Cascade: bottom branches (low index) get more leaves than top ones
            let totalVis = visibleBranches.count
            var weights: [CGFloat] = []
            var totalWeight: CGFloat = 0
            for (vIdx, _) in visibleBranches.enumerated() {
                let frac = CGFloat(vIdx) / CGFloat(max(totalVis - 1, 1))
                let w: CGFloat = 1.4 - frac * 0.6 // 1.4 at bottom, 0.8 at top
                weights.append(w)
                totalWeight += w
            }

            for (vIdx, entry) in visibleBranches.enumerated() {
                let perBranch = max(1, Int(CGFloat(branchBudget) * weights[vIdx] / totalWeight))
                let waypoints = entry.waypoints
                let sampleCount = max(3, min(14, perBranch / 3))
                let leavesPerSample = max(1, perBranch / sampleCount)
                for s in 0..<sampleCount {
                    let t = CGFloat(s + 1) / CGFloat(sampleCount + 1)
                    let pt = pointAlongWaypoints(waypoints, t: t)
                    for _ in 0..<leavesPerSample {
                        // Wider scatter to cover sides of tree
                        let dx = rng.nextCGFloat(in: -24...24)
                        let dy = rng.nextCGFloat(in: -16...16)
                        let rot = rng.nextCGFloat(in: -.pi...(.pi))
                        positions.append((pt.x + dx, pt.y + dy, rot))
                    }
                }
            }
        }

        // --- Part B: Canopy fill — wider and denser (only at growth >= 0.6) ---
        if canopyBudget > 0 {
            let trunkHeight = (trunkBaseY - trunkTopY) * growth
            let canopyTopY = trunkBaseY - trunkHeight - 40
            let lowestFrac = visibleBranches.first?.branch.trunkFraction ?? 0.15
            let canopyBottomY = trunkBaseY - trunkHeight * lowestFrac + 15

            let tierCount = max(8, min(35, canopyBudget / 6))
            let leavesPerTier = max(1, canopyBudget / tierCount)

            for t in 0..<tierCount {
                let frac = CGFloat(t) / CGFloat(max(tierCount - 1, 1))
                let y = canopyBottomY + (canopyTopY - canopyBottomY) * frac
                // Wider base: 105 at bottom, narrows to ~16 at top
                let halfWidth: CGFloat = (1.0 - frac * 0.85) * 105 * growth

                for j in 0..<leavesPerTier {
                    let xNorm = CGFloat(j) / CGFloat(max(leavesPerTier - 1, 1))
                    let x = bounds.midX - halfWidth + halfWidth * 2 * xNorm
                    let jx = rng.nextCGFloat(in: -10...10)
                    let jy = rng.nextCGFloat(in: -8...8)
                    let rot = rng.nextCGFloat(in: -.pi...(.pi))
                    positions.append((x + jx, y + jy, rot))
                }
            }
        }

        // Animate leaves
        for (i, pos) in positions.enumerated() {
            guard i < leafLayers.count else { break }
            let idx = i
            let delay = totalLeafTarget > 500 ? 0.002 : 0.005
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * delay) { [weak self] in
                guard let self, self.animationGeneration == gen else { return }
                let leaf = self.leafLayers[idx]
                let size = CGFloat.random(in: 9...15)
                leaf.path = self.leafPath(at: CGPoint(x: pos.cx, y: pos.cy),
                                          size: size, rotation: pos.rot)
                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0; fadeIn.toValue = 1; fadeIn.duration = 0.12
                leaf.add(fadeIn, forKey: "leafFade"); leaf.opacity = 1
            }
        }
    }

    // MARK: - Sway

    private func addSwayAnimation() {
        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -0.008; sway.toValue = 0.008
        sway.duration = 3.5; sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(sway, forKey: "sway")
    }

    // MARK: - Public API

    func animateToGrowth(_ newGrowth: CGFloat) {
        animationGeneration += 1
        let gen = animationGeneration
        currentGrowth = newGrowth
        clearAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.animationGeneration == gen else { return }
            self.animatePhase1(growth: newGrowth)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.animationGeneration == gen else { return }
            self.animatePhase2(growth: newGrowth, gen: gen)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.animationGeneration == gen else { return }
            self.animatePhase3(growth: newGrowth, gen: gen)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            guard let self, self.animationGeneration == gen else { return }
            self.addSwayAnimation()
        }
    }
}

// MARK: - Seeded RNG

struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let raw = CGFloat(next() % 10000) / 10000.0
        return range.lowerBound + raw * (range.upperBound - range.lowerBound)
    }
}
