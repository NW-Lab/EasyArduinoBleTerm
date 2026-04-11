package com.nwlab.easyarduinobleterm.viewmodel

import com.nwlab.easyarduinobleterm.model.TerminalMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class TerminalViewModel(private val scope: CoroutineScope) {

    companion object {
        private const val MAX_MESSAGES    = 2000
        private const val FLUSH_INTERVAL_MS = 50L  // 20fps
    }

    private val _messages = MutableStateFlow<List<TerminalMessage>>(emptyList())
    val messages: StateFlow<List<TerminalMessage>> = _messages.asStateFlow()

    private val _showTimestamp = MutableStateFlow(true)
    val showTimestamp: StateFlow<Boolean> = _showTimestamp.asStateFlow()

    private val _autoScroll = MutableStateFlow(true)
    val autoScroll: StateFlow<Boolean> = _autoScroll.asStateFlow()

    // 受信バッファー（メインスレッドからのみアクセス）
    private val pendingLines = ArrayDeque<TerminalMessage>()
    private var flushJob: Job? = null

    fun addLine(line: String) {
        pendingLines.addLast(TerminalMessage(line, LocalDateTime.now()))

        // フラッシュタイマーが動いていなければ起動
        if (flushJob == null || flushJob?.isActive == false) {
            flushJob = scope.launch {
                delay(FLUSH_INTERVAL_MS)
                flush()
            }
        }
    }

    private fun flush() {
        if (pendingLines.isEmpty()) return
        val current = _messages.value.toMutableList()
        while (pendingLines.isNotEmpty()) {
            current.add(pendingLines.removeFirst())
        }
        if (current.size > MAX_MESSAGES) {
            current.subList(0, current.size - MAX_MESSAGES).clear()
        }
        _messages.value = current
        flushJob = null
    }

    fun toggleTimestamp() { _showTimestamp.value = !_showTimestamp.value }
    fun toggleAutoScroll() { _autoScroll.value = !_autoScroll.value }

    fun clearMessages() {
        _messages.value = emptyList()
        pendingLines.clear()
        flushJob?.cancel()
        flushJob = null
    }
}
