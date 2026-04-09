import React, { useRef, useEffect, useState, useCallback } from 'react';
import type { PlotChannel, YAxisMode } from '../types';
import { TIME_PRESETS } from '../types';

interface Props {
  channels: PlotChannel[];
  onToggleChannel: (index: number) => void;
  onClear: () => void;
}

const PADDING = { top: 10, right: 20, bottom: 30, left: 60 };

export const PlotterPage: React.FC<Props> = ({ channels, onToggleChannel, onClear }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // 表示幅（秒）
  const [timeWindow, setTimeWindow] = useState(10);
  // 縦軸
  const [yMode, setYMode] = useState<YAxisMode>('auto');
  const [yMin, setYMin] = useState(-1);
  const [yMax, setYMax] = useState(1);
  const [yOffset, setYOffset] = useState(0); // 固定モード時のオフセット

  // ドラッグ状態
  const dragRef = useRef<{ startY: number; startOffset: number } | null>(null);

  // ピンチ中フラグ（描画一時停止用）
  const isPausedRef = useRef(false);

  // 最新のstateをrefで保持（イベントハンドラから参照するため）
  const stateRef = useRef({ timeWindow, yMode, yMin, yMax, yOffset });
  useEffect(() => {
    stateRef.current = { timeWindow, yMode, yMin, yMax, yOffset };
  }, [timeWindow, yMode, yMin, yMax, yOffset]);

  // ---- 描画 ----
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const W = canvas.width;
    const H = canvas.height;
    const plotW = W - PADDING.left - PADDING.right;
    const plotH = H - PADDING.top - PADDING.bottom;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#1a1a1a';
    ctx.fillRect(0, 0, W, H);

    const { timeWindow: tw, yMode: ym, yOffset: yo } = stateRef.current;
    let { yMin: yMn, yMax: yMx } = stateRef.current;

    // 自動モード: 表示中データから範囲計算
    const visibleChannels = channels.filter(ch => ch.visible && ch.data.length > 0);
    if (ym === 'auto' && visibleChannels.length > 0) {
      const latestTime = Math.max(...visibleChannels.map(ch => ch.data[ch.data.length - 1].time));
      const startTime = latestTime - tw;
      let allMin = Infinity, allMax = -Infinity;
      for (const ch of visibleChannels) {
        for (const pt of ch.data) {
          if (pt.time >= startTime) {
            if (pt.value < allMin) allMin = pt.value;
            if (pt.value > allMax) allMax = pt.value;
          }
        }
      }
      if (allMin !== Infinity) {
        const margin = (allMax - allMin) * 0.1 || 0.5;
        yMn = allMin - margin;
        yMx = allMax + margin;
      }
    } else if (ym === 'fixed') {
      yMn = stateRef.current.yMin + yo;
      yMx = stateRef.current.yMax + yo;
    }

    const yRange = yMx - yMn || 1;

    // 座標変換
    const toX = (t: number, latestTime: number) =>
      PADDING.left + ((t - (latestTime - tw)) / tw) * plotW;
    const toY = (v: number) =>
      PADDING.top + plotH - ((v - yMn) / yRange) * plotH;

    const latestTime = visibleChannels.length > 0
      ? Math.max(...visibleChannels.map(ch => ch.data[ch.data.length - 1].time))
      : tw;

    // グリッド
    ctx.strokeStyle = '#2a2a2a';
    ctx.lineWidth = 1;
    // 縦グリッド（時間）
    const gridCount = 5;
    for (let i = 0; i <= gridCount; i++) {
      const x = PADDING.left + (i / gridCount) * plotW;
      ctx.beginPath();
      ctx.moveTo(x, PADDING.top);
      ctx.lineTo(x, PADDING.top + plotH);
      ctx.stroke();
    }
    // 横グリッド（値）
    const yGridCount = 5;
    for (let i = 0; i <= yGridCount; i++) {
      const y = PADDING.top + (i / yGridCount) * plotH;
      ctx.beginPath();
      ctx.moveTo(PADDING.left, y);
      ctx.lineTo(PADDING.left + plotW, y);
      ctx.stroke();
    }

    // ゼロライン
    if (yMn < 0 && yMx > 0) {
      const y0 = toY(0);
      ctx.strokeStyle = '#444';
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(PADDING.left, y0);
      ctx.lineTo(PADDING.left + plotW, y0);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // 軸ラベル（縦軸）
    ctx.fillStyle = '#888';
    ctx.font = '11px monospace';
    ctx.textAlign = 'right';
    for (let i = 0; i <= yGridCount; i++) {
      const v = yMx - (i / yGridCount) * yRange;
      const y = PADDING.top + (i / yGridCount) * plotH;
      ctx.fillText(v.toFixed(2), PADDING.left - 4, y + 4);
    }

    // 横軸ラベル（時間幅表示）
    ctx.textAlign = 'center';
    ctx.fillStyle = '#666';
    ctx.font = '11px monospace';
    const stepLabel = tw >= 10 ? `${tw.toFixed(0)}s` : tw >= 1 ? `${tw.toFixed(1)}s` : `${(tw * 1000).toFixed(0)}ms`;
    ctx.fillText(`← ${stepLabel} →`, PADDING.left + plotW / 2, H - 6);

    // データ描画
    for (const ch of visibleChannels) {
      const startTime = latestTime - tw;
      const pts = ch.data.filter(p => p.time >= startTime - 0.1);
      if (pts.length < 2) continue;

      ctx.strokeStyle = ch.color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let first = true;
      for (const pt of pts) {
        const x = toX(pt.time, latestTime);
        const y = toY(pt.value);
        if (first) { ctx.moveTo(x, y); first = false; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    // クリップ（プロット領域外を隠す）
    ctx.fillStyle = '#1a1a1a';
    ctx.fillRect(0, 0, PADDING.left, H);
    ctx.fillRect(PADDING.left + plotW, 0, PADDING.right, H);
    ctx.fillRect(0, 0, W, PADDING.top);
    ctx.fillRect(0, PADDING.top + plotH, W, PADDING.bottom);

    // 枠線
    ctx.strokeStyle = '#444';
    ctx.lineWidth = 1;
    ctx.strokeRect(PADDING.left, PADDING.top, plotW, plotH);
  }, [channels]);

  // 30fps 描画ループ
  useEffect(() => {
    let animId: number;
    const loop = () => {
      if (!isPausedRef.current) draw();
      animId = requestAnimationFrame(loop);
    };
    animId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(animId);
  }, [draw]);

  // Canvasリサイズ
  useEffect(() => {
    const resize = () => {
      const canvas = canvasRef.current;
      const container = containerRef.current;
      if (!canvas || !container) return;
      canvas.width = container.clientWidth;
      canvas.height = container.clientHeight;
    };
    resize();
    const observer = new ResizeObserver(resize);
    if (containerRef.current) observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  // ---- マウスイベント ----
  const handleWheel = useCallback((e: React.WheelEvent) => {
    e.preventDefault();
    const factor = e.deltaY > 0 ? 1.15 : 0.87;

    if (e.ctrlKey) {
      // Ctrl + ホイール → 縦軸ズーム
      if (stateRef.current.yMode === 'auto') {
        // 自動モードから固定モードに切り替え
        const { yMin: mn, yMax: mx } = stateRef.current;
        const center = (mn + mx) / 2;
        const half = ((mx - mn) / 2) * factor;
        setYMode('fixed');
        setYMin(center - half);
        setYMax(center + half);
        setYOffset(0);
      } else {
        const { yMin: mn, yMax: mx } = stateRef.current;
        const center = (mn + mx) / 2;
        const half = ((mx - mn) / 2) * factor;
        setYMin(center - half);
        setYMax(center + half);
      }
    } else if (e.shiftKey) {
      // Shift + ホイール → 縦軸オフセット
      if (stateRef.current.yMode === 'auto') {
        const { yMin: mn, yMax: mx } = stateRef.current;
        const center = (mn + mx) / 2;
        const half = (mx - mn) / 2;
        setYMode('fixed');
        setYMin(center - half);
        setYMax(center + half);
        setYOffset(0);
      }
      const range = stateRef.current.yMax - stateRef.current.yMin;
      const delta = (e.deltaY > 0 ? -1 : 1) * range * 0.1;
      setYOffset(prev => prev + delta);
    } else {
      // ホイール → 横軸ズーム
      setTimeWindow(prev => Math.min(300, Math.max(0.05, prev * factor)));
    }
  }, []);

  // 右ドラッグ → 縦軸オフセット
  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    if (e.button !== 2) return;
    e.preventDefault();
    if (stateRef.current.yMode === 'auto') {
      const { yMin: mn, yMax: mx } = stateRef.current;
      const center = (mn + mx) / 2;
      const half = (mx - mn) / 2;
      setYMode('fixed');
      setYMin(center - half);
      setYMax(center + half);
      setYOffset(0);
    }
    dragRef.current = { startY: e.clientY, startOffset: stateRef.current.yOffset };
  }, []);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (!dragRef.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const plotH = canvas.height - PADDING.top - PADDING.bottom;
    const range = stateRef.current.yMax - stateRef.current.yMin;
    const dy = e.clientY - dragRef.current.startY;
    const delta = (dy / plotH) * range;
    setYOffset(dragRef.current.startOffset - delta);
  }, []);

  const handleMouseUp = useCallback(() => {
    dragRef.current = null;
  }, []);

  const toggleYMode = useCallback(() => {
    if (stateRef.current.yMode === 'auto') {
      setYMode('fixed');
    } else {
      setYMode('auto');
      setYOffset(0);
    }
  }, []);

  return (
    <div style={styles.container}>
      {/* ツールバー */}
      <div style={styles.toolbar}>
        {/* 時間プリセット */}
        <div style={styles.presetGroup}>
          {TIME_PRESETS.map(t => (
            <button
              key={t}
              onClick={() => setTimeWindow(t)}
              style={{
                ...styles.presetBtn,
                ...(timeWindow === t ? styles.presetBtnActive : {}),
              }}
            >
              {t < 1 ? `${t * 1000}ms` : `${t}s`}
            </button>
          ))}
        </div>

        {/* 縦軸モードトグル */}
        <button onClick={toggleYMode} style={{
          ...styles.yModeBtn,
          ...(yMode === 'fixed' ? styles.yModeBtnFixed : {}),
        }}>
          {yMode === 'auto' ? '↕ 自動' : '🔒 固定'}
        </button>

        {/* チャンネル選択 */}
        <div style={styles.channelGroup}>
          {channels.map(ch => (
            <button
              key={ch.index}
              onClick={() => onToggleChannel(ch.index)}
              style={{
                ...styles.channelBtn,
                borderColor: ch.color,
                opacity: ch.visible ? 1 : 0.35,
              }}
            >
              <span style={{ ...styles.channelDot, background: ch.color }} />
              {ch.label}
            </button>
          ))}
        </div>

        {/* クリア */}
        <button onClick={onClear} style={styles.clearBtn} title="データをクリア">🗑</button>
      </div>

      {/* グラフエリア */}
      <div
        ref={containerRef}
        style={styles.canvasContainer}
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
        onContextMenu={e => e.preventDefault()}
      >
        <canvas ref={canvasRef} style={styles.canvas} />

        {/* 操作ヒント */}
        <div style={styles.hint}>
          ホイール: 横軸ズーム　Ctrl+ホイール: 縦軸ズーム　Shift+ホイール / 右ドラッグ: 縦軸移動
        </div>
      </div>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    background: '#1a1a1a',
    color: '#e0e0e0',
  },
  toolbar: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '6px 12px',
    background: '#252525',
    borderBottom: '1px solid #333',
    flexShrink: 0,
    flexWrap: 'wrap',
  },
  presetGroup: {
    display: 'flex',
    gap: 4,
  },
  presetBtn: {
    padding: '4px 10px',
    background: '#333',
    color: '#ccc',
    border: '1px solid #555',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 12,
  },
  presetBtnActive: {
    background: '#4fc3f7',
    color: '#000',
    borderColor: '#4fc3f7',
    fontWeight: 'bold',
  },
  yModeBtn: {
    padding: '4px 12px',
    background: '#333',
    color: '#ccc',
    border: '1px solid #555',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 12,
  },
  yModeBtnFixed: {
    background: '#e65100',
    color: '#fff',
    borderColor: '#e65100',
  },
  channelGroup: {
    display: 'flex',
    gap: 6,
    flexWrap: 'wrap',
  },
  channelBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: 5,
    padding: '3px 10px',
    background: 'transparent',
    color: '#e0e0e0',
    border: '1.5px solid',
    borderRadius: 12,
    cursor: 'pointer',
    fontSize: 12,
    transition: 'opacity 0.15s',
  },
  channelDot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    flexShrink: 0,
  },
  clearBtn: {
    marginLeft: 'auto',
    padding: '4px 10px',
    background: '#333',
    color: '#e0e0e0',
    border: '1px solid #555',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 13,
  },
  canvasContainer: {
    flex: 1,
    position: 'relative',
    overflow: 'hidden',
    cursor: 'crosshair',
  },
  canvas: {
    display: 'block',
    width: '100%',
    height: '100%',
  },
  hint: {
    position: 'absolute',
    bottom: 34,
    right: 24,
    fontSize: 10,
    color: '#555',
    pointerEvents: 'none',
    userSelect: 'none',
  },
};
