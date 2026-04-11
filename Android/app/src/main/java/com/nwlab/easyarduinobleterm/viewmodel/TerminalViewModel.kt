package com.nwlab.easyarduinobleterm.viewmodel

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nwlab.easyarduinobleterm.model.TerminalMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime

private const val TAG = "TerminalViewModel"

class TerminalViewModel(private val scope: CoroutineScope) {

    companion object {
        private const val MAX_MESSAGES   = 2000
        private const val FLUSH_INTERVAL = 33L   // ~30fps
    }

    private val _messages = MutableStateFlow<List<TerminalMessage>>(emptyList())
    val messages: StateFlow<List<TerminalMessage>> = _messages.asStateFlow()

    private val _showTimestamp = MutableStateFlow(true)
    val showTimestamp: StateFlow<Boolean> = _showTimestamp.asStateFlow()

    private val _autoScroll = MutableStateFlow(true)
    val autoScroll: StateFlow<Boolean> = _autoScroll.asStateFlow()

    // 受信バッファ（メインスレッドからのみアクセス）
    private val pending = ArrayDeque<TerminalMessage>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var flushScheduled = false

    private val flushRunnable = Runnable {
        flushScheduled = false
        if (pending.isEmpty()) return@Runnable
        val current = _messages.value
        val added = ArrayList<TerminalMessage>(pending.size)
        while (pending.isNotEmpty()) added.add(pending.removeFirst())
        val next = if (current.size + added.size > MAX_MESSAGES) {
            val drop = current.size + added.size - MAX_MESSAGES
            current.drop(drop) + added
        } else {
            current + added
        }
        _messages.value = next
    }

    // BleService.onDataReceived から呼ばれる（メインスレッド）
    fun addLine(line: String) {
        Log.d(TAG, "addLine: $line")
        pending.addLast(TerminalMessage(line, LocalDateTime.now()))
        if (!flushScheduled) {
            flushScheduled = true
            mainHandler.postDelayed(flushRunnable, FLUSH_INTERVAL)
        }
    }

    fun toggleTimestamp() { _showTimestamp.value = !_showTimestamp.value }
    fun toggleAutoScroll() { _autoScroll.value = !_autoScroll.value }

    fun clearMessages() {
        mainHandler.removeCallbacks(flushRunnable)
        flushScheduled = false
        pending.clear()
        _messages.value = emptyList()
    }
}
