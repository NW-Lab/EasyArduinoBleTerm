package com.nwlab.easyarduinobleterm.viewmodel

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nwlab.easyarduinobleterm.model.CHANNEL_COLORS
import com.nwlab.easyarduinobleterm.model.PlotChannel
import com.nwlab.easyarduinobleterm.model.PlotPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

private const val TAG = "PlotterViewModel"

class PlotterViewModel(private val scope: CoroutineScope) {

    companion object {
        private const val MAX_POINTS     = 5000
        private const val FRAME_INTERVAL = 33L   // ~30fps
    }

    // --- UI に公開する StateFlow ---
    private val _channels = MutableStateFlow<List<PlotChannel>>(emptyList())
    val channels: StateFlow<List<PlotChannel>> = _channels.asStateFlow()

    private val _timeWindowSec = MutableStateFlow(5.0)
    val timeWindowSec: StateFlow<Double> = _timeWindowSec.asStateFlow()

    private val _yAutoMode = MutableStateFlow(true)
    val yAutoMode: StateFlow<Boolean> = _yAutoMode.asStateFlow()

    private val _yMin = MutableStateFlow(-1f)
    val yMin: StateFlow<Float> = _yMin.asStateFlow()

    private val _yMax = MutableStateFlow(1f)
    val yMax: StateFlow<Float> = _yMax.asStateFlow()

    private val _isInteracting = MutableStateFlow(false)
    val isInteracting: StateFlow<Boolean> = _isInteracting.asStateFlow()

    // --- 生データバッファ（メインスレッドからのみアクセス）---
    private val rawChannels = mutableListOf<MutableList<PlotPoint>>()
    private var startTimeMs  = -1L
    private var dirty        = false   // 未反映データがあるか

    private val mainHandler = Handler(Looper.getMainLooper())
    private var frameScheduled = false

    private val frameRunnable = Runnable {
        frameScheduled = false
        if (dirty && !_isInteracting.value) {
            publishSnapshot()
            dirty = false
        }
    }

    // --- データ受信（メインスレッド）---
    fun addLine(line: String) {
        val parts = line.split(",").mapNotNull { it.trim().toFloatOrNull() }
        if (parts.isEmpty()) return

        Log.d(TAG, "addLine: ${parts.size} channels")

        val now = System.currentTimeMillis()
        if (startTimeMs < 0) startTimeMs = now
        val timeSec = (now - startTimeMs) / 1000.0

        while (rawChannels.size < parts.size) rawChannels.add(mutableListOf())

        parts.forEachIndexed { i, value ->
            val list = rawChannels[i]
            list.add(PlotPoint(timeSec, value))
            if (list.size > MAX_POINTS) list.removeAt(0)
        }

        dirty = true
        if (!frameScheduled) {
            frameScheduled = true
            mainHandler.postDelayed(frameRunnable, FRAME_INTERVAL)
        }
    }

    private fun publishSnapshot() {
        if (rawChannels.isEmpty()) return
        val snapshot = rawChannels.mapIndexed { i, points ->
            val existing = _channels.value.getOrNull(i)
            PlotChannel(
                index   = i,
                label   = "Ch${i + 1}",
                color   = CHANNEL_COLORS[i % CHANNEL_COLORS.size],
                visible = existing?.visible ?: true,
                points  = points.toList()
            )
        }
        _channels.value = snapshot
        if (_yAutoMode.value) updateAutoY(snapshot)
    }

    private fun updateAutoY(snapshot: List<PlotChannel>) {
        val window     = _timeWindowSec.value
        val latestTime = snapshot.flatMap { it.points }.maxOfOrNull { it.timeSeconds } ?: return
        val visiblePts = snapshot
            .filter { it.visible }
            .flatMap { it.points }
            .filter { it.timeSeconds >= latestTime - window }
        if (visiblePts.isEmpty()) return
        val min    = visiblePts.minOf { it.value }
        val max    = visiblePts.maxOf { it.value }
        val margin = ((max - min) * 0.1f).coerceAtLeast(0.1f)
        _yMin.value = min - margin
        _yMax.value = max + margin
    }

    // --- チャンネル表示切り替え ---
    fun toggleChannel(index: Int) {
        _channels.value = _channels.value.map {
            if (it.index == index) it.copy(visible = !it.visible) else it
        }
    }

    // --- 時間軸 ---
    fun setTimePreset(seconds: Double) { _timeWindowSec.value = seconds }

    fun scaleTimeWindow(factor: Double) {
        _timeWindowSec.value = (_timeWindowSec.value * factor).coerceIn(0.05, 300.0)
    }

    // --- Y軸 ---
    fun toggleYAxisMode() {
        _yAutoMode.value = !_yAutoMode.value
    }

    fun scaleYAxis(factor: Float) {
        if (_yAutoMode.value) _yAutoMode.value = false
        val center = (_yMin.value + _yMax.value) / 2f
        val half   = ((_yMax.value - _yMin.value) / 2f * factor).coerceAtLeast(0.01f)
        _yMin.value = center - half
        _yMax.value = center + half
    }

    fun shiftYAxis(deltaValue: Float) {
        if (_yAutoMode.value) _yAutoMode.value = false
        _yMin.value += deltaValue
        _yMax.value += deltaValue
    }

    // --- インタラクション ---
    fun setInteracting(v: Boolean) {
        _isInteracting.value = v
        // インタラクション終了時に即座に最新データを反映
        if (!v && dirty) {
            publishSnapshot()
            dirty = false
        }
    }

    // --- クリア ---
    fun clearData() {
        mainHandler.removeCallbacks(frameRunnable)
        frameScheduled = false
        rawChannels.clear()
        startTimeMs = -1L
        dirty = false
        _channels.value = emptyList()
    }
}
