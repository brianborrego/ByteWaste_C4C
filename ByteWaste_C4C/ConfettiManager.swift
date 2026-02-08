//
//  ConfettiManager.swift
//  ByteWaste_C4C
//
//  Manages confetti animations using ConfettiSwiftUI library
//

import SwiftUI
import ConfettiSwiftUI

struct ConfettiManager: View {
    @Binding var trigger: Int

    var body: some View {
        Color.clear
            .confettiCannon(
                trigger: $trigger,
                num: 50,
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
                confettiSize: 12.0,
                rainHeight: 800.0,
                radius: 400.0,
                repetitions: 1,
                repetitionInterval: 0.5
            )
    }
}
