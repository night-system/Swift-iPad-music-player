import SwiftUI
import AVFoundation
import UIKit

struct BottomPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @ObservedObject var playlistManager = PlaybackPlaylistManager.shared
    
    // 统一管理所有图标的颜色
    private let iconColor = Color.cyan
    private let vstackBackgroundColor = Color(UIColor.systemBackground)
    
    // 创建纯灰色占位图
    private let placeholderCover: UIImage = {
        // 创建50x50大小的纯灰色图片
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }
    }()
    
    @State private var showPlaylist = false
    @State private var progress: Float = 0.0
    @State private var currentTime: TimeInterval = 0
    @State private var totalTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var geometry: CGSize? = nil
    @State private var coverImage: UIImage? = nil
    @State private var defaultCover = UIImage(systemName: "music.note")!
    @State private var showClearConfirm = false
    @State private var showClearConfirmAfterPopup = false
    @State private var clearAlertType: ClearAlertType = .emptyPlaylist
    @State private var showAddToPlaylistSheet = false
    
    // 新状态控制歌曲详情面板
    @State private var showSongDetailPanel = false
    
    // 枚举区分不同提示类型
    private enum ClearAlertType {
        case emptyPlaylist
        case confirmClear
    }
    
    // 播放列表弹出视图尺寸
    private var playlistSize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        return CGSize(width: screenSize.width * 0.33,
                      height: min(400, screenSize.height * 0.55))
    }
    
    var body: some View {
        VStack(spacing: 7) {
            Divider()
            
            // 播放控制条
            HStack(alignment: .center, spacing: 25) {
                // 歌曲封面
                Image(uiImage: coverImage ?? defaultCover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .onTapGesture {
                        guard !audioPlayer.isSeeking else { return }
                        showSongDetailPanel = true
                    }
                    .onReceive(audioPlayer.$currentPlayingID) { id in
                        if let id = id, let music = GlobalMusicManager.shared.getMusic(by: id) {
                            loadCoverImage(for: music)
                        }
                    }
                
                // 上一首
                Button(action: {
                    audioPlayer.playPreviousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                .frame(width: 30, height: 30)
                
                // 播放/暂停
                Button(action: {
                    audioPlayer.togglePlayPause()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                        .frame(width: 42, height: 42)
                }
                
                // 下一首
                Button(action: {
                    audioPlayer.playNextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                .frame(width: 30, height: 30)
                
                Spacer()
                
                // 进度条和信息
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        // 歌曲信息
                        if let currentMusic = GlobalMusicManager.shared.getMusic(by: audioPlayer.currentPlayingID ?? UUID()) {
                            HStack(spacing: 4) {
                                Text(currentMusic.title)
                                    .font(.footnote) // 缩小字体
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Text("-") // 分隔符
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                
                                Text(currentMusic.artist)
                                    .font(.footnote) // 缩小字体
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        } else {
                            Text("无播放内容")
                                .font(.footnote)
                        }
                        
                        Spacer()
                        
                        // 当前时间/总时间
                        Text(timeString(from: currentTime))
                            .font(.caption2)
                            .monospacedDigit()
                        Text("/")
                            .font(.caption2)
                        Text(timeString(from: totalTime))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .frame(height: 15)
                    
                    // 自定义进度条 - 更大点击区域
                    ZStack(alignment: .leading) {
                        GeometryReader { geometry in
                            let width = geometry.size.width  // 实时获取容器宽度
                            
                            // 背景轨道
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2.5)
                            
                            // 进度条
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.cyan)
                                .frame(width: CGFloat(progress) * width, height: 2.5)
                            // 移除动画 - 拖拽时需即时响应
                                .animation(nil, value: progress)
                            
                            // 拖拽手柄
                            
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.0001), lineWidth: 80)
                                        .scaleEffect(audioPlayer.isSeeking ? 1.2 : 1)
                                )
                                .offset(x: CGFloat(progress) * width - 8, y: 0 - 5 + 1.25)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            audioPlayer.isSeeking = true
                                            // 直接使用最新宽度计算位置
                                            let dragLocation = gesture.location.x
                                            let normalizedValue = max(0, min(dragLocation / width, 1))
                                            progress = Float(normalizedValue)
                                            
                                            // 立即请求重绘
                                            DispatchQueue.main.async {
                                                currentTime = totalTime * TimeInterval(normalizedValue)
                                            }
                                        }
                                        .onEnded { _ in
                                            audioPlayer.seek(to: Double(progress))
                                            audioPlayer.isSeeking = false
                                        }
                                )
                            // 拖拽时禁用动画
                                .transaction { transaction in
                                    if audioPlayer.isSeeking { transaction.animation = nil }
                                }
                        }
                        .frame(height: 16)  // 确保点击区域足够大
                    }
                    .frame(height: 20) // 增加垂直高度以扩大点击区域
                    .padding(.vertical, 6) // 增加上下边距进一步扩大点击区域
                }
                .frame(height: 48) // 为整个进度条区域分配更多空间
                .padding(.horizontal, 2) // 两侧留出一点空间
                .background(
                    // 用于获取视图布局尺寸
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { geometry = geo.size }
                            .onChange(of: geo.size) { newSize in
                                geometry = newSize
                            }
                    }
                )
                
                // 播放模式
                Button(action: {
                    audioPlayer.cyclePlaybackMode()
                }) {
                    Image(systemName: audioPlayer.playbackMode.systemImage)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 1, height: 55)
                }
                .padding(.leading, 8)
                
                // 播放列表按钮 - 使用popover
                Button(action: {
                    withAnimation(.spring(dampingFraction: 0.7)) {
                        showPlaylist.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22))
                            .foregroundColor(iconColor)
                        
                        // 播放列表歌曲数量
                        
                    }
                    .padding(20)
                    .contentShape(Rectangle())
                }
                .popover(isPresented: $showPlaylist, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                    VStack(spacing: 0) {
                        // 标题栏
                        HStack {
                            
                            Button(action: {
                                audioPlayer.cyclePlaybackMode()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: audioPlayer.playbackMode.systemImage)
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.secondary)
                                    
                                    switch audioPlayer.playbackMode {
                                    case .loopAll:
                                        Text("列表循环")
                                            .foregroundColor(.secondary)
                                    case .loopOne:
                                        Text("单曲循环")
                                            .foregroundColor(.secondary)
                                    case .random:
                                        Text("随机播放")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text("(\(playlistManager.musicFiles.count))")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            
                            Spacer()
                            
                            Button(action: {
                                // 先关闭popover
                                showPlaylist = false
                                
                                // 延迟100ms后打开添加歌曲到歌单视图
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showAddToPlaylistSheet = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("收藏")
                                        .font(.system(size: 14))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0))
                                .cornerRadius(8)
                                .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                
                                // 首先关闭popover
                                //showPlaylist = false
                                
                                
                                // 根据播放列表状态决定alert类型
                                if playlistManager.musicFiles.isEmpty {
                                    clearAlertType = .emptyPlaylist
                                } else {
                                    clearAlertType = .confirmClear
                                }
                                
                                // 延迟100ms后显示alert
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showClearConfirmAfterPopup = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0))
                                .cornerRadius(8)
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                    // 这里直接模拟原来的动作
                                    showPlaylist = false
                                    
                                    if playlistManager.musicFiles.isEmpty {
                                        clearAlertType = .emptyPlaylist
                                    } else {
                                        clearAlertType = .confirmClear
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showClearConfirmAfterPopup = true
                                    }
                                }
                            }
                            
                        }
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        
                        // 播放列表内容
                        PlaybackPlaylistView(manager: playlistManager)
                            .environmentObject(audioPlayer)
                            .frame(width: playlistSize.width, height: playlistSize.height - 40)
                            .clipped()
                    }
                    .frame(width: playlistSize.width)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .background(vstackBackgroundColor)
        .fullScreenCover(isPresented: $showSongDetailPanel) {
            SongDetailPanel(
                showPanel: $showSongDetailPanel,
                coverImage: coverImage ?? defaultCover,
                currentTime: $currentTime,
                totalTime: $totalTime,
                progress: $progress,
                isSeeking: $audioPlayer.isSeeking
            )
            .environmentObject(audioPlayer)
        }
        .sheet(isPresented: $showAddToPlaylistSheet) {
            AddMultipleToPlaylistView(musicIDs: playlistManager.musicFiles.map { $0.id })
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
                        playlistManager.clearPlaylist()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            // 初始化计时器
            startProgressTimer()
            // 初始化当前时间和总时间
            if let player = audioPlayer.player {
                currentTime = player.currentTime
                totalTime = player.duration
                progress = totalTime > 0 ? min(1.0, Float(currentTime / totalTime)) : 0
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onReceive(audioPlayer.$currentPlayingID) { _ in
            // 当切换歌曲时重置进度
            if let player = audioPlayer.player {
                currentTime = 0
                totalTime = player.duration
                progress = 0
            }
        }
        .onChange(of: audioPlayer.player?.currentTime) { newValue in
            // 当用户正在拖动时，不要自动更新进度
            guard !audioPlayer.isSeeking else { return }
            
            if let player = audioPlayer.player, player.duration > 0 {
                // 确保当前时间不超过总时长
                currentTime = min(player.currentTime, player.duration)
                totalTime = player.duration
                
                // 确保进度不超过1.0
                progress = min(1.0, Float(currentTime / totalTime))
            } else {
                currentTime = 0
                totalTime = 0
                progress = 0
            }
        }
        .onChange(of: audioPlayer.totalDuration) { newDuration in
            // 当收到新歌曲的总时长时更新状态
            totalTime = newDuration
        }
    }
    
    private func loadCoverImage(for music: MusicFile) {
        // 直接使用管理器获取封面（会自动处理自定义封面）
        if let coverImage = GlobalMusicManager.shared.getCoverImage(for: music) {
            self.coverImage = coverImage
        } else {
            coverImage = nil
        }
    }
    
    private func timeString(from time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // 当用户正在拖动时，不要自动更新进度
            guard !self.audioPlayer.isSeeking else { return }
            
            if let player = self.audioPlayer.player, player.duration > 0 {
                self.currentTime = player.currentTime
                self.totalTime = player.duration
                
                // 确保进度值不超过1.0
                self.progress = min(1.0, Float(self.currentTime / self.totalTime))
                
                // 添加特殊检查：如果接近结束且没有在播放下一首，自动触发结束
                if self.totalTime - self.currentTime < 0.5 && player.isPlaying {
                    DispatchQueue.main.async {
                        self.audioPlayer.handleEnded()
                    }
                }
            } else {
                self.currentTime = 0
                self.totalTime = 0
                self.progress = 0
            }
        }
    }
    
    // 确认清空播放列表操作
    private func confirmClearPlaylist() {
        print("🟠 进入 confirmClearPlaylist 函数")
        
        // 检查播放列表是否为空
        print("🟠 播放列表歌曲数量: \(playlistManager.musicFiles.count)")
        guard !playlistManager.musicFiles.isEmpty else {
            print("🔴 播放列表为空，不执行清空操作")
            showAlert(title: "播放列表已空", message: "无需清空")
            return
        }
        
        print("🟠 当前UI线程: \(Thread.isMainThread ? "主线程" : "后台线程")")
        
        // 创建确认提示框
        print("🟠 创建 UIAlertController")
        let alert = UIAlertController(
            title: "确定清空播放列表吗？",
            message: "这将移除所有正在播放的歌曲",
            preferredStyle: .alert
        )
        
        // 添加取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            
        })
        
        // 添加清空按钮
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in
            
            self.playlistManager.clearPlaylist()
            // 清除后关闭播放列表弹出视图
            self.showPlaylist = false
        })
        
        // 检查当前视图控制器的状态
        DispatchQueue.main.async {
            
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                return
            }
            
            // 尝试显示提示框
            rootVC.present(alert, animated: true) {
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                
            }
        }
    }
    
    // 显示简单提示框
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}
  
