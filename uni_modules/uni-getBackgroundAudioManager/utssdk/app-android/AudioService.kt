package uts.sdk.modules.uniGetBackgroundAudioManager;


import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.os.RemoteException
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import io.dcloud.uniapp.extapi.DownloadFileOptions
import io.dcloud.uniapp.extapi.DownloadFileSuccess
import io.dcloud.uniapp.extapi.downloadFile
import uts.sdk.modules.uniGetBackgroundAudioManager.R

class AudioService : Service() {

    private lateinit var playerHelper: BackgroundAudioPlayer
    private var tag: String = "AudioService"
    private lateinit var broadcastReceiver: BroadcastReceiver
    private var mMediaSession: MediaSessionCompat? = null
    private var mNotificationManager: NotificationManager? = null
    private var mNotificationBuilder: NotificationCompat.Builder? = null
    private var lastAudioUrl: String? = null//存放最近一次播放地址

    //指定可以接收的来自锁屏页面的按键信息
    private val mediaSessionActions = (PlaybackStateCompat.ACTION_PLAY
            or PlaybackStateCompat.ACTION_PAUSE
            or PlaybackStateCompat.ACTION_PLAY_PAUSE
            or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            or PlaybackStateCompat.ACTION_STOP
            or PlaybackStateCompat.ACTION_SEEK_TO)

    override fun onCreate() {
        super.onCreate()
        Log.d(tag, "onCreate")
        audioService = this
        mNotificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        playerHelper = BackgroundAudioPlayer.getInstance()
        initNotification()
        register()
    }

    fun canPlay() {
        Log.d(tag, "registerCanPlay")
        notifyChange()
        updateMetaData()
        updateNotification()
    }

    fun onEnd() {
        cancelNotification()//仿照小程序，播放完了自动清除通知
    }

    fun pause() {
        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
    }

    private fun register() {
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                Log.d("register action", intent.action + "")
                when (intent.action) {
                    ACTION_PLAY_PAUSE -> {
                        // 处理播放/暂停操作
                        if (playerHelper.isPausedByUser) {
                            Log.d(tag, "play")
                            playerHelper.play()
                        } else {
                            Log.d(tag, "pause")
                            playerHelper.pause()
                        }
                        updateNotification()
                    }

                    ACTION_PREV -> {
                        // 处理上一首操作
                        playerHelper.invokeCallBack("prev")
                    }

                    ACTION_NEXT -> {
                        // 处理下一首操作
                        playerHelper.invokeCallBack("next")
                    }
                }
            }
        }

// 注册广播
        val intentFilter = IntentFilter().apply {
            addAction(ACTION_PLAY_PAUSE)
            addAction(ACTION_PREV)
            addAction(ACTION_NEXT)
        }
        registerReceiver(broadcastReceiver, intentFilter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(tag, "onStartCommand $lastAudioUrl")
        if (playerHelper.player.isPlaying) {// 处理在播放中在点击播放的场景
            Log.d(tag, "onStartCommand isplaying")
        } else {
            playCurrent()
        }
        return START_STICKY
    }

    private fun playCurrent() {
        playerHelper.playInService()
    }

    /**
     * 取消通知
     */
    private fun cancelNotification() {
        stopForeground(true)
        mNotificationManager!!.cancel(NOTIFICATION_ID)
        mMediaSession!!.setCallback(null)
        mMediaSession!!.setActive(false)
        mMediaSession!!.release()
        stopSelf()
    }

    /**
     * 更新正在播放的音乐信息，切换歌曲时调用
     */
    private fun updateMetaData() {
        if (lastAudioUrl != playerHelper.coverImgUrl) {
            lastAudioUrl = playerHelper.coverImgUrl

            var duration = playerHelper.player.duration
            val metaDta = MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, playerHelper.title)//标题
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, playerHelper.singer)//艺术家名称
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, playerHelper.epname)//专辑名称
                .putLong(
                    MediaMetadataCompat.METADATA_KEY_DURATION,
                    duration
                )//媒体总时长 单位ms
            playerHelper.coverImgUrl?.let {
                if (it.startsWith("http") || it.startsWith("https")) {
                    downloadFile(
                        DownloadFileOptions(
                            url = it,
                            success = fun(res: DownloadFileSuccess) {
                                Log.d(tag, "DownloadFileSuccess=" + res.tempFilePath)
                                metaDta.putBitmap(
                                    MediaMetadataCompat.METADATA_KEY_ALBUM_ART,
                                    BitmapFactory.decodeFile(res.tempFilePath)
                                )//封面图 URL
                                mMediaSession!!.setMetadata(metaDta.build())
                                updateNotification()
                            },
                            fail = fun(_) {
                            }
                        ));
                }
            }
            mMediaSession!!.setMetadata(metaDta.build())
        }
    }

    /**
     * 发送更新广播
     */
    public fun notifyChange() {
        val state =
            if (playerHelper.player.isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        updatePlaybackState(state)
    }

    private fun initChannelId(): String {
        // 通知渠道的id
        val id = "uni_app_uni_getBackgroundAudioManager_music_channel"
        // 用户可以看到的通知渠道的名字.
        val name: String = this.getString(R.string.uni_app_uni_getBackgroundAudioManager_notification_name)
        // 用户可以看到的通知渠道的描述
        val description = name
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val mChannel = NotificationChannel(id, name, importance)
            mChannel.description = description
            mNotificationManager!!.createNotificationChannel(mChannel)
        }
        return id
    }

    private fun updateNotification() {
        updateAction(mNotificationBuilder!!)
        mNotificationManager!!.notify(NOTIFICATION_ID, mNotificationBuilder!!.build())
    }

    private fun initNotification() {

        Log.d(tag, "initNotification")
        mNotificationBuilder = NotificationCompat.Builder(this, initChannelId())
            .setContentTitle(playerHelper.title)
            .setContentText(playerHelper.singer)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)//设置显示范围
            .setPriority(NotificationCompat.PRIORITY_LOW)//设置优先级
        var idSmall = resources.getIdentifier("icon", "drawable", packageName)
        if (idSmall <= 0) {
            mNotificationBuilder?.setSmallIcon(applicationInfo.icon); //设置图标
        } else {
            mNotificationBuilder?.setSmallIcon(idSmall); //设置图标
        }
        playerHelper.coverImgUrl?.let {
            if (it.startsWith("http") || it.startsWith("https")) {
                downloadFile(
                    DownloadFileOptions(
                        url = it,
                        success = fun(res: DownloadFileSuccess) {
                            mNotificationBuilder?.setLargeIcon(BitmapFactory.decodeFile(res.tempFilePath))
                            updateNotification()
                        },
                        fail = fun(_) {
                        }
                    ));
            }
        }
        Log.d(tag, "idSmall=$idSmall")
        //创建点击通知的意图
        setContent(mNotificationBuilder!!)
        updateAction(mNotificationBuilder!!)
        setMediaStyle(mNotificationBuilder!!)
        var notification = mNotificationBuilder!!.build()
        mNotificationManager!!.notify(NOTIFICATION_ID, notification)
        startForeground(NOTIFICATION_ID, notification)
        Log.d(tag, "initNotification end")

    }

    private fun setContent(notificationBuilder: NotificationCompat.Builder) {
        var intent = Intent();
        intent.setClassName(
            this,
            "uts.sdk.modules.DCloudUniGetBackgroundAudioManager.AudioTempActivity"
        );

        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK);
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.setContentIntent(contentIntent)
    }

    private fun updateAction(notificationBuilder: NotificationCompat.Builder) {
        mNotificationBuilder?.mActions?.clear()

        // 创建上一曲按钮的意图
        val prevIntent = PendingIntent.getBroadcast(
            this,
            2,
            Intent(ACTION_PREV),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.addAction(
            R.drawable.uni_app_x_bgaudio_icon_previous,
            "上一曲",
            prevIntent
        )

        // 创建播放/暂停按钮的意图
        val playPauseIntent = PendingIntent.getBroadcast(
            this,
            1,
            Intent(ACTION_PLAY_PAUSE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.addAction(
            if (playerHelper.player.isPlaying) R.drawable.uni_app_x_bgaudio_icon_pause else R.drawable.uni_app_x_bgaudio_icon_play,
            "播放/暂停",
            playPauseIntent
        )

        // 创建下一曲按钮的意图
        var nextIntent = PendingIntent.getBroadcast(
            this,
            3,
            Intent(ACTION_NEXT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.addAction(
            R.drawable.uni_app_x_bgaudio_icon_next,
            "下一曲",
            nextIntent
        )
    }

//    private fun getBitmap(path: String): Bitmap? {
//        var filePath = UTSAndroid.convert2AbsFullPath(path)
//        if (path.startsWith("/android_asset/")) {
//            var assetName = path.substring("/android_asset/".length)
//            var stream = assets.open(assetName)
//            val bitmap = BitmapFactory.decodeStream(assets.open(assetName))
//            stream.close()
//            return bitmap
//        } else if (path.startsWith("content://")) {
//            val contentUri: Uri = Uri.parse(path)
//            val inputStream = contentResolver.openInputStream(contentUri)
//            val bitmap = BitmapFactory.decodeStream(inputStream)
//            inputStream?.close()
//            return bitmap
//        } else {
//            var imageFile = File(filePath)
//            if (imageFile.exists()) {
//                return BitmapFactory.decodeFile(imageFile.absolutePath)
//            }
//        }
//        return null
//    }

    private fun setMediaStyle(notificationBuilder: NotificationCompat.Builder) {
        if (mMediaSession == null) {
            setupMediaSession()
            val style = androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mMediaSession?.sessionToken)
                .setShowActionsInCompactView(0, 1, 2)//简图显示的按钮
            notificationBuilder.setStyle(style)
            mMediaSession?.isActive = true
        }
    }

    /**
     * 初始化并激活 MediaSession
     */
    private fun setupMediaSession() {
        mMediaSession =
            MediaSessionCompat(this, "PlayerSession")
        mMediaSession!!.setCallback(callback)
        mMediaSession!!.setActive(true)
    }

    /**
     * 更新播放状态， 播放／暂停／拖动进度条时调用
     */
    private fun updatePlaybackState(state: Int) {

        var currentPosition = playerHelper.player.currentPosition
        mMediaSession!!.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(mediaSessionActions)
                .setState(
                    state,
                    currentPosition,
                    playerHelper._playbackRate.toFloat()
                )
                .build()
        )
        Log.d(
            tag,
            "updatePlaybackState> state=" + state + ";currentPosition=" + currentPosition + ";_playbackRate=" + playerHelper._playbackRate.toFloat()
        )
    }

    private val callback: MediaSessionCompat.Callback = object : MediaSessionCompat.Callback() {
        //进度条拖拽
        override fun onSeekTo(pos: Long) {
            try {
                updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
                playerHelper.seek(pos / 1000)
                updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                Log.d(
                    tag,
                    "onSeekTo = " + pos.toInt()
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }

        // 接收到监听事件，可以有选择的进行重写相关方法
        override fun onMediaButtonEvent(mediaButtonEvent: Intent): Boolean {
            Log.d(
                tag,
                "mediaButtonEvent$mediaButtonEvent"
            )
            return super.onMediaButtonEvent(mediaButtonEvent)
        }

        override fun onPlay() {
            try {
                playerHelper.play()
                updateNotification()
                Log.d(
                    tag,
                    "onPlay"
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }

        override fun onPause() {
            try {
                playerHelper.pause()
                updateNotification()
                Log.d(
                    tag,
                    "onPause"
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }

        override fun onSkipToNext() {
            try {
                playerHelper.invokeCallBack("next")
                Log.d(
                    tag,
                    "onSkipToNext"
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }

        override fun onSkipToPrevious() {
            try {
                playerHelper.invokeCallBack("prev")
                Log.d(
                    tag,
                    "onSkipToPrevious"
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }

        override fun onStop() {
            try {
                Log.d(
                    tag,
                    "onStop"
                )
            } catch (e: RemoteException) {
                e.printStackTrace()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        Log.d(tag, "onDestroy")
        super.onDestroy()
        unregisterReceiver(broadcastReceiver)
        audioService = null
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "ACTION_PLAY_PAUSE"
        const val ACTION_PREV = "ACTION_PREV"
        const val ACTION_NEXT = "ACTION_NEXT"

        const val NOTIFICATION_ID = 0x124
        var audioService: AudioService? = null
    }
}

