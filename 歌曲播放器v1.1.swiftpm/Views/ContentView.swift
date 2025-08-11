import SwiftUI

struct ContentView: View {
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @State private var showPlaylistCreator = false
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playbackManager = PlaybackPlaylistManager.shared
    
    // 控制右侧视图状态
    @State private var currentRightView: RightViewType = .library
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 主内容区域 (分左右两半)
                HStack(spacing: 0) {
                    // 使用新的SidebarView组件 - 固定宽度为40%
                    SidebarView(
                        currentView: $currentRightView,
                        playlists: playlistManager.playlists,
                        onDelete: { offsets in
                            // 保留外部给的删除方法
                            deletePlaylists(at: offsets)
                        },
                        onCreatePlaylist: { showPlaylistCreator = true }
                    )
                    .frame(width: geometry.size.width * 0.4)
                    
                    // 分割线
                    Divider()
                    
                    // 右侧区域 - 固定宽度为60%
                    Group {
                        switch currentRightView {
                        case .library:
                            LibraryView()
                                .environmentObject(audioPlayer)
                        case .playlist(let id):
                            PlaylistDetailView(playlistId: id)
                                .environmentObject(audioPlayer)
                        }
                    }
                    .frame(width: geometry.size.width * 0.6)
                }
                .frame(maxHeight: .infinity)
                
                // 底部播放栏 - 保持原样
                BottomPlayerView()
                    .environmentObject(audioPlayer)
            }
        }
        .sheet(isPresented: $showPlaylistCreator) {
            NewPlaylistView()
        }
        .onReceive(playlistManager.$playlistUpdateTrigger) { _ in
            // 强制视图更新 - 保持原逻辑
        }
    }
    
    // 删除歌单的方法 - 保持不变
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            playlistManager.deletePlaylist(playlistManager.playlists[index])
        }
    }
}
