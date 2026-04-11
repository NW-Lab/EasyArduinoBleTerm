package com.nwlab.easyarduinobleterm.viewmodel

import com.nwlab.easyarduinobleterm.model.CHANNEL_COLORS
import com.nwlab.easyarduinobleterm.model.PlotChannel
import com.nwlab.easyarduinobleterm.model.PlotPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class PlotterViewModel(private val scope: CoroutineScope) {

    companion object {
        private const val MAX_POINTS      = 5000
        private const val DISPLAY_FPS_MS  = 33L   // ~30fps
    }

    // --- Display snapshot (published to UI) ---
    private val _channels = MutableStateFlow<List<PlotChannel>>(emptyList())
    val channels: StateFlow<List<PlotChannel>> = _channels.asStateFlow()

    // --- Time window ---
    private val _timeWindowSec = MutableStateFlow(5.0)
    val timeWindowSec: StateFlow<Double> = _timeWindowSec.asStateFlow()

    // --- Y axis ---
    private val _yAutoMode = MutableStateFlow(true)
    val yAutoMode: StateFlow<Boolean> = _yAutoMode.asStateFlow()

    private val _yMin = MutableStateFlow(-1f)
    val yMin: StateFlow<Float> = _yMin.asStateFlow()

    private val _yMax = MutableStateFlow(1f)
    val yMax: StateFlow<Float> = _yMax.asStateFlow()

    // --- Interaction lock ---
    private val _isInteracting = MutableStateFlow(false)
    val isInteracting: StateFlow<Boolean> = _isInteracting.asStateFlow()

    // --- Raw data (not published directly) ---
    private val rawChannels  = mutableListOf<MutableList<PlotPoint>>()
    private var startTimeMs  = -1L
    private var timerJob: Job? = null

    // --- Data ingestion ---

    fun addLine(line: String) {
        val parts = line.split(",").mapNotNull { it.trim().toFloatOrNull() }
        if (parts.isEmpty()) return

        val now = System.currentTimeMillis()
        if (startTimeMs < 0) startTimeMs = now
        val timeSec = (now - startTimeMs) / 1000.0

        // チャンネル数が増えたら拡張
        while (rawChannels.size < parts.size) {
            rawChannels.add(mutableListOf())
        }

        parts.forEachIndexed { i, value ->
            val list = rawChannels[i]
            list.add(PlotPoint(timeSec, value))
            if (list.size > MAX_POINTS) list.removeAt(0)
        }

        // 描画タイマーが止まっていたら起動
        if (timerJob == null || timerJob?.isActive == false) {
            startDisplayTimer()
        }
    }

    private fun startDisplayTimer() {
        timerJob = scope.launch {
            while (true) {
                delay(DISPLAY_FPS_MS)
                if (!_isInteracting.value) publishSnapshot()
            }
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

        // 自動Yスケール
        if (_yAutoMode.value) updateAutoY(snapshot)
    }

    private fun updateAutoY(snapshot: List<PlotChannel>) {
        val window      = _timeWindowSec.value
        val latestTime  = snapshot.flatMap { it.points }.maxOfOrNull { it.timeSeconds } ?: return
        val visiblePts  = snapshot
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

    // --- Channel visibility ---
    fun toggleChannel(index: Int) {
        _channels.value = _channels.value.map {
            if (it.index == index) it.copy(visible = !it.visible) else it
        }
    }

    // --- Time window ---
    fun setTimePreset(seconds: Double) { _timeWindowSec.value = seconds }

    fun scaleTimeWindow(factor: Double) {
        _timeWindowSec.value = (_timeWindowSec.value * factor).coerceIn(0.05, 300.0)
    }

    // --- Y axis ---
    fun toggleYAxisMode() {
        if (_yAutoMode.value) {
            // 自動→固定: 現在の自動範囲をそのまま固定値として引き継ぐ
            _yAutoMode.value = false
        } else {
            _yAutoMode.value = true
        }
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

    // --- Interaction ---
    fun setInteracting(v: Boolean) { _isInteracting.value = v }

    // --- Clear ---
    fun clearData() {
        rawChannels.clear()
        startTimeMs = -1L
        _channels.value = emptyList()
        timerJob?.cancel()
        timerJob = null
    }
}
