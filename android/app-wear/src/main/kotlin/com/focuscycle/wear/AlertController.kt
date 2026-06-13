package com.focuscycle.wear

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

enum class WearAlertPattern {
    Light,
    Medium,
    Heavy,
    Success,
    Warning,
    Error,
    Selection,
    Notification
}

class AlertController(context: Context) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    fun play(pattern: WearAlertPattern = WearAlertPattern.Notification) {
        val timings = when (pattern) {
            WearAlertPattern.Light -> longArrayOf(0, 35)
            WearAlertPattern.Medium -> longArrayOf(0, 70)
            WearAlertPattern.Heavy -> longArrayOf(0, 120)
            WearAlertPattern.Success -> longArrayOf(0, 45, 70, 90)
            WearAlertPattern.Warning -> longArrayOf(0, 90, 90, 90)
            WearAlertPattern.Error -> longArrayOf(0, 140, 80, 140)
            WearAlertPattern.Selection -> longArrayOf(0, 25)
            WearAlertPattern.Notification -> longArrayOf(0, 70, 80, 70)
        }
        val effect = VibrationEffect.createWaveform(timings, -1)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .build()
        vibrator?.vibrate(effect, attrs)
    }
}
