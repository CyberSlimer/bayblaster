import SpriteKit
import SwiftUI

/// SwiftUI host. The SKView presented here is reused for every scene change
/// (scenes swap themselves via SceneRouter / view.presentScene).
struct ContentView: View {
    @State private var scene: SKScene = {
        let s = TitleScene(size: CGSize(width: 844, height: 390))   // real size arrives via .resizeFill
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        // Sibling order is respected on purpose: the placeholder drawings are layered shapes at the
        // same zPosition. If real sprites replace them, [.ignoresSiblingOrder] is a free speed-up.
        SpriteView(scene: scene,
                   preferredFramesPerSecond: 120,          // 60 on non-ProMotion devices
                   options: [])
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
