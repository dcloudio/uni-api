import AVFoundation
import MediaPlayer
import DCloudUniappRuntime
@_implementationOnly import KTVHTTPCache

private enum UniAudioObserveKeypath: String {
    case status = "status"
    case timeControlStatus = "timeControlStatus"
    case rate = "rate"
    case loadedTimeRanges = "loadedTimeRanges"
    case playbackBufferEmpty = "playbackBufferEmpty"
    case playbackLikelyToKeepUp = "playbackLikelyToKeepUp"
}

private enum UniAudioEvent: String {
    case canplay = "canplay"
    case play = "play"
    case pause = "pause"
    case stop = "stop"
    case ended = "ended"
    case timeUpdate = "timeUpdate"
    case waiting = "waiting"
    case seeking = "seeking"
    case seeked = "seeked"
}

// 闭包class化，方便通过 == 对比
private class CallbackWrapper: Equatable {
    enum CallbackType {
        case callback(UniAudioEventCallback)
        case errorCallback(UniAudioErrorEventCallback)
    }
    
    let callbackType: CallbackType
    
    init(callback: @escaping UniAudioEventCallback) {
        self.callbackType = .callback(callback)
    }
    
    init(errorCallback: @escaping UniAudioErrorEventCallback) {
        self.callbackType = .errorCallback(errorCallback)
    }
    
    public static func == (lhs: CallbackWrapper, rhs: CallbackWrapper) -> Bool {
        return lhs === rhs
    }
}

typealias UniAudioEventCallback = (_ result: Any) -> Void
typealias UniAudioErrorEventCallback = (_ result: ICreateInnerAudioContextFail) -> Void

public class UniAudioPlayer: NSObject, InnerAudioContext {
    
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
    private var _autoplay: Bool = false {
        didSet {
            if player?.timeControlStatus != .playing && !_isManualPause {
                innerPlay(needDispathEvent: true)
            }
        }
    }
    private var _loop: Bool = false
    private var _cache: Bool = true {
        didSet {
            if _isActuallyPlaying == false {
                initCacheConfig()
                player?.replaceCurrentItem(with: nil)
                updatePlayerItem()
            }
        }
    }
    
    private var _isActuallyPlaying: Bool {
        guard let currentItem = player?.currentItem else { return false }
        return  player?.rate != 0 &&
        player?.error == nil &&
        currentItem.status == .readyToPlay &&
        currentItem.isPlaybackLikelyToKeepUp
    }

    private var _volume: NSNumber = 1.0 {
        didSet {
            player?.volume = _volume.toFloat()
        }
    }
    private var _playbackRate: NSNumber = 1.0 {
        didSet {
            if player?.timeControlStatus == .playing {
                player?.rate = _playbackRate.toFloat()
            } else {
                player?.pause()
            }
        }
    }
    private var _isNeedSetRate = false //添加该变量优化系统默认的只有播放状态设置rate才有效的情况
    private var _status: AVPlayerItem.Status? //playitem 监听status状态
    private var _isManualPlay = false  //是否正在播放，侧重于用户是否点击了播放按钮
    private var _isManualPause = false //是否用户点击暂停，和缓冲的暂停无关
    private var _hasPlayError = false //是否播放出错
    private var _currentFailImpl: CreateInnerAudioContextFailImpl? = nil //当前播放出错error对象
    private var _isSeeking = false //是否是正在seeking状态
    private var _readyToPlay = false //是否canPlay状态
    private var _cacheSize: Int64 = 100*1024*1024 //默认缓存大小100M
    private var _hasAddObservers = false //是否添加了观察者
    
    private var eventCallbacks: [String: [CallbackWrapper]] = [:]
    private var errorEventCallBacks: [UniAudioErrorEventCallback] = []
    private var timeObserverToken: Any?
    
    public var duration: NSNumber {
        get {
            var tmp = playerItem?.asset.duration.seconds.round(3) ?? 0.0
            if tmp.isNaN || tmp.isInfinite {
                tmp = 0.0
            }
            return NSNumber(floatLiteral: tmp)
        }
        set {}
    }
    
    public var currentTime: NSNumber {
        get {
            var second = 0.0
            if let temp = player?.currentTime().seconds, temp >= 0 {
                second = temp
            }
            return NSNumber(floatLiteral: second.round(3))
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
            if _playbackRate != newValue && !isHLSLiveOrEvent() {
                _isNeedSetRate = true
                _playbackRate = newValue ?? 1.0
            }
        }
    }
    
    public var cache: Bool {
        get { return _cache }
        set { _cache = newValue }
    }
    
    public func seek(_ position: NSNumber) {
        innerSeek(position, needDispathEvent: true)
    }
    
    public override init() {
        super.init()
        configurePlayer()
    }
    
    deinit {
        destroy()
    }
    
    public func destroy() {
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
        addPeriodicTimeObserver()
    }
    
    public func offTimeUpdate(_ callback: @escaping (Any) -> Void) {
        removeEvent(event: .timeUpdate, eventCallback: callback)
        removePeriodicTimeObserver()
    }
    
    public func onError(_ callback: @escaping (any ICreateInnerAudioContextFail) -> Void) {
        errorEventCallBacks.append(callback)
    }
    
    public func offError(_ callback: @escaping (any ICreateInnerAudioContextFail) -> Void) {
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
    
    public func play() {
        innerPlay(needDispathEvent: true)
        _isManualPlay = true
        _isManualPause = false
    }
    
    public func pause() {
        if let player = player {
            player.pause()
            _isManualPause = true
            _isManualPlay = false
            dispatchEvent(event: .pause)
        }
    }
    
    public func stop() {
        if let player = player {
            player.pause()
            _isManualPause = true
            _isManualPlay = false
            innerSeek(0)
            dispatchEvent(event: .stop)
        }
    }
}

extension UniAudioPlayer {
    private func initCacheConfig() {
        if self._cache == false { return }
        
        //设置是否显示KTVHTTPCache的log日志
        KTVHTTPCache.logSetConsoleLogEnable(false)
        try? KTVHTTPCache.proxyStart()
        KTVHTTPCache.cacheSetMaxCacheLength(_cacheSize)
        KTVHTTPCache.cacheSetRootPath("Caches/uni-audio")
        //配置MIME类型集
        let contentTypes: [String] = [
            "audio/wav",
            "audio/flac",
            "audio/aiff",
            "audio/caf",
            "audio/mpeg",
            "audio/mp4",
            "audio/m4a",
            "audio/x-m4a",
            "audio/aac",
            "audio/*" //通配符
        ]
        //设置可接受的内容类型
        KTVHTTPCache.downloadSetAcceptableContentTypes(contentTypes)
        
        //通过拦截url中的contentType动态设置是否要继续请求
        KTVHTTPCache.downloadSetUnacceptableContentTypeDisposer { url, contentType in
            if let contentType = contentType {
                UNILogDebug("======audio======, KTVHTTPCache Intercepted Content-Type: \(contentType)")
            }
            return true
        }
    }
    
    private func innerPlay(needDispathEvent: Bool? = false) {
        if let player = player {
            if self.startTime.toDouble() > 0 {
                innerSeek(self.startTime)
            }
            if !_hasPlayError {
                // 恢复播放前，判断当前位置是否还在 seekable 范围内
                if let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue {
                    let rangeStart = CMTimeGetSeconds(range.start)
                    let rangeEnd = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
                    let current = CMTimeGetSeconds(player.currentTime())
                    
                    /// 如果rangeStart == rangeEnd 或者 duration过小，就是直播源的server没有配置Event模式（服务器没有提供 DVR 缓存窗口），只能seek到当前播放点，没有快退能力，
                    let duration = CMTimeGetSeconds(range.duration)
                    let isSupportDVR = duration > 10
                    
                    if (current < rangeStart || current > rangeEnd) && !isSupportDVR {
                        // 已经不在可播放范围，回到直播点
                        player.seek(to: CMTime(seconds: rangeEnd, preferredTimescale: 600)) {
                            _ in player.play()
                        }
                    } else {
                        // 在范围内，继续播放
                        player.play()
                    }
                } else {
                    player.play()
                }
            }
            if let needDispathEvent = needDispathEvent, needDispathEvent, !_hasPlayError, _readyToPlay {
                dispatchEvent(event: .play)
            }
        }
    }
    
    private func innerSeek(_ position: NSNumber, needDispathEvent: Bool? = false) {
        guard let player = player, let currentItem = player.currentItem else { return }
        
        // 检查 AVPlayerItem 状态
        if currentItem.status != .readyToPlay {
            UNILogDebug("======audio======, Player item is not ready to play, skipping seek.")
            return
        }
        
        if (position.toDouble() >= 0) {
            let timeScale = player.currentItem?.asset.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
            let seekTime = CMTime(seconds: position.toDouble(), preferredTimescale: timeScale)
            if !seekTime.isValid || seekTime.isIndefinite {
                UNILogDebug("======audio======, Invalid seek time, skipping seek.")
                return
            }
            if let needDispathEvent = needDispathEvent, needDispathEvent {
                UNILogDebug("======audio======, Seeking started，调用seek方法后调用")
                dispatchEvent(event: .seeking)
                _isSeeking = true
            }
            
            player.seek(to: seekTime, completionHandler: { [weak self] finished in
                self?.dispatchEvent(event: .seeked)
                self?._isSeeking = false
            })
        }
    }
    
    private func failedAction(_ errorCode: NSNumber, errMsg: String? = nil) {
        let failImpl = CreateInnerAudioContextFailImpl(errorCode)
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
        initCacheConfig()
        player?.volume = self.volume.toFloat()
        if self.startTime.toDouble() > 0 {
            innerSeek(self.startTime)
        }
        player?.rate = playbackRate?.toFloat() ?? 1.0
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
        
        var tempCacheUrl: URL?
        
        let isM3u8 = url?.path.lowercased().contains("m3u8") ?? false
        if let cacheUrl = KTVHTTPCache.cacheCompleteFileURL(with: url), !isM3u8, self._cache {
            tempCacheUrl = cacheUrl
        }
        if let asset = player.currentItem?.asset as? AVURLAsset, (asset.url == url || asset.url == tempCacheUrl) {
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
            if let scheme = url.scheme, scheme.startsWith("http"), self._cache {
                var _cacheUrl: URL
                if let cacheUrl = KTVHTTPCache.cacheCompleteFileURL(with: url), !isM3u8 {
                    _cacheUrl = cacheUrl
                } else {
                    let headers = [
                        "User-Agent": UTSiOS.getUserAgent(),
                        "Cookie": UTSiOS.getCookieString(url)
                    ]
                    KTVHTTPCache.downloadSetAdditionalHeaders(headers)
                    _cacheUrl = KTVHTTPCache.proxyURL(withOriginalURL: url, bindToLocalhost: false)
                }
                playerItem = AVPlayerItem(url: _cacheUrl)
            } else {
                playerItem = AVPlayerItem(url: url)
            }
            
            player.replaceCurrentItem(with: playerItem)
        }
        player.pause()
        
        // 监听各种状态
        addPlayerObservers()
        
        if autoplay {
            innerPlay()
        }
    }
    
    /// 判断是不是HLS 流是不是 live / event
    private func isHLSLiveOrEvent() -> Bool {
        guard let playerItem = player?.currentItem, playerItem.status == .readyToPlay else {
            return false
        }
        
        if playerItem.duration.isIndefinite {
            return true
        }
        
        return false
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
extension UniAudioPlayer {
    private func addEvent(event: UniAudioEvent, eventCallback: @escaping UniAudioEventCallback) {
        guard let _ = player else { return }
        var callbacks = eventCallbacks[event.rawValue] ?? []
        let wrapper = CallbackWrapper(callback: eventCallback)
        if !callbacks.contains(wrapper) {
            callbacks.append(wrapper)
            eventCallbacks.set(event.rawValue, callbacks)
        }
    }
    
    private func removeEvent(event: UniAudioEvent,  eventCallback: @escaping UniAudioEventCallback) {
        guard let _ = player else { return }
        if var callbacks = eventCallbacks.get(event.rawValue) {
            callbacks.removeAll()
            eventCallbacks.set(event.rawValue, callbacks)
        }
    }
    
    private func dispatchEvent(event: UniAudioEvent, result: Any? = nil) {
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
extension UniAudioPlayer {
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == UniAudioObserveKeypath.status.rawValue {
            if let statusNumber =  change?[.newKey] as? NSNumber {
                let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) ?? .unknown
                handleAudioPlayerStatus(status)
            }
        } else if keyPath == UniAudioObserveKeypath.rate.rawValue {
            //            UNILogDebug("======audio======, rate发生变化：\(player?.rate ?? 0)")
        } else if keyPath == UniAudioObserveKeypath.loadedTimeRanges.rawValue {
            if let timeRange = playerItem?.loadedTimeRanges.first?.timeRangeValue {
                self.buffered = (timeRange.end.seconds.round(3) as NSNumber)
            }
        } else if keyPath == UniAudioObserveKeypath.playbackBufferEmpty.rawValue {
            UNILogDebug("======audio======, buffer empty, 但可能还在播放")
            dispatchEvent(event: .waiting)
        } else if keyPath == UniAudioObserveKeypath.playbackLikelyToKeepUp.rawValue {
            UNILogDebug("======audio======, buffer 充足, 当前buffered = \(self.buffered)")
        } else if keyPath == UniAudioObserveKeypath.timeControlStatus.rawValue {
            if let player = player {
                //                UNILogDebug("======audio======, 播放状态改变为 = \(player.timeControlStatus)")
                if player.timeControlStatus == .playing {
                    _hasPlayError = false
                    if _isNeedSetRate {
                        _isNeedSetRate = false
                        player.rate = playbackRate?.toFloat() ?? 1.0
                    }
                } else {
                    _isNeedSetRate = true
                }
            }
        }
    }
    
    private func addPlayerObservers() {
        guard let player = player else { return }
        if !_hasAddObservers {
            player.addObserver(self, forKeyPath: UniAudioObserveKeypath.timeControlStatus.rawValue, options: .new, context: nil)
            player.addObserver(self, forKeyPath: UniAudioObserveKeypath.rate.rawValue, options: .new, context: nil)
        }
        
        if let currentItem = player.currentItem {
            currentItem.addObserver(self, forKeyPath: UniAudioObserveKeypath.status.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniAudioObserveKeypath.loadedTimeRanges.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniAudioObserveKeypath.playbackBufferEmpty.rawValue, options: .new, context: nil)
            currentItem.addObserver(self, forKeyPath: UniAudioObserveKeypath.playbackLikelyToKeepUp.rawValue, options: .new, context: nil)
        }
        //监听播放完毕
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying(_:)),
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem
        )
        _hasAddObservers = true
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        innerSeek(0)
        if self.loop {
            innerPlay()
        } else {
            UNILogDebug("======audio======, 播放结束")
            dispatchEvent(event: .ended)
        }
    }
    
    private func removePlayerObservers() {
        removePeriodicTimeObserver()
        if let player = player, let currentItem = player.currentItem {
            player.removeObserver(self, forKeyPath: UniAudioObserveKeypath.timeControlStatus.rawValue, context: nil)
            player.removeObserver(self, forKeyPath: UniAudioObserveKeypath.rate.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniAudioObserveKeypath.status.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniAudioObserveKeypath.loadedTimeRanges.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniAudioObserveKeypath.playbackBufferEmpty.rawValue, context: nil)
            currentItem.removeObserver(self, forKeyPath: UniAudioObserveKeypath.playbackLikelyToKeepUp.rawValue, context: nil)
        }
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        
        player?.replaceCurrentItem(with: nil)
        _hasAddObservers = false
    }
    
    // 添加播放进度监听
    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        
        // 设置观察间隔
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // 添加时间观察器
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let currentTime = CMTimeGetSeconds(time)
            
            if let duration = self?.player?.currentItem?.duration {
                if let isSeeking = self?._isSeeking, !isSeeking, let iaPaused = self?.paused, !iaPaused {
                    UNILogDebug("======audio======, 当前时间: \(currentTime), 总时长: \(CMTimeGetSeconds(duration))")
                    self?.dispatchEvent(event: .timeUpdate)
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

extension NSNumber {
    func toDouble() -> Double {
        return Double(truncating: self)
    }
    
    func toFloat() -> Float {
        return Float(truncating: self)
    }
    
    /// 设置最多小数点位数, 显示控制直接移除小数点位数
    func maximumFractionDigits(_ count: Int) -> NSNumber {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = count
        return formatter.number(from: formatter.string(from: self) ?? self.stringValue) ?? self
    }
}
