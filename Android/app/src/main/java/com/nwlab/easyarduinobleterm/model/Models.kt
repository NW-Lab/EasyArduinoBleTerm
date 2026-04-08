package com.nwlab.easyarduinobleterm.model

import androidx.compose.ui.graphics.Color
import java.time.LocalDateTime

data class TerminalMessage(
    val text: String,
    val timestamp: LocalDateTime = LocalDateTime.now()
)

data class PlotPoint(
    val timeSeconds: Double,
    val value: Float
)

data class PlotChannel(
    val index: Int,
    val label: String,
    val color: Color,
    val visible: Boolean = true,
    val points: List<PlotPoint> = emptyList()
)

val CHANNEL_COLORS = listOf(
    Color(0xFF4FC3F7), // 水色
    Color(0xFFEF5350), // 赤
    Color(0xFF66BB6A), // 緑
    Color(0xFFFFCA28), // 黄
    Color(0xFFAB47BC)  // 紫
)
