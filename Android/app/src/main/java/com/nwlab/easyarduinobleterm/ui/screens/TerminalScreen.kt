package com.nwlab.easyarduinobleterm.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nwlab.easyarduinobleterm.viewmodel.TerminalViewModel
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter

@Composable
fun TerminalScreen(
    vm: TerminalViewModel,
    isConnected: Boolean,
    onSend: (String) -> Unit
) {
    val messages     by vm.messages.collectAsState()
    val showTs       by vm.showTimestamp.collectAsState()
    val autoScroll   by vm.autoScroll.collectAsState()
    val listState    = rememberLazyListState()
    val scope        = rememberCoroutineScope()
    var inputText    by remember { mutableStateOf("") }
    val tsFormatter  = remember { DateTimeFormatter.ofPattern("HH:mm:ss.SSS") }

    // 自動スクロール
    LaunchedEffect(messages.size) {
        if (autoScroll && messages.isNotEmpty()) {
            scope.launch {
                listState.animateScrollToItem(messages.size - 1)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1E1E1E))
    ) {
        // --- ツールバー ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // タイムスタンプ ON/OFF
            FilterChip(
                selected = showTs,
                onClick  = { vm.toggleTimestamp() },
                label    = { Text("日時", fontSize = 12.sp) }
            )
            // 自動スクロール
            FilterChip(
                selected = autoScroll,
                onClick  = { vm.toggleAutoScroll() },
                label    = { Text("自動スクロール", fontSize = 12.sp) }
            )
            Spacer(Modifier.weight(1f))
            // クリア
            IconButton(onClick = { vm.clearMessages() }) {
                Icon(Icons.Default.Delete, contentDescription = "クリア", tint = Color(0xFFEF5350))
            }
        }

        HorizontalDivider(color = Color(0xFF333333))

        // --- メッセージリスト ---
        LazyColumn(
            state    = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            verticalArrangement = Arrangement.spacedBy(1.dp)
        ) {
            items(messages, key = { it.hashCode() }) { msg ->
                Row(modifier = Modifier.fillMaxWidth()) {
                    if (showTs) {
                        Text(
                            text     = msg.timestamp.format(tsFormatter) + "  ",
                            color    = Color(0xFF888888),
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                    Text(
                        text       = msg.text,
                        color      = Color(0xFF00FF00),
                        fontSize   = 12.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }
        }

        HorizontalDivider(color = Color(0xFF333333))

        // --- 送信フィールド ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value         = inputText,
                onValueChange = { inputText = it },
                modifier      = Modifier.weight(1f),
                placeholder   = { Text("送信データを入力...") },
                singleLine    = true,
                enabled       = isConnected,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = {
                    if (inputText.isNotBlank()) {
                        onSend(inputText)
                        inputText = ""
                    }
                }),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor   = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Button(
                onClick  = {
                    if (inputText.isNotBlank()) {
                        onSend(inputText)
                        inputText = ""
                    }
                },
                enabled  = isConnected && inputText.isNotBlank()
            ) {
                Text("送信")
            }
        }
    }
}
