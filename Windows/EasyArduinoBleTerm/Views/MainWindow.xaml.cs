using EasyArduinoBleTerm.Services;
using EasyArduinoBleTerm.ViewModels;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace EasyArduinoBleTerm.Views;

public sealed partial class MainWindow : Window
{
    private readonly MainViewModel _vm;
    private readonly TerminalPage  _terminalPage;
    private readonly PlotterPage   _plotterPage;

    public MainWindow()
    {
        InitializeComponent();

        _vm           = new MainViewModel(Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread());
        _terminalPage = new TerminalPage(_vm.Terminal);
        _plotterPage  = new PlotterPage(_vm.Plotter);

        // 初期ページ
        ContentFrame.Content = _terminalPage;

        // BLE状態変化を購読
        _vm.Ble.StateChanged += OnBleStateChanged;

        // ウィンドウサイズ
        AppWindow.Resize(new Windows.Graphics.SizeInt32(1100, 750));
        Title = "EasyArduinoBleTerm";
    }

    // ---- Tab ----

    private void MainTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        ContentFrame.Content = MainTabView.SelectedIndex switch
        {
            0 => _terminalPage,
            1 => _plotterPage,
            _ => _terminalPage,
        };
    }

    // ---- Connect / Disconnect ----

    private async void ConnectButton_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.IsConnected)
        {
            _vm.DisconnectCommand.Execute(null);
        }
        else
        {
            var dialog = new DeviceSelectionDialog(_vm) { XamlRoot = Content.XamlRoot };
            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
                await _vm.ConnectCommand.ExecuteAsync(null);
        }
    }

    // ---- BLE State ----

    private void OnBleStateChanged(object? sender, BleState state)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            switch (state)
            {
                case BleState.ConnectedState:
                    StatusDot.Fill    = new SolidColorBrush(Colors.LimeGreen);
                    StatusText.Text   = $"接続中: {_vm.Ble.ConnectedDeviceName}";
                    ConnectButton.Content = "切断";
                    ConnectButton.IsEnabled = true;
                    break;

                case BleState.ConnectingState:
                    StatusDot.Fill    = new SolidColorBrush(Colors.Orange);
                    StatusText.Text   = "接続中...";
                    ConnectButton.Content = "接続";
                    ConnectButton.IsEnabled = false;
                    break;

                case BleState.DisconnectedState:
                    StatusDot.Fill    = new SolidColorBrush(Colors.Gray);
                    StatusText.Text   = "未接続";
                    ConnectButton.Content   = "接続";
                    ConnectButton.IsEnabled = true;
                    break;

                case BleState.FailedState f:
                    StatusDot.Fill    = new SolidColorBrush(Colors.Red);
                    StatusText.Text   = $"エラー: {f.Message}";
                    ConnectButton.Content   = "接続";
                    ConnectButton.IsEnabled = true;
                    ShowErrorDialog(f.Message);
                    break;
            }
        });
    }

    private async void ShowErrorDialog(string message)
    {
        var dialog = new ContentDialog
        {
            Title             = "接続エラー",
            Content           = message,
            CloseButtonText   = "OK",
            XamlRoot          = Content.XamlRoot,
        };
        await dialog.ShowAsync();
    }
}
