package com.nwlab.easyarduinobleterm.viewmodel

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
        private const val MAX_MESSAGES = 2000
    }

    private val _messages = MutableStateFlow<List<TerminalMessage>>(emptyList())
    val messages: StateFlow<List<TerminalMessage>> = _messages.asStateFlow()

    private val _showTimestamp = MutableStateFlow(true)
    val showTimestamp: StateFlow<Boolean> = _showTimestamp.asStateFlow()

    private val _autoScroll = MutableStateFlow(true)
    val autoScroll: StateFlow<Boolean> = _autoScroll.asStateFlow()

    // BleService.onDataReceived から呼ばれる（メインスレッド）
    fun addLine(line: String) {
        Log.d(TAG, "addLine: $line")
        val msg = TerminalMessage(line, LocalDateTime.now())
        val current = _messages.value
        val next = if (current.size >= MAX_MESSAGES) {
            current.drop(current.size - MAX_MESSAGES + 1) + msg
        } else {
            current + msg
        }
        _messages.value = next
    }

    fun toggleTimestamp() { _showTimestamp.value = !_showTimestamp.value }
    fun toggleAutoScroll() { _autoScroll.value = !_autoScroll.value }

    fun clearMessages() {
        _messages.value = emptyList()
    }
}
