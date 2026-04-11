package com.nwlab.easyarduinobleterm.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.nwlab.easyarduinobleterm.ble.BleDevice
import com.nwlab.easyarduinobleterm.ble.BleService
import com.nwlab.easyarduinobleterm.ble.BleState
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn

class MainViewModel(application: Application) : AndroidViewModel(application) {

    val bleService = BleService(application)

    val bleState = bleService.state.stateIn(
        viewModelScope, SharingStarted.Eagerly, BleState.Disconnected
    )
    val scannedDevices = bleService.scannedDevices.stateIn(
        viewModelScope, SharingStarted.Eagerly, emptyList()
    )

    // viewModelScope を渡して子ViewModelのスコープを共有
    val terminalViewModel = TerminalViewModel(viewModelScope)
    val plotterViewModel  = PlotterViewModel(viewModelScope)

    init {
        // BleService からデータが届いたらターミナル・プロッターに転送
        // onDataReceived はメインスレッドから呼ばれる
        bleService.onDataReceived = { line ->
            terminalViewModel.addLine(line)
            plotterViewModel.addLine(line)
        }
    }

    fun startScan()  = bleService.startScan()
    fun stopScan()   = bleService.stopScan()
    fun connect(device: BleDevice) = bleService.connect(device)
    fun disconnect() = bleService.disconnect()
    fun sendText(text: String) = bleService.send(text)

    override fun onCleared() {
        super.onCleared()
        bleService.disconnect()
    }
}
