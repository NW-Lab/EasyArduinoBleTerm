using EasyArduinoBleTerm.Services;
using EasyArduinoBleTerm.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace EasyArduinoBleTerm.Views;

public sealed partial class DeviceSelectionDialog : ContentDialog
{
    public MainViewModel ViewModel { get; }

    private bool _isScanning = false;

    public DeviceSelectionDialog(MainViewModel vm)
    {
        ViewModel = vm;
        InitializeComponent();

        // 接続ボタンは選択されるまで無効
        IsPrimaryButtonEnabled = false;
    }

    private void ScanButton_Click(object sender, RoutedEventArgs e)
    {
        if (_isScanning)
        {
            ViewModel.StopScanCommand.Execute(null);
            _isScanning = false;
            ScanButton.Content   = "スキャン開始";
            ScanProgress.IsActive = false;
            ScanStatusText.Text  = "スキャン停止";
        }
        else
        {
            ViewModel.StartScanCommand.Execute(null);
            _isScanning = true;
            ScanButton.Content    = "スキャン停止";
            ScanProgress.IsActive = true;
            ScanStatusText.Text   = "スキャン中...";
        }
    }

    private void DeviceListView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (DeviceListView.SelectedItem is BleDeviceInfo info)
        {
            ViewModel.SelectedDevice   = info;
            IsPrimaryButtonEnabled     = true;
        }
        else
        {
            IsPrimaryButtonEnabled = false;
        }
    }

    protected override void OnApplyTemplate()
    {
        base.OnApplyTemplate();
        // ダイアログが閉じられるときスキャンを停止
        Closed += (_, _) =>
        {
            if (_isScanning)
            {
                ViewModel.StopScanCommand.Execute(null);
                _isScanning = false;
            }
        };
    }
}
