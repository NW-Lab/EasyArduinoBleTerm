using EasyArduinoBleTerm.Helpers;
using EasyArduinoBleTerm.ViewModels;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Windows.System;
using Windows.UI;

namespace EasyArduinoBleTerm.Views;

public sealed partial class PlotterPage : Page
{
    public PlotterViewModel ViewModel { get; }

    // ---- Mouse interaction state ----
    private bool   _isDragging    = false;
    private double _dragStartY    = 0;
    private double _dragStartYMin = 0;
    private double _dragStartYMax = 0;

    public PlotterPage(PlotterViewModel vm)
    {
        ViewModel = vm;
        InitializeComponent();

        ViewModel.PlotRefreshRequested += (_, _) =>
        {
            UpdateChannelButtons();
            UpdateEmptyState();
            PlotCanvas.Invalidate();
            UpdateYAxisModeButton();
        };
    }

    // ---- Win2D Draw ----

    private void PlotCanvas_Draw(CanvasControl sender, CanvasDrawEventArgs args)
    {
        PlotCanvasHelper.Draw(
            args.DrawingSession,
            (float)sender.ActualWidth,
            (float)sender.ActualHeight,
            ViewModel.ChannelSnapshots,
            ViewModel.VisibleStartTime,
            ViewModel.DisplayTimeSpan,
            ViewModel.YRange.Min,
            ViewModel.YRange.Max,
            ViewModel.GridInterval);
    }

    // ---- Mouse: Wheel (横軸ズーム / 縦軸ズーム) ----
    // ・通常ホイール       → 横軸（時間幅）ズーム
    // ・Ctrl + ホイール   → 縦軸（値の幅）ズーム
    // ・Shift + ホイール  → 縦軸オフセット（上下スクロール）

    private void PlotCanvas_PointerWheelChanged(object sender, PointerRoutedEventArgs e)
    {
        var props = e.GetCurrentPoint(PlotCanvas).Properties;
        int delta = props.MouseWheelDelta; // 正 = 上方向

        var keys = Microsoft.UI.Input.InputKeyboardSource
                       .GetKeyStateForCurrentThread(VirtualKey.Control);
        bool ctrlDown = keys.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);

        var shiftKeys = Microsoft.UI.Input.InputKeyboardSource
                            .GetKeyStateForCurrentThread(VirtualKey.Shift);
        bool shiftDown = shiftKeys.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);

        if (ctrlDown)
        {
            // 縦軸ズーム（中心を保ったまま範囲を拡大縮小）
            EnsureFixedYAxis();
            double center   = (ViewModel.YFixedMin + ViewModel.YFixedMax) / 2;
            double halfSpan = (ViewModel.YFixedMax - ViewModel.YFixedMin) / 2;
            double factor   = delta > 0 ? 0.85 : 1.0 / 0.85;  // 上ホイール=ズームイン
            double newHalf  = Math.Clamp(halfSpan * factor, 1e-6, 1e9);
            ViewModel.YFixedMin = center - newHalf;
            ViewModel.YFixedMax = center + newHalf;
        }
        else if (shiftDown)
        {
            // 縦軸オフセット
            EnsureFixedYAxis();
            double ySpan  = ViewModel.YFixedMax - ViewModel.YFixedMin;
            double shift  = ySpan * (delta > 0 ? 0.1 : -0.1);
            ViewModel.YFixedMin += shift;
            ViewModel.YFixedMax += shift;
        }
        else
        {
            // 横軸ズーム
            double factor  = delta > 0 ? 0.85 : 1.0 / 0.85;
            double newSpan = Math.Clamp(ViewModel.DisplayTimeSpan * factor, 0.05, 300.0);
            ViewModel.DisplayTimeSpan = newSpan;
            UpdateGridInterval();
        }

        ViewModel.PauseDisplay();
        PlotCanvas.Invalidate();
        ShowGestureHint(ctrlDown ? "縦軸ズーム (Ctrl+ホイール)" :
                        shiftDown ? "縦軸スクロール (Shift+ホイール)" :
                        "横軸ズーム (ホイール)");
        ViewModel.ResumeDisplay();
        e.Handled = true;
    }

    // ---- Mouse: Right-drag (縦軸オフセット) ----

    private void PlotCanvas_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        var props = e.GetCurrentPoint(PlotCanvas).Properties;
        if (!props.IsRightButtonPressed) return;

        EnsureFixedYAxis();
        _isDragging    = true;
        _dragStartY    = e.GetCurrentPoint(PlotCanvas).Position.Y;
        _dragStartYMin = ViewModel.YFixedMin;
        _dragStartYMax = ViewModel.YFixedMax;
        PlotCanvas.CapturePointer(e.Pointer);
        ViewModel.PauseDisplay();
        ShowGestureHint("縦軸スクロール (右ドラッグ)");
        e.Handled = true;
    }

    private void PlotCanvas_PointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_isDragging) return;

        double currentY  = e.GetCurrentPoint(PlotCanvas).Position.Y;
        double deltaY    = currentY - _dragStartY;          // 下が正
        double graphH    = PlotCanvas.ActualHeight;
        if (graphH <= 0) return;

        double ySpan  = _dragStartYMax - _dragStartYMin;
        double shift  = deltaY / graphH * ySpan;            // 下ドラッグ → 値が小さい方向

        ViewModel.YFixedMin = _dragStartYMin + shift;
        ViewModel.YFixedMax = _dragStartYMax + shift;
        PlotCanvas.Invalidate();
        e.Handled = true;
    }

    private void PlotCanvas_PointerReleased(object sender, PointerRoutedEventArgs e)
    {
        EndDrag(e.Pointer);
        e.Handled = true;
    }

    private void PlotCanvas_PointerCaptureLost(object sender, PointerRoutedEventArgs e)
    {
        EndDrag(null);
    }

    private void EndDrag(Pointer? pointer)
    {
        if (!_isDragging) return;
        _isDragging = false;
        if (pointer != null) PlotCanvas.ReleasePointerCapture(pointer);
        ViewModel.ResumeDisplay();
        HideGestureHint();
    }

    // ---- Gesture hint ----

    private DispatcherTimer? _hintTimer;

    private void ShowGestureHint(string text)
    {
        GestureHintText.Text       = text;
        GestureHintText.Visibility = Visibility.Visible;

        _hintTimer?.Stop();
        _hintTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
        _hintTimer.Tick += (_, _) => { HideGestureHint(); _hintTimer?.Stop(); };
        _hintTimer.Start();
    }

    private void HideGestureHint()
    {
        GestureHintText.Visibility = Visibility.Collapsed;
    }

    // ---- Y Axis Mode Button ----

    private void YAxisModeButton_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.ToggleYAxisMode();
        UpdateYAxisModeButton();
        PlotCanvas.Invalidate();
    }

    private void UpdateYAxisModeButton()
    {
        if (ViewModel.YAxisMode == YAxisMode.Fixed)
        {
            YAxisModeIcon.Glyph = "\uE72E"; // Lock icon
            YAxisModeText.Text  = "固定";
            YAxisModeButton.Background = new SolidColorBrush(
                Color.FromArgb(40, 255, 165, 0));
        }
        else
        {
            YAxisModeIcon.Glyph = "\uE8CB"; // Sort icon
            YAxisModeText.Text  = "自動";
            YAxisModeButton.Background = null;
        }
    }

    // ---- Time Scale ----

    private void TimeScaleRadio_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (TimeScaleRadio.SelectedItem is RadioButton rb &&
            int.TryParse(rb.Tag?.ToString(), out int idx))
        {
            ViewModel.SelectedTimeScaleIndex = idx;
            UpdateGridInterval();
            PlotCanvas.Invalidate();
        }
    }

    private void UpdateGridInterval()
    {
        // DisplayTimeSpan に合わせて GridInterval を自動調整
        var span = ViewModel.DisplayTimeSpan;
        ViewModel.GridInterval = span switch
        {
            <= 1    => 0.1,
            <= 10   => 1.0,
            <= 60   => 10.0,
            <= 300  => 30.0,
            _       => 60.0,
        };
    }

    // ---- Channel buttons ----

    private void UpdateChannelButtons()
    {
        var channels = ViewModel.ChannelSnapshots;
        if (channels.Count == ChannelPanel.Children.Count) return;

        ChannelPanel.Children.Clear();
        foreach (var ch in channels)
        {
            var btn = new ToggleButton
            {
                Content    = ch.Label,
                IsChecked  = ch.IsEnabled,
                Margin     = new Thickness(0),
                Padding    = new Thickness(10, 4, 10, 4),
                Background = new SolidColorBrush(
                    Color.FromArgb(40,
                        ch.LineColor.R, ch.LineColor.G, ch.LineColor.B)),
                BorderBrush = new SolidColorBrush(ch.LineColor),
            };
            int capturedId = ch.Id;
            btn.Click += (_, _) =>
            {
                ViewModel.ToggleChannel(capturedId);
                PlotCanvas.Invalidate();
            };
            ChannelPanel.Children.Add(btn);
        }
    }

    // ---- Empty state ----

    private void UpdateEmptyState()
    {
        bool hasData = ViewModel.ChannelSnapshots.Count > 0;
        EmptyState.Visibility  = hasData ? Visibility.Collapsed  : Visibility.Visible;
        PlotCanvas.Visibility  = hasData ? Visibility.Visible    : Visibility.Collapsed;
    }

    // ---- Helpers ----

    private void EnsureFixedYAxis()
    {
        if (ViewModel.YAxisMode == YAxisMode.Auto)
        {
            ViewModel.YFixedMin = ViewModel.YRange.Min;
            ViewModel.YFixedMax = ViewModel.YRange.Max;
            ViewModel.YAxisMode = YAxisMode.Fixed;
            UpdateYAxisModeButton();
        }
    }
}
