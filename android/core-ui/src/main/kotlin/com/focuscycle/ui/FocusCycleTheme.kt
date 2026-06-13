package com.focuscycle.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object FocusCycleColors {
    val FocusBlue = Color(0xFF42A5F5)
    val PlayGreen = Color(0xFF4CAF50)
    val PauseOrange = Color(0xFFFF9800)
    val StopRed = Color(0xFFE53935)
    val FocusPurple = Color(0xFF8E68FF)
}

@Composable
fun FocusCycleTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) {
        darkColorScheme(
            primary = FocusCycleColors.FocusBlue,
            secondary = FocusCycleColors.PlayGreen,
            tertiary = FocusCycleColors.FocusPurple,
            error = FocusCycleColors.StopRed
        )
    } else {
        lightColorScheme(
            primary = FocusCycleColors.FocusBlue,
            secondary = FocusCycleColors.PlayGreen,
            tertiary = FocusCycleColors.FocusPurple,
            error = FocusCycleColors.StopRed
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}
