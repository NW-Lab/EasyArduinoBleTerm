import { useState, useEffect, useCallback, useRef } from 'react';
import { bleService } from '../services/BleService';
import type { TerminalMessage, PlotChannel } from '../types';
import { CHANNEL_COLORS } from '../types';

const MAX_MESSAGES = 2000;
const MAX_PLOT_POINTS = 5000; // チャンネルあたりの最大保持ポイント数

export function useBle() {
  const [connected, setConnected] = useState(false);
  const [deviceName, setDeviceName] = useState('');
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // ターミナル
  const [messages, setMessages] = useState<TerminalMessage[]>([]);
  const messageIdRef = useRef(0);
  const pendingMessagesRef = useRef<TerminalMessage[]>([]);
  const terminalFlushTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // プロッター
  const [channels, setChannels] = useState<PlotChannel[]>([]);
  const channelsRef = useRef<PlotChannel[]>([]);
  const startTimeRef = useRef<number | null>(null);
  const plotFlushTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const pendingPlotRef = useRef<{ chIdx: number; time: number; value: number }[]>([]);

  // データ受信ハンドラ（高頻度で呼ばれる）
  const handleData = useCallback((line: string, timestamp: Date) => {
    // ターミナル用バッファー
    const msg: TerminalMessage = {
      id: ++messageIdRef.current,
      text: line,
      timestamp,
    };
    pendingMessagesRef.current.push(msg);

    // プロッター用: カンマ区切り解析
    const parts = line.split(',').map(s => parseFloat(s.trim()));
    if (parts.length > 0 && parts.every(v => !isNaN(v))) {
      if (startTimeRef.current === null) {
        startTimeRef.current = timestamp.getTime();
      }
      const elapsed = (timestamp.getTime() - startTimeRef.current) / 1000;
      parts.forEach((value, chIdx) => {
        if (chIdx < 5) {
          pendingPlotRef.current.push({ chIdx, time: elapsed, value });
        }
      });
    }
  }, []);

  // ターミナル 20fps フラッシュ
  useEffect(() => {
    terminalFlushTimerRef.current = setInterval(() => {
      if (pendingMessagesRef.current.length === 0) return;
      const pending = pendingMessagesRef.current.splice(0);
      setMessages(prev => {
        const next = [...prev, ...pending];
        return next.length > MAX_MESSAGES ? next.slice(next.length - MAX_MESSAGES) : next;
      });
    }, 50);
    return () => {
      if (terminalFlushTimerRef.current) clearInterval(terminalFlushTimerRef.current);
    };
  }, []);

  // プロッター 30fps フラッシュ
  useEffect(() => {
    plotFlushTimerRef.current = setInterval(() => {
      if (pendingPlotRef.current.length === 0) return;
      const pending = pendingPlotRef.current.splice(0);

      // チャンネル数を確認して必要なら拡張
      const maxChIdx = Math.max(...pending.map(p => p.chIdx));
      const currentCount = channelsRef.current.length;
      if (maxChIdx >= currentCount) {
        const newChannels = [...channelsRef.current];
        for (let i = currentCount; i <= maxChIdx; i++) {
          newChannels.push({
            index: i,
            label: `Ch${i + 1}`,
            color: CHANNEL_COLORS[i % CHANNEL_COLORS.length],
            visible: true,
            data: [],
          });
        }
        channelsRef.current = newChannels;
      }

      const updated = channelsRef.current.map(ch => ({ ...ch, data: [...ch.data] }));
      for (const p of pending) {
        updated[p.chIdx].data.push({ time: p.time, value: p.value });
        if (updated[p.chIdx].data.length > MAX_PLOT_POINTS) {
          updated[p.chIdx].data.splice(0, updated[p.chIdx].data.length - MAX_PLOT_POINTS);
        }
      }
      channelsRef.current = updated;
      setChannels([...updated]);
    }, 33);
    return () => {
      if (plotFlushTimerRef.current) clearInterval(plotFlushTimerRef.current);
    };
  }, []);

  // BLEサービスにコールバック登録
  useEffect(() => {
    bleService.onData(handleData);
    bleService.onStatus((conn, name) => {
      setConnected(conn);
      setDeviceName(name);
    });
  }, [handleData]);

  const connect = useCallback(async () => {
    setIsConnecting(true);
    setError(null);
    try {
      await bleService.connect();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      // ユーザーがキャンセルした場合はエラー表示しない
      if (!msg.includes('cancelled') && !msg.includes('User cancelled')) {
        setError(msg);
      }
    } finally {
      setIsConnecting(false);
    }
  }, []);

  const disconnect = useCallback(() => {
    bleService.disconnect();
  }, []);

  const sendText = useCallback(async (text: string) => {
    await bleService.send(text);
  }, []);

  const clearTerminal = useCallback(() => {
    setMessages([]);
    pendingMessagesRef.current = [];
  }, []);

  const clearPlot = useCallback(() => {
    channelsRef.current = [];
    setChannels([]);
    pendingPlotRef.current = [];
    startTimeRef.current = null;
  }, []);

  const toggleChannel = useCallback((index: number) => {
    setChannels(prev => {
      const next = prev.map(ch =>
        ch.index === index ? { ...ch, visible: !ch.visible } : ch
      );
      channelsRef.current = next;
      return next;
    });
  }, []);

  return {
    connected,
    deviceName,
    isConnecting,
    error,
    connect,
    disconnect,
    sendText,
    // ターミナル
    messages,
    clearTerminal,
    // プロッター
    channels,
    clearPlot,
    toggleChannel,
    isSupported: bleService.isSupported(),
  };
}
