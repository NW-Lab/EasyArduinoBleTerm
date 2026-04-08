package com.nwlab.easyarduinobleterm.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nwlab.easyarduinobleterm.model.PlotChannel
import com.nwlab.easyarduinobleterm.viewmodel.PlotterViewModel
import kotlin.math.*

@Composable
fun PlotterScreen(vm: PlotterViewModel) {
    val channels      by vm.channels.collectAsState()
    val timeWindow    by vm.timeWindowSec.collectAsState()
    val yAutoMode     by vm.yAutoMode.collectAsState()
    val yMin          by vm.yMin.collectAsState()
    val yMax          by vm.yMax.collectAsState()
    val isInteracting by vm.isInteracting.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1A1A1A))
    ) {
        // --- ツールバー ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // 時間プリセット
            listOf(0.1 to "0.1s", 1.0 to "1s", 10.0 to "10s").forEach { (sec, label) ->
                val selected = abs(timeWindow - sec) < sec * 0.1
                FilterChip(
                    selected = selected,
                    onClick  = { vm.setTimePreset(sec) },
                    label    = { Text(label, fontSize = 12.sp) }
                )
            }
            Spacer(Modifier.weight(1f))
            // 縦軸トグル
            FilterChip(
                selected = !yAutoMode,
                onClick  = { vm.toggleYAxisMode() },
                label    = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        if (!yAutoMode) Icon(Icons.Default.Lock, contentDescription = null, modifier = Modifier.size(14.dp))
                        Text(if (yAutoMode) "自動" else "固定", fontSize = 12.sp)
                    }
                }
            )
            // クリア
            IconButton(onClick = { vm.clearData() }) {
                Icon(Icons.Default.Delete, contentDescription = "クリア", tint = Color(0xFFEF5350))
            }
        }

        // --- チャンネル選択 ---
        if (channels.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                channels.forEach { ch ->
                    Box(
                        modifier = Modifier
                            .border(
                                width = 2.dp,
                                color = if (ch.visible) ch.color else Color(0xFF555555),
                                shape = RoundedCornerShape(16.dp)
                            )
                            .clickable { vm.toggleChannel(ch.index) }
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .background(
                                        color = if (ch.visible) ch.color else Color(0xFF555555),
                                        shape = RoundedCornerShape(4.dp)
                                    )
                            )
                            Text(
                                text  = ch.label,
                                color = if (ch.visible) ch.color else Color(0xFF555555),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
        }

        // --- グラフエリア ---
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
        ) {
            PlotCanvas(
                channels      = channels,
                timeWindowSec = timeWindow,
                yMin          = yMin,
                yMax          = yMax,
                modifier      = Modifier.fillMaxSize(),
                onScaleX      = { factor -> vm.scaleTimeWindow(factor) },
                onScaleY      = { factor -> vm.scaleYAxis(factor) },
                onShiftY      = { delta  -> vm.shiftYAxis(delta) },
                onInteracting = { v      -> vm.setInteracting(v) }
            )

            // ピンチ中インジケーター
            if (isInteracting) {
                Text(
                    text     = "操作中",
                    color    = Color(0xFFFFCA28),
                    fontSize = 12.sp,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp)
                        .background(Color(0x88000000), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }

            // 時間幅表示
            if (channels.isNotEmpty()) {
                val gridLabel = when {
                    timeWindow <= 0.15 -> "0.1 s"
                    timeWindow <= 1.5  -> "1 s"
                    else               -> "10 s"
                }
                Text(
                    text     = "表示幅: ${"%.3f".format(timeWindow)} s / 目盛: $gridLabel",
                    color    = Color(0xFF888888),
                    fontSize = 11.sp,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(8.dp)
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// Canvas + Gesture
// ─────────────────────────────────────────────

@Composable
private fun PlotCanvas(
    channels: List<PlotChannel>,
    timeWindowSec: Double,
    yMin: Float,
    yMax: Float,
    modifier: Modifier,
    onScaleX: (Double) -> Unit,
    onScaleY: (Float) -> Unit,
    onShiftY: (Float) -> Unit,
    onInteracting: (Boolean) -> Unit
) {
    // ジェスチャー状態
    var prevHDist by remember { mutableStateOf(0f) }
    var prevVDist by remember { mutableStateOf(0f) }
    var prevMidY  by remember { mutableStateOf(0f) }
    var gestureMode by remember { mutableStateOf(GestureMode.NONE) }

    val gestureModifier = modifier.pointerInput(Unit) {
        awaitEachGesture {
            // 最初の1本目の指を待つ
            awaitFirstDown(requireUnconsumed = false)

            // 2本目の指を待つ
            var event = awaitPointerEvent()
            while (event.changes.count { it.pressed } < 2) {
                if (event.changes.all { !it.pressed }) return@awaitEachGesture
                event = awaitPointerEvent()
            }

            // 2本指ジェスチャー開始
            onInteracting(true)
            gestureMode = GestureMode.NONE

            val p0 = event.changes[0].position
            val p1 = event.changes[1].position
            prevHDist = abs(p0.x - p1.x)
            prevVDist = abs(p0.y - p1.y)
            prevMidY  = (p0.y + p1.y) / 2f

            // ジェスチャー継続
            while (true) {
                event = awaitPointerEvent()
                val pressed = event.changes.filter { it.pressed }
                if (pressed.size < 2) break

                val c0 = pressed[0].position
                val c1 = pressed[1].position
                val hDist = abs(c0.x - c1.x)
                val vDist = abs(c0.y - c1.y)
                val midY  = (c0.y + c1.y) / 2f

                // モード判定（最初の動きで決定）
                if (gestureMode == GestureMode.NONE) {
                    val dH = abs(hDist - prevHDist)
                    val dV = abs(vDist - prevVDist)
                    val dPan = abs(midY - prevMidY)
                    gestureMode = when {
                        dPan > dH && dPan > dV -> GestureMode.PAN_Y
                        dH > dV                -> GestureMode.SCALE_X
                        else                   -> GestureMode.SCALE_Y
                    }
                }

                when (gestureMode) {
                    GestureMode.SCALE_X -> {
                        if (prevHDist > 1f && hDist > 1f) {
                            val factor = prevHDist / hDist
                            onScaleX(factor.toDouble())
                        }
                    }
                    GestureMode.SCALE_Y -> {
                        if (prevVDist > 1f && vDist > 1f) {
                            val factor = vDist / prevVDist
                            onScaleY(factor)
                        }
                    }
                    GestureMode.PAN_Y -> {
                        val dy = midY - prevMidY
                        val yRange = (yMax - yMin).coerceAtLeast(0.001f)
                        // ピクセル → 値変換（高さは概算500px）
                        val delta = dy / 500f * yRange
                        onShiftY(delta)
                    }
                    GestureMode.NONE -> {}
                }

                prevHDist = hDist
                prevVDist = vDist
                prevMidY  = midY

                event.changes.forEach { it.consume() }
            }

            onInteracting(false)
            gestureMode = GestureMode.NONE
        }
    }

    Canvas(modifier = gestureModifier) {
        val w = size.width
        val h = size.height
        val leftPad  = 56f
        val rightPad = 8f
        val topPad   = 8f
        val botPad   = 24f
        val plotW = w - leftPad - rightPad
        val plotH = h - topPad - botPad

        // 背景
        drawRect(color = Color(0xFF1A1A1A))

        if (channels.isEmpty() || plotW <= 0 || plotH <= 0) return@Canvas

        val latestTime = channels.flatMap { it.points }.maxOfOrNull { it.timeSeconds } ?: 0.0
        val tEnd   = latestTime
        val tStart = tEnd - timeWindowSec
        val yRange = (yMax - yMin).coerceAtLeast(0.001f)

        fun toX(t: Double) = (leftPad + ((t - tStart) / timeWindowSec * plotW).toFloat()).coerceIn(leftPad, leftPad + plotW)
        fun toY(v: Float)  = (topPad + (1f - (v - yMin) / yRange) * plotH).coerceIn(topPad, topPad + plotH)

        // グリッド（横軸）
        val gridStep = when {
            timeWindowSec <= 0.15 -> 0.1
            timeWindowSec <= 1.5  -> 1.0
            else                  -> 10.0
        }
        var t = floor(tStart / gridStep) * gridStep
        while (t <= tEnd + gridStep) {
            val x = toX(t)
            if (x in leftPad..(leftPad + plotW)) {
                drawLine(
                    color       = Color(0xFF333333),
                    start       = Offset(x, topPad),
                    end         = Offset(x, topPad + plotH),
                    strokeWidth = 1f
                )
            }
            t += gridStep
        }

        // グリッド（縦軸）
        val yStepCount = 5
        val yStep = yRange / yStepCount
        for (i in 0..yStepCount) {
            val v = yMin + yStep * i
            val y = toY(v)
            drawLine(
                color       = Color(0xFF333333),
                start       = Offset(leftPad, y),
                end         = Offset(leftPad + plotW, y),
                strokeWidth = 1f
            )
            // Y軸ラベル
            drawContext.canvas.nativeCanvas.drawText(
                formatYLabel(v),
                leftPad - 4f,
                y + 4f,
                android.graphics.Paint().apply {
                    color     = android.graphics.Color.argb(180, 180, 180, 180)
                    textSize  = 22f
                    textAlign = android.graphics.Paint.Align.RIGHT
                    isAntiAlias = true
                }
            )
        }

        // ゼロライン
        if (yMin < 0 && yMax > 0) {
            val y0 = toY(0f)
            drawLine(
                color       = Color(0xFF555555),
                start       = Offset(leftPad, y0),
                end         = Offset(leftPad + plotW, y0),
                strokeWidth = 1.5f
            )
        }

        // チャンネル描画
        channels.filter { it.visible }.forEach { ch ->
            val pts = ch.points.filter { it.timeSeconds >= tStart - 0.1 }
            if (pts.size < 2) return@forEach
            val path = Path()
            pts.forEachIndexed { i, pt ->
                val x = toX(pt.timeSeconds)
                val y = toY(pt.value)
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path = path, color = ch.color, style = Stroke(width = 2f))
        }

        // 枠線
        drawRect(
            color       = Color(0xFF444444),
            topLeft     = Offset(leftPad, topPad),
            size        = androidx.compose.ui.geometry.Size(plotW, plotH),
            style       = Stroke(width = 1f)
        )
    }
}

private fun formatYLabel(v: Float): String {
    return when {
        abs(v) >= 1000 -> "%.0f".format(v)
        abs(v) >= 10   -> "%.1f".format(v)
        abs(v) >= 1    -> "%.2f".format(v)
        else           -> "%.3f".format(v)
    }
}

private enum class GestureMode { NONE, SCALE_X, SCALE_Y, PAN_Y }
