import SwiftUI

@main
struct MusicPlaygroundApp: App {
    init() {
        // 初始化全局管理器
        _ = GlobalMusicManager.shared
        _ = PlaylistManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
