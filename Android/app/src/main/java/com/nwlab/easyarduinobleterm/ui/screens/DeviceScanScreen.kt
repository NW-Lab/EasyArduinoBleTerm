package com.nwlab.easyarduinobleterm.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nwlab.easyarduinobleterm.ble.BleDevice
import com.nwlab.easyarduinobleterm.ble.BleState
import com.nwlab.easyarduinobleterm.viewmodel.MainViewModel

@Composable
fun DeviceScanScreen(
    vm: MainViewModel,
    onConnected: () -> Unit
) {
    val bleState by vm.bleState.collectAsState()
    val devices  by vm.scannedDevices.collectAsState()
    val isScanning = bleState is BleState.Scanning

    // 接続完了したら戻る
    LaunchedEffect(bleState) {
        if (bleState is BleState.Connected) onConnected()
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text       = "BLE デバイスを選択",
                fontSize   = 18.sp,
                fontWeight = FontWeight.SemiBold,
                modifier   = Modifier.weight(1f)
            )
            Button(
                onClick = { if (isScanning) vm.stopScan() else vm.startScan() }
            ) {
                if (isScanning) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("停止")
                } else {
                    Icon(Icons.Default.Refresh, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("スキャン")
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        if (devices.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                Text(
                    text  = if (isScanning) "スキャン中..." else "デバイスが見つかりません\n「スキャン」を押してください",
                    color = Color.Gray,
                    fontSize = 14.sp
                )
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(devices) { device ->
                    DeviceItem(
                        device    = device,
                        isLoading = bleState is BleState.Connecting,
                        onClick   = { vm.connect(device) }
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceItem(
    device: BleDevice,
    isLoading: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isLoading) { onClick() },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text       = device.name,
                    fontSize   = 15.sp,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text     = device.address,
                    fontSize = 12.sp,
                    color    = Color.Gray
                )
            }
            // RSSI インジケーター
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text     = "${device.rssi} dBm",
                    fontSize = 12.sp,
                    color    = rssiColor(device.rssi)
                )
                Text(
                    text     = rssiLabel(device.rssi),
                    fontSize = 11.sp,
                    color    = rssiColor(device.rssi)
                )
            }
        }
    }
}

private fun rssiColor(rssi: Int): Color = when {
    rssi >= -60 -> Color(0xFF66BB6A)
    rssi >= -75 -> Color(0xFFFFCA28)
    rssi >= -90 -> Color(0xFFFF7043)
    else        -> Color(0xFFEF5350)
}

private fun rssiLabel(rssi: Int): String = when {
    rssi >= -60 -> "強"
    rssi >= -75 -> "中"
    rssi >= -90 -> "弱"
    else        -> "微弱"
}
