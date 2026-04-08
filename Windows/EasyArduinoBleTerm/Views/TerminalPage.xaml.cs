using EasyArduinoBleTerm.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.System;

namespace EasyArduinoBleTerm.Views;

public sealed partial class TerminalPage : Page
{
    public TerminalViewModel ViewModel { get; }

    public TerminalPage(TerminalViewModel vm)
    {
        ViewModel = vm;
        InitializeComponent();

        // 新しい行が追加されたら自動スクロール
        ViewModel.Lines.CollectionChanged += (_, _) =>
        {
            if (ViewModel.AutoScroll)
                TerminalScroller.ChangeView(null, double.MaxValue, null);
        };
    }

    private void SendTextBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter)
        {
            ViewModel.SendCommand.Execute(null);
            e.Handled = true;
        }
    }
}
