using EasyArduinoBleTerm.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Text;
using Microsoft.UI;
using Windows.Foundation;
using Windows.UI;

namespace EasyArduinoBleTerm.Helpers;

/// <summary>
/// Win2D の CanvasDrawingSession にグラフを描画するヘルパー
/// </summary>
public static class PlotCanvasHelper
{
    public static void Draw(
        CanvasDrawingSession ds,
        float width,
        float height,
        IReadOnlyList<PlotChannel> channels,
        double visibleStartTime,
        double displayTimeSpan,
        double yMin,
        double yMax,
        double gridInterval)
    {
        if (width <= 0 || height <= 0) return;

        double ySpan = Math.Max(yMax - yMin, 1e-9);

        // ---- Background ----
        ds.Clear(Color.FromArgb(255, 18, 18, 18));

        // ---- Vertical grid lines (time axis) ----
        if (gridInterval > 0 && displayTimeSpan > 0)
        {
            double firstGrid = Math.Ceiling(visibleStartTime / gridInterval) * gridInterval;
            double t = firstGrid;
            double endT = visibleStartTime + displayTimeSpan;
            int maxLines = (int)(displayTimeSpan / gridInterval) + 2;
            int count = 0;

            while (t <= endT + gridInterval * 0.001 && count < maxLines)
            {
                float x = (float)((t - visibleStartTime) / displayTimeSpan * width);
                ds.DrawLine(x, 0, x, height,
                    Color.FromArgb(60, 180, 180, 180), 0.5f);
                t += gridInterval;
                count++;
            }
        }

        // ---- Zero line ----
        if (yMin < 0 && yMax > 0)
        {
            float zeroY = height - (float)((0 - yMin) / ySpan * height);
            ds.DrawLine(0, zeroY, width, zeroY,
                Color.FromArgb(120, 200, 200, 200), 1f);
        }

        // ---- Plot channels ----
        double lo  = visibleStartTime - gridInterval;
        double hi  = visibleStartTime + displayTimeSpan + gridInterval;

        foreach (var ch in channels.Where(c => c.IsEnabled))
        {
            var pts = ch.Points.Where(p => p.Time >= lo && p.Time <= hi).ToList();
            if (pts.Count < 2) continue;

            using var pathBuilder = new CanvasPathBuilder(ds);
            bool started = false;

            foreach (var pt in pts)
            {
                float x = (float)((pt.Time - visibleStartTime) / displayTimeSpan * width);
                float rawY = height - (float)((pt.Value - yMin) / ySpan * height);
                float y = Math.Clamp(rawY, -5f, height + 5f);

                if (!started)
                {
                    pathBuilder.BeginFigure(x, y);
                    started = true;
                }
                else
                {
                    pathBuilder.AddLine(x, y);
                }
            }
            if (started)
            {
                pathBuilder.EndFigure(CanvasFigureLoop.Open);
                using var geo = CanvasGeometry.CreatePath(pathBuilder);
                ds.DrawGeometry(geo, ch.LineColor, 2f);
            }
        }

        // ---- Y axis labels ----
        DrawYAxisLabels(ds, width, height, yMin, yMax);

        // ---- Time scale label ----
        DrawTimeScaleLabel(ds, width, height, displayTimeSpan, gridInterval);
    }

    private static void DrawYAxisLabels(
        CanvasDrawingSession ds, float w, float h,
        double yMin, double yMax)
    {
        double ySpan = yMax - yMin;
        int steps = 5;
        var fmt = new CanvasTextFormat
        {
            FontSize    = 10,
            FontFamily  = "Consolas",
            HorizontalAlignment = CanvasHorizontalAlignment.Left,
        };

        for (int i = 0; i <= steps; i++)
        {
            double frac  = (double)i / steps;
            double value = yMin + frac * ySpan;
            float  y     = h - (float)(frac * h);

            string label = FormatValue(value);
            ds.DrawText(label, 4, y - 8, Color.FromArgb(180, 200, 200, 200), fmt);
        }
    }

    private static void DrawTimeScaleLabel(
        CanvasDrawingSession ds, float w, float h,
        double displayTimeSpan, double gridInterval)
    {
        string text = $"表示幅: {FormatSpan(displayTimeSpan)}  目盛: {FormatSpan(gridInterval)}";
        var fmt = new CanvasTextFormat
        {
            FontSize   = 10,
            FontFamily = "Consolas",
            HorizontalAlignment = CanvasHorizontalAlignment.Right,
        };
        ds.DrawText(text, new Rect(0, h - 20, w - 4, 20),
            Color.FromArgb(160, 200, 200, 200), fmt);
    }

    private static string FormatValue(double v)
    {
        if (Math.Abs(v) >= 1000) return v.ToString("F0");
        if (Math.Abs(v) >= 100)  return v.ToString("F1");
        return v.ToString("F2");
    }

    private static string FormatSpan(double s)
    {
        if (s < 1)   return $"{s * 1000:F0}ms";
        if (s < 100) return $"{s:F2}s";
        return $"{s:F0}s";
    }
}
