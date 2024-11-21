@file:Suppress(
    "UNCHECKED_CAST",
    "USELESS_CAST",
    "INAPPLICABLE_JVM_NAME",
    "UNUSED_ANONYMOUS_PARAMETER"
)

package uts.sdk.modules.uniGetBackgroundAudioManager;

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import com.google.android.exoplayer2.DeviceInfo
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.MediaMetadata
import com.google.android.exoplayer2.PlaybackException
import com.google.android.exoplayer2.PlaybackParameters
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.Timeline
import com.google.android.exoplayer2.Tracks
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.text.Cue
import com.google.android.exoplayer2.text.CueGroup
import com.google.android.exoplayer2.trackselection.TrackSelectionParameters
import com.google.android.exoplayer2.video.VideoSize
import io.dcloud.uts.UTSAndroid
import io.dcloud.uts.UTSArray
import io.dcloud.uts.UTSJSONObject
import io.dcloud.uts.clearInterval
import io.dcloud.uts.compareTo
import io.dcloud.uts.setInterval
import io.dcloud.uts.times
import io.dcloud.uts.utsArrayOf

typealias EventCallback = (result: Any) -> Unit;

open class BackgroundAudioPlayer : BackgroundAudioManager, Player.Listener,
    AudioManager.OnAudioFocusChangeListener {
    open var _src: String = "";

    companion object {
        private lateinit var backgroundAudioPlayer: BackgroundAudioPlayer
        fun getInstance(): BackgroundAudioPlayer {
            if (!::backgroundAudioPlayer.isInitialized) {
                backgroundAudioPlayer = BackgroundAudioPlayer()
            }
            return backgroundAudioPlayer
        }
    }

    override var src: String
        get(): String {
            return this._src;
        }
        set(src: String) {
            if (this._src == src) {
                return;
            }
            if (this._src == "") {
                this.changeSRC(src);
                return;
            } else {
                this.stop();
            }
            this.changeSRC(src);
        }

    open fun changeSRC(src: String) {
        this._src = src;
        var mediaItem = MediaItem.fromUri(this._src);
        this.player.setMediaItem(mediaItem);
        this.player.prepare();
        if (this._startTime > 0) {
            this.player.seekTo((this._startTime * 1000).toLong());
        }
        if (this._autoplay) {
            this.play();
        }
    }

    open var _startTime: Number = 0;
    override var startTime: Number
        get(): Number {
            return this._startTime;
        }
        set(startTime: Number) {
            if (startTime <= 0) {
                return;
            }
            this._startTime = startTime;
            if (this._src != "" && !this.player.isPlaying() && !this.isPausedByUser) {
                this.player.seekTo((this._startTime * 1000).toLong());
            }
        }
    open var _autoplay: Boolean = false;
    open var autoplay: Boolean
        get(): Boolean {
            return this._autoplay;
        }
        set(autoplay: Boolean) {
            this._autoplay = autoplay;
            if (this._src == "") {
                return;
            }
            if (!this.player.isPlaying() && !this.isPausedByUser) {
                this.play();
            }
        }
    open var _loop: Boolean = false;
    open var loop: Boolean
        get(): Boolean {
            return this._loop;
        }
        set(startTime: Boolean) {
            this._loop = startTime;
            if (this._loop) {
                this.player.repeatMode = Player.REPEAT_MODE_ONE;
            } else {
                this.player.repeatMode = Player.REPEAT_MODE_OFF;
            }
        }
    open var _obeyMuteSwitch: Boolean = true;
    open var obeyMuteSwitch: Boolean
        get(): Boolean {
            return this._obeyMuteSwitch;
        }
        set(startTime: Boolean) {
            this._obeyMuteSwitch = startTime;
        }
    override var duration: Number
        get(): Number {
            if (this.player.playbackState == Player.STATE_READY || this.player.playbackState == Player.STATE_ENDED) {
                return this.player.duration / 1000;
            } else {
                return 0;
            }
        }
        set(_) {}
    override var currentTime: Number
        get(): Number {
            if (this.player.isPlaying()) {
                return this.player.getCurrentPosition() / 1000;
            }
            return 0;
        }
       set(currentTime) {
           val positionInMillis = (currentTime.toDouble() * 1000).toLong()
           this.player.seekTo(positionInMillis)
       }
    override var paused: Boolean
        get(): Boolean {
            return !this.player.isPlaying();
        }
        set(_) {}
    override var buffered: Number
        get(): Number {
            return this.player.getBufferedPosition();
        }
        set(_) {}
    open var _volume: Number = 0;
    open var volume: Number
        get(): Number {
            return this.player.getVolume();
        }
        set(volume: Number) {
            var tVolume = volume;
            if (volume > 1) {
                tVolume = 1;
            } else if (volume < 0) {
                tVolume = 0;
            }
            this.player.setVolume(tVolume.toFloat());
            this._volume = tVolume;
        }
    open var _sessionCategory: String = "";
    open var _playbackRate: Number? = 1.0;
    override var playbackRate: Number?
        get(): Number? {
            return this._playbackRate;
        }
        set(rate: Number?) {
            if (utsArrayOf(
                    0.5,
                    0.8,
                    1.0,
                    1.25,
                    1.5,
                    2.0
                ).indexOf(rate) > 0
            ) {
                this.player.setPlaybackSpeed(rate!!.toFloat());
            }
        }
    override var title = "";
    override var epname = "";
    override var singer = "";
    override var coverImgUrl = "";
    override var webUrl = "";
    override var protocol = "";
    open var player: ExoPlayer;
    open var callbacks = HashMap<String, UTSArray<EventCallback>>();
    open var isPausedByUser: Boolean = false;
    open var isSeeking: Boolean = false;
    open var audioManager: AudioManager;

    constructor() {
        this.player = ExoPlayer.Builder(UTSAndroid.getAppContext()!!).build();
        this.player.addListener(this);
        this.audioManager =
            UTSAndroid.getAppContext()!!.getSystemService(Context.AUDIO_SERVICE) as AudioManager;
    }

    private fun stopPlayService() {
        UTSAndroid.getAppContext()
            ?.stopService(Intent(UTSAndroid.getAppContext(), AudioService::class.java))
    }

    fun playInService() {
        if (this._src == "") {
            // var errorResult: UTSJSONObject = object : UTSJSONObject() {
            //     var errCode: Number = -1
            //     var errMsg = "empty src"
            // };
            invokeCallBack("error")
            return;
        }

        if (this.player.playbackState == Player.STATE_IDLE) {//停止后播放
            var mediaItem = MediaItem.fromUri(this._src);
            this.player.setMediaItem(mediaItem);
            this.player.prepare();
        }
        this.isPausedByUser = false;
        if (this.player.playbackState == Player.STATE_READY) {//暂停后播放
            if (this.isSeeking) {
                this.isSeeking = false;
                invokeCallBack("seeked")
            }
            invokeCallBack("play")
        }
        this.player.playWhenReady = true;
        this.registerAudioManager();

    }

    override fun play() {
        startAudioService()
    }

    private fun startAudioService() {
        UTSAndroid.getAppContext()
            ?.startService(
                Intent(
                    UTSAndroid.getAppContext(),
                    AudioService::class.java
                )
            )
    }

    override fun pause() {
        this.isPausedByUser = true;
        this.player.playWhenReady = false;
        this.player.pause();
        this.unregisterAudioManager();
        invokeCallBack("pause")
    }

    fun invokeCallBack(action: String) {
        this.callbacks[action]?.forEach(fun(item: EventCallback) {
            item(UTSJSONObject());
        })
    }

    override fun stop() {
        this.isPausedByUser = true;
        this.player.playWhenReady = false;
        this.player.stop();
        this.unregisterAudioManager();
        invokeCallBack("stop")
        stopPlayService()
    }

    override fun seek(position: Number) {
        if (position > 0) {
            this.isSeeking = true;
            this.player.seekTo((position * 1000).toLong());
            invokeCallBack("seeking")
        }
    }
    @Suppress("DEPRECATION")
    open fun registerAudioManager() {
        this.audioManager.requestAudioFocus(
            this,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN
        );
    }
    @Suppress("DEPRECATION")
    open fun unregisterAudioManager() {
        this.audioManager.abandonAudioFocus(this);
    }

    override fun onAudioFocusChange(focusChange: Int) {
        if (focusChange == AudioManager.AUDIOFOCUS_LOSS || focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT || focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
            this.pause();
        } else if (focusChange == AudioManager.AUDIOFOCUS_GAIN) {
        }
    }

    open fun addEvent(action: String, callback: EventCallback) {
        var playArray = this.callbacks.get(action);
        if (playArray == null) {
            playArray = UTSArray<EventCallback>();
        }
        playArray.push(callback);
        this.callbacks.put(action, playArray);
    }

    open fun removeEvent(action: String, callback: EventCallback) {
        var playArray = this.callbacks.get(action) ?: return;
        if (playArray.indexOf(callback) > 0) {
            playArray.splice(playArray.indexOf(callback), 1);
            this.callbacks[action] = playArray;
        }
    }

    override fun onCanplay(callback: EventCallback) {
        this.addEvent("canplay", callback);
    }

    open fun offCanplay(callback: EventCallback) {
        this.removeEvent("canplay", callback);
    }

    override fun onPlay(callback: EventCallback) {
        this.addEvent("play", callback);
    }

    open fun offPlay(callback: EventCallback) {
        this.removeEvent("play", callback);
    }

    override fun onPause(callback: EventCallback) {
        this.addEvent("pause", callback);
    }

    open fun offPause(callback: EventCallback) {
        this.removeEvent("pause", callback);
    }

    override fun onStop(callback: EventCallback) {
        this.addEvent("stop", callback);
    }

    open fun offStop(callback: EventCallback) {
        this.removeEvent("stop", callback);
    }

    override fun onEnded(callback: EventCallback) {
        this.addEvent("ended", callback);
    }

    override fun onTimeUpdate(callback: EventCallback) {
        this.addEvent("timeUpdate", callback);
        this.startTimeUpdate();
    }

    override fun onPrev(callback: EventCallback) {
        this.addEvent("prev", callback);
    }

    override fun onNext(callback: EventCallback) {
        this.addEvent("next", callback);
    }

    open fun offTimeUpdate(callback: EventCallback) {
        this.removeEvent("timeUpdate", callback);
        this.stopTimeUpdate();
    }

    override fun onError(callback: EventCallback) {
        this.addEvent("error", callback);
    }

    open fun offError(callback: EventCallback) {
        this.removeEvent("error", callback);
    }

    override fun onWaiting(callback: EventCallback) {
        this.addEvent("waiting", callback);
    }

    open fun offWaiting(callback: EventCallback) {
        this.removeEvent("waiting", callback);
    }

    open fun onSeeking(callback: EventCallback) {
        this.addEvent("seeking", callback);
    }

    open fun offSeeking(callback: EventCallback) {
        this.removeEvent("seeking", callback);
    }

    open fun onSeeked(callback: EventCallback) {
        this.addEvent("seeked", callback);
    }

    open fun offSeeked(callback: EventCallback) {
        this.removeEvent("seeked", callback);
    }

    open var isTriggerTimeUpdate = false;
    open var timeUpdateInterval: Number = 0;
    open fun startTimeUpdate() {
        if (this.isTriggerTimeUpdate) {
            return;
        }
        this.isTriggerTimeUpdate = true;
        this.timeUpdateInterval = setInterval(fun() {
            if (this.player.isPlaying) {
                invokeCallBack("timeUpdate")
            }
        }, 750);
    }

    open fun stopTimeUpdate() {
        if (!this.isTriggerTimeUpdate) {
            return;
        }
        var timeUpdate = this.callbacks["timeUpdate"];
        if (timeUpdate == null || timeUpdate.size == 0) {
            clearInterval(this.timeUpdateInterval.toInt());
            this.timeUpdateInterval = 0;
            this.isTriggerTimeUpdate = false;
        }
    }

    override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {}
    override fun onPlayerError(error: PlaybackException) {
        // var errorResult: UTSJSONObject = object : UTSJSONObject() {
        //     var errCode = error.errorCode
        //     var errMsg = error.message
        // };
       invokeCallBack("error")
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        if (playbackState == Player.STATE_BUFFERING) {
            invokeCallBack("waiting")
        } else if (playbackState == Player.STATE_READY) {
            if (!this.isPausedByUser && this.isSeeking) {
                this.isSeeking = false;
                invokeCallBack("seeked")
            } else {
                invokeCallBack("canplay")
                if (this.player.playWhenReady) {
                    invokeCallBack("play")
                }
            }
        } else if (playbackState == Player.STATE_ENDED) {
            invokeCallBack("ended")
        }
    }


    override fun onEvents(player: Player, events: Player.Events) {}
    override fun onTimelineChanged(timeline: Timeline, reason: Int) {}
    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {}
    override fun onTracksChanged(tracks: Tracks) {}
    override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {}
    override fun onPlaylistMetadataChanged(mediaMetadata: MediaMetadata) {}
    override fun onIsLoadingChanged(isLoading: Boolean) {}
    override fun onLoadingChanged(isLoading: Boolean) {}
    override fun onAvailableCommandsChanged(availableCommands: Player.Commands) {}
    override fun onTrackSelectionParametersChanged(parameters: TrackSelectionParameters) {}
    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {}
    override fun onPlaybackSuppressionReasonChanged(playbackSuppressionReason: Int) {}
    override fun onIsPlayingChanged(isPlaying: Boolean) {}
    override fun onRepeatModeChanged(repeatMode: Int) {}
    override fun onShuffleModeEnabledChanged(shuffleModeEnabled: Boolean) {}
    override fun onPlayerErrorChanged(error: PlaybackException?) {}
    override fun onPositionDiscontinuity(reason: Int) {}
    override fun onPositionDiscontinuity(
        oldPosition: Player.PositionInfo,
        newPosition: Player.PositionInfo,
        reason: Int
    ) {}
    override fun onPlaybackParametersChanged(playbackParameters: PlaybackParameters) {}
    override fun onSeekBackIncrementChanged(seekBackIncrementMs: Long) {}
    override fun onSeekForwardIncrementChanged(seekForwardIncrementMs: Long) {}
    override fun onMaxSeekToPreviousPositionChanged(maxSeekToPreviousPositionMs: Long) {}
    override fun onSeekProcessed() {}
    override fun onAudioSessionIdChanged(audioSessionId: Int) {}
    override fun onAudioAttributesChanged(audioAttributes: AudioAttributes) {}
    override fun onVolumeChanged(volume: Float) {}
    override fun onSkipSilenceEnabledChanged(skipSilenceEnabled: Boolean) {}
    override fun onDeviceInfoChanged(deviceInfo: DeviceInfo) {}
    override fun onDeviceVolumeChanged(volume: Int, muted: Boolean) {}
    override fun onVideoSizeChanged(videoSize: VideoSize) {}
    override fun onSurfaceSizeChanged(width: Int, height: Int) {}
    override fun onRenderedFirstFrame() {}
    override fun onCues(cues: MutableList<Cue>) {}
    override fun onCues(cueGroup: CueGroup) {}
}