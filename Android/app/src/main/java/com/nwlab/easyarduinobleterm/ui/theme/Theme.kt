package com.nwlab.easyarduinobleterm.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary         = Color(0xFF4FC3F7),
    secondary       = Color(0xFF66BB6A),
    background      = Color(0xFF121212),
    surface         = Color(0xFF1E1E1E),
    surfaceVariant  = Color(0xFF2A2A2A),
    onPrimary       = Color.Black,
    onBackground    = Color.White,
    onSurface       = Color.White,
)

@Composable
fun EasyArduinoBleTermTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content     = content
    )
}
