package com.nwlab.easyarduinobleterm

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nwlab.easyarduinobleterm.ble.BleState
import com.nwlab.easyarduinobleterm.ui.screens.DeviceScanScreen
import com.nwlab.easyarduinobleterm.ui.screens.PlotterScreen
import com.nwlab.easyarduinobleterm.ui.screens.TerminalScreen
import com.nwlab.easyarduinobleterm.ui.theme.EasyArduinoBleTermTheme
import com.nwlab.easyarduinobleterm.viewmodel.MainViewModel

class MainActivity : ComponentActivity() {

    private val vm: MainViewModel by viewModels()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* 結果は画面側で状態を見て判断 */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // BLE権限リクエスト
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
        permissionLauncher.launch(permissions)

        setContent {
            EasyArduinoBleTermTheme {
                AppContent(vm)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppContent(vm: MainViewModel) {
    val bleState by vm.bleState.collectAsState()
    var showScan by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableIntStateOf(0) }

    val isConnected = bleState is BleState.Connected

    if (showScan) {
        DeviceScanScreen(
            vm          = vm,
            onConnected = { showScan = false }
        )
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    // 接続状態
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val dotColor = when (bleState) {
                            is BleState.Connected    -> Color(0xFF66BB6A)
                            is BleState.Connecting   -> Color(0xFFFFCA28)
                            else                     -> Color.Gray
                        }
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .let {
                                    it // 丸はTextで代用
                                }
                        )
                        Surface(
                            shape = androidx.compose.foundation.shape.CircleShape,
                            color = dotColor,
                            modifier = Modifier.size(10.dp)
                        ) {}
                        Text(
                            text = when (val s = bleState) {
                                is BleState.Connected  -> s.deviceName
                                is BleState.Connecting -> "接続中..."
                                is BleState.Scanning   -> "スキャン中..."
                                is BleState.Error      -> "エラー"
                                else                   -> "未接続"
                            },
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1
                        )
                    }
                },
                actions = {
                    if (isConnected) {
                        IconButton(onClick = { vm.disconnect() }) {
                            Icon(Icons.Default.Close, contentDescription = "切断")
                        }
                    } else {
                        TextButton(onClick = { showScan = true }) {
                            Text("接続", color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick  = { selectedTab = 0 },
                    icon     = { Text(">_", fontSize = 16.sp, fontWeight = FontWeight.Bold) },
                    label    = { Text("ターミナル") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick  = { selectedTab = 1 },
                    icon     = { Text("📈", fontSize = 16.sp) },
                    label    = { Text("プロッター") }
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (selectedTab) {
                0 -> TerminalScreen(
                    vm          = vm.terminalViewModel,
                    isConnected = isConnected,
                    onSend      = { vm.sendText(it) }
                )
                1 -> PlotterScreen(vm = vm.plotterViewModel)
            }
        }
    }
}
