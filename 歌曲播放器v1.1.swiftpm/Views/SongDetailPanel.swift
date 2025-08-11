import SwiftUI
import AVFoundation

struct SongDetailPanel: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Binding var showPanel: Bool
    @State private var showControlPanel = false
    let coverImage: UIImage
    @Binding var currentTime: TimeInterval
    @Binding var totalTime: TimeInterval
    @Binding var progress: Float
    @Binding var isSeeking: Bool
    
    // 新增状态：曲率和模糊
    @AppStorage("lyricCurvature") private var curvature: Double = 0.5
    @AppStorage("lyricBlur") private var blur: Double = 0.5
    
    // 分享相关状态
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // 播放列表弹窗状态
    @State private var showAddToPlaylistSheet = false
    @State private var showClearConfirmAfterPopup = false
    @State var clearAlertType: ClearAlertType = .emptyPlaylist
    
    enum ClearAlertType {
        case emptyPlaylist
        case confirmClear
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 模糊背景
                DetailBackgroundView(coverImage: coverImage)
                
                // 主内容区
                VStack(spacing: 0) {
                    // 顶部控制栏
                    TopControlBar(dismissAction: { dismiss() }, shareAction: shareCurrentMusic)
                    
                    // 左右面板布局
                    HStack(spacing: 30) {
                        // 左边面板（封面和控制）
                        LeftPanelView(
                            coverImage: coverImage,
                            width: geometry.size.width * 0.4,
                            progress: $progress,
                            currentTime: $currentTime,
                            totalTime: $totalTime,
                            isSeeking: $isSeeking,
                            showAddToPlaylistSheet: $showAddToPlaylistSheet,
                            showClearConfirmAfterPopup: $showClearConfirmAfterPopup,
                            clearAlertType: $clearAlertType,
                            showControlPanel: $showControlPanel // 传递绑定状态
                        )
                        .environmentObject(audioPlayer)
                        .padding(.bottom, 300)
                        .padding(.top, 20)
                        
                        // 右边面板（歌词）- 使用新建的独立视图
                        
                        Color.clear
                            .frame(width: geometry.size.width * 0.4)
                        
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 0)
                    
                    Spacer()
                }
                
                HStack{
                    
                    Color.clear
                        .frame(width: geometry.size.width * 0.4)
                    
                    LyricsPanelView(
                        currentTime: $currentTime,
                        curvature: $curvature,  // 传递曲率绑定
                        blur: $blur             // 传递模糊绑定
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .environmentObject(GlobalMusicManager.shared)
                    .environmentObject(audioPlayer)
                    .padding(.bottom, 260)
                    
                    
                    
                }
                
                
                
                
                
                // 在最上层添加控制面板
                if showControlPanel {
                    ControlPanelView(
                        isPresented: $showControlPanel,
                        curvature: $curvature,  // 传递曲率绑定
                        blur: $blur             // 传递模糊绑定
                    )
                    .environmentObject(audioPlayer)  // 传递音频播放器
                    .offset(x: 20, y: 0)
                    .position(x: geometry.size.width - 60, 
                              y: geometry.size.height * 0.5)
                    
                }
            }
        }
        .background(Color.black)
        
        // 添加分享弹出层
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet2(activityItems: $shareItems)
            }
        }
        .sheet(isPresented: $showAddToPlaylistSheet) {
            AddMultipleToPlaylistView(musicIDs: PlaybackPlaylistManager.shared.musicFiles.map { $0.id })
        }
        .alert(isPresented: $showClearConfirmAfterPopup) {
            switch clearAlertType {
            case .emptyPlaylist:
                return Alert(
                    title: Text("播放列表已空"),
                    message: Text("无需清空"),
                    dismissButton: .default(Text("确定"))
                )
            case .confirmClear:
                return Alert(
                    title: Text("确定清空播放列表吗？"),
                    message: Text("这将移除所有正在播放的歌曲"),
                    primaryButton: .destructive(Text("清空")) {
                        PlaybackPlaylistManager.shared.clearPlaylist()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // 分享当前歌曲
    private func shareCurrentMusic() {
        guard let currentID = audioPlayer.currentPlayingID,
              let music = GlobalMusicManager.shared.getMusic(by: currentID),
              let fileURL = GlobalMusicManager.shared.fileURL(for: music.fileName) else {
            return
        }
        shareItems = [fileURL]  // 直接赋值单个文件URL的数组
        showShareSheet = true
    }
}
