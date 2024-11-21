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
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import io.dcloud.uniapp.util.LogUtils
//import io.dcloud.uniappx.R

import uts.sdk.modules.uniGetBackgroundAudioManager.R //todo 替换

class AudioService : Service() {

    private lateinit var playerHelper: BackgroundAudioPlayer
    private var tag: String = "AudioService"
    private lateinit var broadcastReceiver: BroadcastReceiver
    private var mediaSession: MediaSessionCompat? = null

    override fun onCreate() {
        super.onCreate()
        val channelId = "music_channel"
        mediaSession = MediaSessionCompat(this, "PlayerSession")
        createNotificationChannel(channelId)
        playerHelper = BackgroundAudioPlayer.getInstance()
        register()

    }

    private fun register() {
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                Log.d("register action", intent.action + "")
                when (intent.action) {
                    ACTION_PLAY_PAUSE -> {
                        // 处理播放/暂停操作
                        if (playerHelper.isPausedByUser) {
                            LogUtils.d(tag, "play")
                            playerHelper.play()
                        } else {
                            LogUtils.d(tag, "pause")
                            playerHelper.pause()
                        }
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
        LogUtils.d(tag, "onStartCommand")
        // 显示通知
        showNotification(CHANNEL_ID)
        playerHelper.playInService()
        return START_STICKY
    }

    private fun showNotification(channelId: String) {
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(playerHelper.title)
            .setContentText(playerHelper.epname + ' ' + playerHelper.singer)
            .setSmallIcon(R.drawable.uni_app_x_logo) // 设置通知图标
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.drawable.uni_app_x_logo)) // 设置封面图
            .setOngoing(true) // 设置为正在进行的通知
            .setPriority(NotificationCompat.PRIORITY_LOW)
        notificationBuilder.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        //创建点击通知的意图
        var intent: Intent = Intent();
        intent.setClassName(this, "uts.sdk.modules.uniGetBackgroundAudioManager.AudioTempActivity");

        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK);
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.setContentIntent(contentIntent)


        // 创建上一曲按钮的意图
        val prevIntent = PendingIntent.getBroadcast(
            this,
            2,
            Intent(ACTION_PREV),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.addAction(
            R.drawable.uni_app_x_exo_icon_previous,
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
            if (playerHelper.player.isPlaying) R.drawable.uni_app_x_exo_icon_pause else R.drawable.uni_app_x_exo_icon_play,
            "播放/暂停",
            playPauseIntent
        )

        // 创建下一曲按钮的意图
        val nextIntent = PendingIntent.getBroadcast(
            this,
            3,
            Intent(ACTION_NEXT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder.addAction(
            R.drawable.uni_app_x_exo_icon_next,
            "下一曲",
            nextIntent
        )
        val style = androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(mediaSession?.sessionToken)
            .setShowActionsInCompactView(0, 1, 2)
        notificationBuilder.setStyle(style)
        mediaSession?.isActive = true
        // 显示通知
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())

//        startForeground(NOTIFICATION_ID, notificationBuilder.build())

    }

    private fun createNotificationChannel(channelId: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Music Playback",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(broadcastReceiver)
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "ACTION_PLAY_PAUSE"
        const val ACTION_PREV = "ACTION_PREV"
        const val ACTION_NEXT = "ACTION_NEXT"
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "music_channel"
    }
}


