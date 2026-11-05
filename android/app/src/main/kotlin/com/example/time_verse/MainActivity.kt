package com.infiniquote.app

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.KeyEvent
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.infiniquote.app/ringtone"
    private val RINGTONE_PICKER_REQUEST_CODE = 9401

    private var methodChannel: MethodChannel? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null
    private var mediaPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var previewStopRunnable: Runnable? = null

    @Volatile
    private var isAlarmRinging: Boolean = false
    private var savedAlarmStreamVolume: Int = -1
    private var isVolumeReceiverRegistered: Boolean = false

    private val volumeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isAlarmRinging) return
            if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                val newVol = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1)
                val oldVol = intent.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1)

                if (newVol != oldVol && (streamType == AudioManager.STREAM_ALARM ||
                            streamType == AudioManager.STREAM_MUSIC ||
                            streamType == AudioManager.STREAM_RING)
                ) {
                    // Restore alarm stream volume if the OS changed it before snooze
                    if (streamType == AudioManager.STREAM_ALARM && savedAlarmStreamVolume > 0) {
                        try {
                            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmStreamVolume, 0)
                        } catch (_: Exception) {}
                    }
                    onHardwareSnoozeTriggered()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenFlags()
    }

    private fun configureLockScreenFlags() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDefaultRingtoneUri" -> {
                    try {
                        val alarmUri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                        result.success(alarmUri?.toString() ?: "")
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Failed to get ringtone: ${e.message}", null)
                    }
                }
                "getRingtoneTitle" -> {
                    val uriString = call.argument<String>("uri")
                    result.success(resolveRingtoneTitle(uriString))
                }
                "pickAlarmRingtone" -> {
                    if (pendingRingtoneResult != null) {
                        result.error("BUSY", "Ringtone picker already active", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val currentUriStr = call.argument<String>("currentUri")
                        val currentUri = if (!currentUriStr.isNullOrEmpty() && currentUriStr.startsWith("content://")) {
                            Uri.parse(currentUriStr)
                        } else {
                            RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
                        }

                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Sound")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                        }
                        pendingRingtoneResult = result
                        startActivityForResult(intent, RINGTONE_PICKER_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingRingtoneResult = null
                        result.error("PICKER_ERROR", "Could not open ringtone picker: ${e.message}", null)
                    }
                }
                "playRingtone" -> {
                    val uriString = call.argument<String>("uri")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    val loop = call.argument<Boolean>("loop") ?: true
                    try {
                        startNativePlayer(uriString, volume, loop, isPreview = false)
                        setRingingStateInternal(true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", "Could not play audio track: ${e.message}", null)
                    }
                }
                "previewRingtone" -> {
                    val uriString = call.argument<String>("uri")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.8f
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 3000L
                    try {
                        startNativePlayer(uriString, volume, loop = false, isPreview = true)
                        previewStopRunnable?.let { mainHandler.removeCallbacks(it) }
                        val stopTask = Runnable { stopNativePlayer() }
                        previewStopRunnable = stopTask
                        mainHandler.postDelayed(stopTask, durationMs)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PREVIEW_ERROR", "Could not preview audio: ${e.message}", null)
                    }
                }
                "stopRingtone" -> {
                    setRingingStateInternal(false)
                    stopNativePlayer()
                    cancelNativeVibration()
                    result.success(true)
                }
                "cancelVibration" -> {
                    cancelNativeVibration()
                    result.success(true)
                }
                "triggerVibration" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
                    triggerShortVibration(durationMs)
                    result.success(true)
                }
                "setAlarmRingingState" -> {
                    val ringing = call.argument<Boolean>("isRinging") ?: false
                    setRingingStateInternal(ringing)
                    if (!ringing) {
                        stopNativePlayer()
                        cancelNativeVibration()
                    }
                    result.success(true)
                }
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(nm.canUseFullScreenIntent())
                    } else {
                        result.success(true)
                    }
                }
                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICKER_REQUEST_CODE) {
            val callback = pendingRingtoneResult
            pendingRingtoneResult = null
            if (callback == null) return

            if (resultCode == Activity.RESULT_OK && data != null) {
                val pickedUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                }
                val uriStr = pickedUri?.toString() ?: ""
                val title = resolveRingtoneTitle(uriStr)
                val localPath = if (pickedUri != null) copyUriToLocalAlarmFile(pickedUri) else ""
                callback.success(
                    mapOf(
                        "uri" to uriStr,
                        "title" to title,
                        "localPath" to (localPath ?: "")
                    )
                )
            } else {
                callback.success(null)
            }
        }
    }

    private fun resolveRingtoneTitle(uriString: String?): String {
        if (uriString.isNullOrEmpty() || !uriString.startsWith("content://")) {
            return "Default Chime"
        }
        return try {
            val ringtone = RingtoneManager.getRingtone(context, Uri.parse(uriString))
            ringtone?.getTitle(context) ?: "System Alarm"
        } catch (_: Exception) {
            "System Alarm"
        }
    }

    private fun copyUriToLocalAlarmFile(uri: Uri): String? {
        return try {
            val outFile = File(context.filesDir, "custom_alarm_ringtone.mp3")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile, false).use { output ->
                    input.copyTo(output)
                    output.flush()
                }
            }
            if (outFile.exists() && outFile.length() > 0) outFile.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun setRingingStateInternal(ringing: Boolean) {
        isAlarmRinging = ringing
        mainHandler.post {
            try {
                if (ringing) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        if (km.isKeyguardLocked) {
                            setShowWhenLocked(true)
                            setTurnScreenOn(true)
                        }
                    }
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    savedAlarmStreamVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                    registerVolumeReceiverIfNeeded()
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    unregisterVolumeReceiverIfNeeded()
                }
            } catch (_: Exception) {}
        }
    }

    private fun registerVolumeReceiverIfNeeded() {
        if (isVolumeReceiverRegistered) return
        try {
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(volumeChangeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(volumeChangeReceiver, filter)
            }
            isVolumeReceiverRegistered = true
        } catch (_: Exception) {}
    }

    private fun unregisterVolumeReceiverIfNeeded() {
        if (!isVolumeReceiverRegistered) return
        try {
            unregisterReceiver(volumeChangeReceiver)
        } catch (_: Exception) {}
        isVolumeReceiverRegistered = false
    }

    private fun startNativePlayer(uriString: String?, volume: Float, loop: Boolean, isPreview: Boolean) {
        stopNativePlayer()

        val clampedVolume = volume.coerceIn(0.05f, 1.0f)
        requestAlarmAudioFocus()

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )

            var loaded = false
            if (!uriString.isNullOrEmpty() && uriString.startsWith("content://")) {
                try {
                    setDataSource(context, Uri.parse(uriString))
                    loaded = true
                } catch (_: Exception) {
                    loaded = false
                }
            }
            if (!loaded) {
                loadFallbackAsset(this)
            }

            isLooping = loop
            setVolume(clampedVolume, clampedVolume)
            if (isPreview) {
                setOnCompletionListener { stopNativePlayer() }
            }
            prepare()
            start()
        }
    }

    private fun requestAlarmAudioFocus() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .build()
                audioFocusRequest = req
                am.requestAudioFocus(req)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            }
        } catch (_: Exception) {}
    }

    private fun abandonAlarmAudioFocus() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}
    }

    private fun loadFallbackAsset(player: MediaPlayer) {
        try {
            val assetDescriptor = context.assets.openFd("flutter_assets/assets/alarm.mp3")
            player.setDataSource(assetDescriptor.fileDescriptor, assetDescriptor.startOffset, assetDescriptor.length)
            assetDescriptor.close()
        } catch (e: FileNotFoundException) {
            val alertUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            player.setDataSource(context, alertUri)
        }
    }

    private fun getSystemVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun cancelNativeVibration() {
        try {
            getSystemVibrator()?.cancel()
        } catch (_: Exception) {}
    }

    private fun triggerShortVibration(durationMs: Long) {
        try {
            val vibrator = getSystemVibrator() ?: return
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (_: Exception) {}
    }

    private fun onHardwareSnoozeTriggered() {
        if (!isAlarmRinging) return
        setRingingStateInternal(false)
        stopNativePlayer()
        cancelNativeVibration()
        mainHandler.post {
            methodChannel?.invokeMethod("onVolumeButtonPressed", null)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        if (isAlarmRinging && (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
                    keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                    keyCode == KeyEvent.KEYCODE_VOLUME_MUTE)
        ) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                onHardwareSnoozeTriggered()
            }
            // Consume both ACTION_DOWN and ACTION_UP so Android never mutes the stream while leaving vibration active
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun stopNativePlayer() {
        previewStopRunnable?.let { mainHandler.removeCallbacks(it) }
        previewStopRunnable = null
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            }
        } catch (_: Exception) {
        } finally {
            mediaPlayer = null
            abandonAlarmAudioFocus()
        }
    }

    override fun onDestroy() {
        setRingingStateInternal(false)
        stopNativePlayer()
        cancelNativeVibration()
        methodChannel = null
        super.onDestroy()
    }
}

