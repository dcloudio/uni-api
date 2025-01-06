import AVFoundation
import MediaPlayer
import DCloudUniappRuntime;

private enum UniBackgroundAudioObserveKeypath: String {
    case status = "status"
    case timeControlStatus = "timeControlStatus"
    case rate = "rate"
    case loadedTimeRanges = "loadedTimeRanges"
    case playbackBufferEmpty = "playbackBufferEmpty"
    case playbackLikelyToKeepUp = "playbackLikelyToKeepUp"
}

private enum UniBackgroundAudioEvent: String {
    case canplay = "canplay"
    case play = "play"
    case pause = "pause"
    case stop = "stop"
    case ended = "ended"
    case timeUpdate = "timeUpdate"
    case waiting = "waiting"
    case seeking = "seeking"
    case seeked = "seeked"
    case next = "next"
    case prev = "prev"
}

// 闭包class化，方便通过 == 对比
private class CallbackWrapper: Equatable {
    enum CallbackType {
        case callback(UniBackgroundAudioEventCallback)
        case errorCallback(UniBackgroundAudioErrorEventCallback)
    }
    
    let callbackType: CallbackType
    
    init(callback: @escaping UniBackgroundAudioEventCallback) {
        self.callbackType = .callback(callback)
    }
    
    init(errorCallback: @escaping UniBackgroundAudioErrorEventCallback) {
        self.callbackType = .errorCallback(errorCallback)
    }
    
    public static func == (lhs: CallbackWrapper, rhs: CallbackWrapper) -> Bool {
        return lhs === rhs
    }
}

typealias UniBackgroundAudioEventCallback = (_ result: Any) -> Void
typealias UniBackgroundAudioErrorEventCallback = (_ result: ICreateBackgroundAudioFail) -> Void

public class UniBackgroundAudioManager: NSObject, BackgroundAudioManager {
    public static var shared = UniBackgroundAudioManager()
    
    private lazy var playerItem: AVPlayerItem? = {
        if let url = URL(string: src) {
            return AVPlayerItem(url: url)
        } else {
            return nil
        }
    }()
    
    private lazy var player: AVPlayer? = {
        return AVPlayer(playerItem: playerItem)
    }()
    
    private var _src: String = "" {
        didSet {
            updatePlayerItem()
        }
    }
    private var _startTime: NSNumber = 0 {
        didSet {
            innerSeek(_startTime)
        }
    }
    private var _buffered: NSNumber = 0
    private var _title: String = ""
    private var _epname: String = ""
    private var _singer: String = ""
    private var _coverImgUrl: String = "" {
        didSet {
            if _coverImgUrl != "" {
                UTSiOS.loadImage(coverImgUrl) { [weak self] image, data in
                    if let image = image {
                        self?.remoteControlCoverImage = image
                    }
                }
            }
        }
    }
    private var _webUrl: String = ""
    private var _protocol: String = ""
    private var _autoplay: Bool = false {
        didSet {
            if player?.timeControlStatus != .playing && !_isManualPause {
                innerPlay(needDispathEvent: true)
            }
        }
    }
    private var _loop: Bool = false
    private var _volume: NSNumber = 1.0 {
        didSet {
            player?.volume = _volume.toFloatA()
        }
    }
    private var _playbackRate: NSNumber = 1.0 {
        didSet {
            if player?.timeControlStatus == .playing {
                player?.rate = _playbackRate.toFloatA()
            } else {
                player?.pause()
            }
        }
    }
    
    private var _isNeedSetRate = false //添加该变量优化系统默认的只有播放状态设置rate才有效的情况
    private var _status: AVPlayerItem.Status? //playitem 监听status状态
    private var _isPlaying: Bool {
        get {
            return player?.timeControlStatus == .playing
        }
    }
    private var _isManualPlay = false  //是否正在播放，侧重于用户是否点击了播放按钮
    private var _isManualPause = false //是否用户点击暂停，和缓冲的暂停无关
    private var _hasPlayError = false //是否播放出错
    private var _currentFailImpl: CreateBackgroundAudioFailImpl? = nil //当前播放出错error对象
    private var _isSeeking = false //是否是正在seeking状态
    private var _isAppActive = false //app是否正在前台状态
    private var _hasConfigAudioSession = false //是否配置好了后台播放会话通道
    private var _readyToPlay = false //是否canPlay状态
    
    private var eventCallbacks: [String: [CallbackWrapper]] = [:]
    private var errorEventCallBacks: [UniBackgroundAudioErrorEventCallback] = []
    private var timeObserverToken: Any?
    private var remoteControlCoverImage: UIImage?
    
    public var duration: NSNumber {
        get {
            return NSNumber(floatLiteral: playerItem?.asset.duration.seconds ?? 0.0)
        }
        set {}
    }
    
    public var currentTime: NSNumber {
        get {
            var second = 0.0
            if let temp = player?.currentTime().seconds, temp >= 0 {
                second = temp
            }
            return NSNumber(floatLiteral: second)
        }
        set {}
    }
    
    public var paused: Bool {
        get {
            return player?.timeControlStatus == .paused || player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
        }
        set {}
    }
    public var src: String {
        get { return _src}
        set { _src = newValue }
    }
    
    public var startTime: NSNumber{
        get { return
            _startTime
        }
        set {
            _startTime = newValue
        }
    }
    
    public var buffered: NSNumber{
        get { return _buffered }
        set { _buffered = newValue }
    }
    
    public var title: String {
        get { return _title }
        set { _title = newValue }
    }
    
    public var epname: String {
        get { return _epname }
        set { _epname = newValue }
    }
    
    public var singer: String {
        get { return _singer }
        set { _singer = newValue }
    }
    
    public var coverImgUrl: String {
        get { return _coverImgUrl }
        set { _coverImgUrl = newValue }
    }
    
    public var webUrl: String {
        get { return _webUrl }
        set { _webUrl = newValue }
    }
    
    public var `protocol`: String {
        get { return _protocol }
        set { _protocol = newValue }
    }
    
    public var autoplay: Bool{
        get { return _autoplay }
        set { _autoplay = newValue }
    }
    
    public var loop: Bool{
        get { return _loop }
        set { _loop = newValue }
    }
    
    public var obeyMuteSwitch: Bool {
        get { return false }
        set {}
    }
    
    public var volume: NSNumber {
        get { return _volume }
        set { _volume = newValue }
    }
    
    public var playbackRate: NSNumber? {
        get { return _playbackRate }
        set {
            if _playbackRate != newValue {
                _isNeedSetRate = true
                _playbackRate = newValue ?? 1.0
            }
        }
    }
    
    public func seek(_ position: NSNumber) {
        innerSeek(position, needDispathEvent: true)
    }
    
    public override init() {
        super.init()
        _isAppActive = true
        configureAudioSession()
        configureRemoteCommandCenter()
        configurePlayer()
    }
    
    deinit {
        destroy()
    }
    
    public func destroy() {
        deactivateAudioSession()
        releaseResources()
    }

    public func onCanplay(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .canplay, eventCallback: callback)
    }
    
    public func offCanplay(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .canplay, eventCallback: callback)
    }
    
    public func onPlay(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .play, eventCallback: callback)
    }
    
    public func offPlay(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .play, eventCallback: callback)
    }
    
    public func onPause(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .pause, eventCallback: callback)
    }
    
    public func offPause(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .pause, eventCallback: callback)
    }
    
    public func onStop(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .stop, eventCallback: callback)
    }
    
    public func offStop(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .stop, eventCallback: callback)
    }
    
    public func onEnded(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .ended, eventCallback: callback)
    }
    
    public func offEnded(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .ended, eventCallback: callback)
    }
    
    public func onTimeUpdate(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .timeUpdate, eventCallback: callback)
    }
    
    public func offTimeUpdate(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .timeUpdate, eventCallback: callback)
        removePeriodicTimeObserver()
    }
    
    public func onError(_ callback: @escaping (any ICreateBackgroundAudioFail) -> Void) {
        errorEventCallBacks.removeAll()
        errorEventCallBacks.append(callback)
    }
    
    public func offError(_ callback: @escaping (any ICreateBackgroundAudioFail) -> Void) {
        errorEventCallBacks.removeAll()
    }
    
    public func onWaiting(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .waiting, eventCallback: callback)
    }
    
    public func offWaiting(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .waiting, eventCallback: callback)
    }
    
    public func onSeeking(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .seeking, eventCallback: callback)
    }
    
    public func offSeeking(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .seeking, eventCallback: callback)
    }
    
    public func onSeeked(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .seeked, eventCallback: callback)
    }
    
    public func offSeeked(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .seeked, eventCallback: callback)
    }
    
    public func onPrev(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .prev, eventCallback: callback)
    }
    
    public func offPrev(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .prev, eventCallback: callback)
    }
    
    public func onNext(_ callback: @escaping (Any) -> Void) {
        addEvent(event: .next, eventCallback: callback)
    }
    
    public func offNext(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .prev, eventCallback: callback)
    }
    
    public func play() {
        configureAudioSession()
        innerPlay(needDispathEvent: true)
        _isManualPlay = true
        _isManualPause = false
        updateNowPlayingInfoPlaybackRate(rate: 1.0)
    }
    
    public func pause() {
        if let player = player {
            player.pause()
            _isManualPause = true
            _isManualPlay = false
            dispatchEvent(event: .pause)
            updateNowPlayingInfoPlaybackRate(rate: 0.0)
        }
    }
    
    public func stop() {
        innerStop(needClearPlayingCenterInfo: true)
    }
}

extension UniBackgroundAudioManager {
    private func innerStop(needClearPlayingCenterInfo: Bool = false) {
        if let player = player {
            player.pause()
            _isManualPause = true
            _isManualPlay = false
            innerSeek(0)
            dispatchEvent(event: .stop)
            if needClearPlayingCenterInfo {
                clearPlayingCenterInfo()
            }
            updateNowPlayingInfoPlaybackRate(rate: 0.0)
        }
    }
    private func innerPlay(needDispathEvent: Bool? = false) {
        if let player = player {
            if self.startTime.toDoubleA() > 0 {
                innerSeek(self.startTime)
            }
            if !_hasPlayError {
                player.play()
                configPlayingCenterInfo()
            } else {
                if let errCode = _currentFailImpl?.errCode {
                    failedAction(errCode)
                }
            }
            if let needDispathEvent = needDispathEvent, needDispathEvent, !_hasPlayError, _readyToPlay {
                dispatchEvent(event: .play)
            }
        }
    }
    
    private func innerSeek(_ position: NSNumber, needDispathEvent: Bool? = false, completionHandler: ((Bool) -> Void)? = nil) {
        if (position.toDoubleA() >= 0) {
            let timeScale = player?.currentItem?.asset.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
            let seekTime = CMTime(seconds: position.toDoubleA(), preferredTimescale: timeScale)
            if let needDispathEvent = needDispathEvent, needDispathEvent {
                UNILogDebug("======audio======, Seeking started，调用seek方法后调用")
                dispatchEvent(event: .seeking)
            }
            _isSeeking = true
            player?.seek(to: seekTime, completionHandler: { [weak self] finished in
                
                if let needDispathEvent = needDispathEvent, needDispathEvent {
                    self?.dispatchEvent(event: .seeked)
                }
                self?._isSeeking = false
                completionHandler?(finished)
            })
        }
    }
    
    private func failedAction(_ errorCode: NSNumber, errMsg: String? = nil) {
        let failImpl = CreateBackgroundAudioFailImpl(errorCode)
        if let errMsg = errMsg {
            failImpl.errMsg = errMsg
        }
        _hasPlayError = true
        _currentFailImpl = failImpl
        errorEventCallBacks.forEach { $0(failImpl) }
        player?.pause()
    }
    
    // 初始化 AVPlayer 并配置选项
    private func configurePlayer() {
        player?.volume = self.volume.toFloatA()
        if self.startTime.toDoubleA() > 0 {
            innerSeek(self.startTime)
        }
        player?.rate = playbackRate?.toFloatA() ?? 1.0
    }
    
    // 设置播放源并更新 AVPlayerItem
    private func updatePlayerItem() {
        guard let player = player else { return }
        
        if src == "" {
            failedAction(1107609)
            return
        }
        var url: URL? = nil
        if self.src.startsWith("http") || self.src.startsWith("https") {
            if let _url = URL(string: self.src) {
                url = _url
            }
        } else {
            let temp = UTSiOS.convert2AbsFullPath(self.src)
            url = URL(fileURLWithPath: temp)
            if let path = url?.path {
                if (!FileManager.default.fileExists(atPath: path)) {
                    failedAction(1107603)
                    return
                }
            }
        }
        
        if let asset = player.currentItem?.asset as? AVURLAsset, asset.url == url {
            if _hasPlayError {
                innerSeek(0)
                if let errCode = _currentFailImpl?.errCode {
                    failedAction(errCode)
                }
            }
            return
        } else {
            _hasPlayError = false
        }
        
        playerItem = nil
        if let url = url {
            _readyToPlay = false
            playerItem = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: playerItem)
        }
        player.pause()
        
        // 监听各种状态
        addPlayerObservers()
        
        if autoplay {
            innerPlay()
        }
    }
    
    //释放资源
    private func releaseResources() {
        removePlayerObservers()
        pause()
        player = nil
        playerItem = nil
    }
}


//event事件
extension UniBackgroundAudioManager {
    private func addEvent(event: UniBackgroundAudioEvent, eventCallback: @escaping UniBackgroundAudioEventCallback) {
        guard let _ = player else { return }
        var callbacks = eventCallbacks[event.rawValue] ?? []
        callbacks.removeAll()
        let wrapper = CallbackWrapper(callback: eventCallback)
        callbacks.append(wrapper)
        eventCallbacks.set(event.rawValue, callbacks)
    }
    
    private func removeEvent(event: UniBackgroundAudioEvent,  eventCallback: @escaping UniBackgroundAudioEventCallback) {
        guard let _ = player else { return }
        if var callbacks = eventCallbacks.get(event.rawValue) {
            callbacks.removeAll()
            eventCallbacks.set(event.rawValue, callbacks)
        }
    }
    
    private func dispatchEvent(event: UniBackgroundAudioEvent, result: Any? = nil) {
        guard let _ = player else { return }
        eventCallbacks.get(event.rawValue)?.forEach({ callbackWrapper in
            switch callbackWrapper.callbackType {
            case .callback(let callback):
                UNILogDebug("======audio======, 触发事件：\(event.rawValue)")
                callback(result ?? UTSJSONObject())
            case .errorCallback(_):
                break
            }
        })
    }
}

//监听逻辑
extension UniBackgroundAudioManager {
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == UniBackgroundAudioObserveKeypath.status.rawValue {
            if let statusNumber =  change?[.newKey] as? NSNumber {
                let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) ?? .unknown
                handleAudioPlayerStatus(status)
            }
        } else if keyPath == UniBackgroundAudioObserveKeypath.rate.rawValue {
            //            UNILogDebug("======audio======, rate发生变化：\(player?.rate ?? 0)")
        } else if keyPath == UniBackgroundAudioObserveKeypath.loadedTimeRanges.rawValue {
            if let timeRange = playerItem?.loadedTimeRanges.first?.timeRangeValue {
                self.buffered = timeRange.end.seconds as NSNumber
            }
        } else if keyPath == UniBackgroundAudioObserveKeypath.playbackBufferEmpty.rawValue {
            UNILogDebug("======audio======, buffer empty, 但可能还在播放")
            dispatchEvent(event: .waiting)
        } else if keyPath == UniBackgroundAudioObserveKeypath.playbackLikelyToKeepUp.rawValue {
            UNILogDebug("======audio======, buffer 充足, 当前buffered = \(self.buffered)")
        } else if keyPath == UniBackgroundAudioObserveKeypath.timeControlStatus.rawValue {
            if let player = player {
                //                UNILogDebug("======audio======, 播放状态改变为 = \(player.timeControlStatus)")
                if player.timeControlStatus == .playing {
                    _hasPlayError = false
                    if _isNeedSetRate {
                        _isNeedSetRate = false
                        player.rate = playbackRate?.toFloatA() ?? 1.0
                    }
                } else {
                    _isNeedSetRate = true
                }
            }
        }
    }
    
    private func addPlayerObservers() {
        if let player = player, let currentItem = player.currentItem {
            player.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.timeControlStatus.rawValue, options: .new, context: nil)
            player.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.rate.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.status.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.loadedTimeRanges.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.playbackBufferEmpty.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.playbackLikelyToKeepUp.rawValue, options: .new, context: nil)
        }
        //监听播放完毕
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying(_:)),
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem
        )
        //监听播放中断，一般是缓冲暂停
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStalled(_:)),
            name: AVPlayerItem.playbackStalledNotification,
            object: playerItem
        )
        addPeriodicTimeObserver()
        listenerInterruption()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        //        //监听开始seek
        //        NotificationCenter.default.addObserver(
        //            self,
        //            selector: #selector(seekingStarted(_:)),
        //            name: AVPlayerItem.timeJumpedNotification,
        //            object: playerItem
        //        )
    }
    
    @objc private func handleAppStateChange(notification: Notification) {
        if notification.name == UIApplication.willResignActiveNotification {
            _isAppActive = false
        } else if notification.name == UIApplication.didBecomeActiveNotification {
            _isAppActive = true
        }
    }
    
    @objc private func handleEnterBackground() {
        _isAppActive = false
    }
    
    @objc private func seekingStarted(_ notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem else { return }
        let currentTime = CMTimeGetSeconds(playerItem.currentTime())
        if currentTime > 0 {
            UNILogDebug("======audio======, Seeking started，调用seek方法后调用")
            dispatchEvent(event: .seeking)
        }
    }
    
    @objc private func handlePlaybackStalled(_ notification: Notification) {
        UNILogDebug("======audio======, ")
        updateNowPlayingInfoPlaybackRate(rate: 0.0)
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        innerSeek(0)
        if self.loop {
            innerPlay()
        } else {
            UNILogDebug("======audio======, 播放结束")
            dispatchEvent(event: .ended)
            clearPlayingCenterInfo()
        }
    }
    
    private func removePlayerObservers() {
        if let player = player, let currentItem = player.currentItem {
            player.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.timeControlStatus.rawValue, context: nil)
            player.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.rate.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.status.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.loadedTimeRanges.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.playbackBufferEmpty.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniBackgroundAudioObserveKeypath.playbackLikelyToKeepUp.rawValue, context: nil)
        }
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.timeJumpedNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        removePeriodicTimeObserver()
        removeListenerInterruption()
        removePeriodicTimeObserver()

        player?.replaceCurrentItem(with: nil)
    }
    
    // 添加播放进度监听
    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        
        // 设置观察间隔
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // 添加时间观察器
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let currentTime = CMTimeGetSeconds(time)
            
            if let duration = self?.player?.currentItem?.duration, duration.isNumeric {
                if let isSeeking = self?._isSeeking, !isSeeking {
                    UNILogDebug("======audio======, 当前时间: \(currentTime), 总时长: \(CMTimeGetSeconds(duration))")
                    self?.dispatchEvent(event: .timeUpdate)
                    self?.updateNowPlayingInfoElapsedTime(time: currentTime)
                }
            }
        }
    }
    
    // 移除时间观察器
    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func handleAudioPlayerStatus(_ status: AVPlayerItem.Status) {
        _status = status
        switch status {
        case .readyToPlay:
            dispatchEvent(event: .canplay)
            if !_readyToPlay {
                if _isManualPlay {
                    dispatchEvent(event: .play)
                }
                _readyToPlay = true
            }
            
            UNILogDebug("======audio======, AVPlayerItem is ready to play")
        case .failed:
            UNILogDebug("======audio======, AVPlayerItem failed, 获取错误的域和错误码以进一步分析失败原因")
            if let error = playerItem?.error as NSError? {
                if error.domain == NSURLErrorDomain {
                    failedAction(1107602, errMsg: error.localizedDescription)
                } else if error.domain == AVFoundationErrorDomain {
                    failedAction(1107604)
                }
            } else {
                failedAction(117605)
            }
        case .unknown:
            UNILogDebug("======audio======, AVPlayerItem status is unknown")
            failedAction(117605)
        @unknown default:
            UNILogDebug("======audio======, AVPlayerItem status is unknown default case")
            failedAction(117605)
        }
    }
}

extension UniBackgroundAudioManager {
    
    // 配置音频会话，支持后台播放
    private func configureAudioSession() {
        if _hasConfigAudioSession { return }
        _hasConfigAudioSession = true
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            UNILogDebug("======audio======, Failed to set up audio session: \(error)")
        }
    }
    
    // 在销毁或停止时恢复音频会话状态
    private func deactivateAudioSession() {
        clearPlayingCenterInfo()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            UNILogDebug("======audio======, Failed to deactivate audio session: \(error)")
        }
    }
    
    private func configureRemoteCommandCenter() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.innerStop(needClearPlayingCenterInfo: true)
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.innerStop(needClearPlayingCenterInfo: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.dispatchEvent(event: .next)
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.innerStop(needClearPlayingCenterInfo: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.dispatchEvent(event: .prev)
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?._isPlaying == true {
                self?.pause()
            } else {
                self?.play()
            }
            return .success
        }

        setRatingCommand(commandCenter)
        setChangePlaybackPositionCommand(commandCenter)
    }
    
    private func setLikeCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.addTarget { event in
            guard let command = event.command as? MPFeedbackCommand else {
                return .commandFailed
            }
            if command.isActive {
                commandCenter.likeCommand.isEnabled = false
                commandCenter.dislikeCommand.isEnabled = true
                commandCenter.dislikeCommand.addTarget { event in
                    guard let command = event.command as? MPFeedbackCommand else {
                        return .commandFailed
                    }
                    if command.isActive {
                        command.isEnabled = false
                    }
                    return .success
                }
            }
            return .success
        }
    }
    
    //实现后台播放控制中心进度条seek功能
    private func setChangePlaybackPositionCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            let seekTime = NSNumber(value: event.positionTime)
            innerSeek(seekTime, needDispathEvent: true, completionHandler: { [weak self] completed in
                if completed {
                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self?.currentTime
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self?.player?.rate
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            })
            return .success
        }
    }
    
    //实现后台播放控制中心评分功能
    private func setRatingCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.ratingCommand.isEnabled = true
        commandCenter.ratingCommand.minimumRating = 0.0
        commandCenter.ratingCommand.maximumRating = 5.0
        commandCenter.ratingCommand.addTarget { [weak self] event in
            guard let _ = self else { return .commandFailed }
            
            if let ratingEvent = event as? MPRatingCommandEvent {
                let rating = ratingEvent.rating
                UNILogDebug("======audio======, 用户评分rating= \(rating)")
                return .success
            }
            return .commandFailed
        }
    }
    
    private func updateNowPlayingInfoElapsedTime(time: TimeInterval) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfoPlaybackRate(rate: Float) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func configPlayingCenterInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo.set(MPMediaItemPropertyTitle, title)
        nowPlayingInfo.set(MPMediaItemPropertyAlbumTitle, epname)
        nowPlayingInfo.set(MPMediaItemPropertyArtist, singer)
        if let remoteControlCoverImage = remoteControlCoverImage {
            let itemArtwork = MPMediaItemArtwork.init(boundsSize: remoteControlCoverImage.size) { _ in
                return remoteControlCoverImage
            }
            nowPlayingInfo.set(MPMediaItemPropertyArtwork, itemArtwork)
        }
        nowPlayingInfo.set(MPMediaItemPropertyPlaybackDuration, self.duration)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func clearPlayingCenterInfo() {
        UIApplication.shared.endReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        _hasConfigAudioSession = false
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
    }
    
    private func listenerInterruption() {
        // 监听音频被其他三方中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // 监听耳机或其他音频设备插拔
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChangeListenerCallback(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    private func removeListenerInterruption() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        UNILogDebug("======audio======, 监听音频被其他三方中断")
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            UNILogDebug("======audio======, 音频中断开始")
            pause()
        case .ended:
            UNILogDebug("======audio======, 音频中断结束时的处理逻辑")
            play()
        @unknown default:
            break
        }
    }
    
    @objc private func audioRouteChangeListenerCallback(_ notification: Notification) {
        UNILogDebug("======audio======, 监听耳机或其他音频设备插拔")
        guard let interruptionDict = notification.userInfo,
              let routeChangeReasonValue = interruptionDict[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let routeChangeReason = AVAudioSession.RouteChangeReason(rawValue: routeChangeReasonValue) else {
            return
        }
        
        switch routeChangeReason {
        case .newDeviceAvailable:
            UNILogDebug("======audio======, 耳机或其他音频设备插入")
        case .oldDeviceUnavailable:
            UNILogDebug("======audio======, 耳机或其他音频设备拔出")
            pause()
        case .categoryChange:
            UNILogDebug("======audio======, 音频会话类别发生变化")
        default:
            break
        }
    }
}

extension NSNumber {
    func toDoubleA() -> Double {
        return Double(truncating: self)
    }
    
    func toFloatA() -> Float {
        return Float(truncating: self)
    }
}
