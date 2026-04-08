package com.nwlab.easyarduinobleterm.viewmodel

import androidx.lifecycle.ViewModel
import com.nwlab.easyarduinobleterm.model.TerminalMessage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime

class TerminalViewModel : ViewModel() {

    companion object {
        private const val MAX_MESSAGES = 2000
    }

    private val _messages = MutableStateFlow<List<TerminalMessage>>(emptyList())
    val messages: StateFlow<List<TerminalMessage>> = _messages.asStateFlow()

    private val _showTimestamp = MutableStateFlow(true)
    val showTimestamp: StateFlow<Boolean> = _showTimestamp.asStateFlow()

    private val _autoScroll = MutableStateFlow(true)
    val autoScroll: StateFlow<Boolean> = _autoScroll.asStateFlow()

    // 受信バッファー（UIスレッドから呼ばれる）
    private val pendingLines = ArrayDeque<TerminalMessage>()
    private var lastFlushTime = 0L

    fun addLine(line: String) {
        pendingLines.addLast(TerminalMessage(line, LocalDateTime.now()))
        val now = System.currentTimeMillis()
        if (now - lastFlushTime >= 50L) { // 20fps
            flush()
            lastFlushTime = now
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
    }

    fun toggleTimestamp() {
        _showTimestamp.value = !_showTimestamp.value
    }

    fun toggleAutoScroll() {
        _autoScroll.value = !_autoScroll.value
    }

    fun clearMessages() {
        _messages.value = emptyList()
        pendingLines.clear()
    }
}
