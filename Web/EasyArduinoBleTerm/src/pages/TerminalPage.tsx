import React, { useState, useRef, useEffect, useCallback } from 'react';
import type { TerminalMessage } from '../types';

interface Props {
  messages: TerminalMessage[];
  connected: boolean;
  onSend: (text: string) => Promise<void>;
  onClear: () => void;
}

function formatTime(d: Date): string {
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');
  const ms = String(d.getMilliseconds()).padStart(3, '0');
  return `${hh}:${mm}:${ss}.${ms}`;
}

export const TerminalPage: React.FC<Props> = ({ messages, connected, onSend, onClear }) => {
  const [showTimestamp, setShowTimestamp] = useState(true);
  const [autoScroll, setAutoScroll] = useState(true);
  const [inputText, setInputText] = useState('');
  const listRef = useRef<HTMLDivElement>(null);
  const lastCountRef = useRef(0);

  // 自動スクロール
  useEffect(() => {
    if (!autoScroll) return;
    if (messages.length === lastCountRef.current) return;
    lastCountRef.current = messages.length;
    const el = listRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [messages, autoScroll]);

  const handleSend = useCallback(async () => {
    const text = inputText.trim();
    if (!text || !connected) return;
    await onSend(text);
    setInputText('');
  }, [inputText, connected, onSend]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSend();
  }, [handleSend]);

  return (
    <div style={styles.container}>
      {/* ツールバー */}
      <div style={styles.toolbar}>
        <label style={styles.toggleLabel}>
          <input
            type="checkbox"
            checked={showTimestamp}
            onChange={e => setShowTimestamp(e.target.checked)}
            style={styles.checkbox}
          />
          受信日時
        </label>
        <label style={styles.toggleLabel}>
          <input
            type="checkbox"
            checked={autoScroll}
            onChange={e => setAutoScroll(e.target.checked)}
            style={styles.checkbox}
          />
          自動スクロール
        </label>
        <span style={styles.countLabel}>{messages.length} 行</span>
        <button onClick={onClear} style={styles.clearBtn} title="クリア">🗑 クリア</button>
      </div>

      {/* メッセージリスト */}
      <div ref={listRef} style={styles.messageList}>
        {messages.map(msg => (
          <div key={msg.id} style={styles.messageRow}>
            {showTimestamp && (
              <span style={styles.timestamp}>{formatTime(msg.timestamp)}</span>
            )}
            <span style={styles.messageText}>{msg.text}</span>
          </div>
        ))}
      </div>

      {/* 送信エリア */}
      <div style={styles.sendArea}>
        <input
          type="text"
          value={inputText}
          onChange={e => setInputText(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={connected ? 'テキストを入力して Enter で送信' : '未接続'}
          disabled={!connected}
          style={styles.sendInput}
        />
        <button
          onClick={handleSend}
          disabled={!connected || !inputText.trim()}
          style={styles.sendBtn}
        >
          送信
        </button>
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
    fontFamily: "'Courier New', Consolas, monospace",
  },
  toolbar: {
    display: 'flex',
    alignItems: 'center',
    gap: 16,
    padding: '6px 12px',
    background: '#252525',
    borderBottom: '1px solid #333',
    flexShrink: 0,
    flexWrap: 'wrap',
  },
  toggleLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    fontSize: 13,
    cursor: 'pointer',
    userSelect: 'none',
  },
  checkbox: {
    accentColor: '#4fc3f7',
    width: 14,
    height: 14,
  },
  countLabel: {
    fontSize: 12,
    color: '#888',
    marginLeft: 'auto',
  },
  clearBtn: {
    padding: '4px 10px',
    background: '#333',
    color: '#e0e0e0',
    border: '1px solid #555',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 12,
  },
  messageList: {
    flex: 1,
    overflowY: 'auto',
    padding: '4px 8px',
    fontSize: 13,
    lineHeight: 1.6,
  },
  messageRow: {
    display: 'flex',
    gap: 8,
    wordBreak: 'break-all',
  },
  timestamp: {
    color: '#888',
    flexShrink: 0,
    fontSize: 12,
    paddingTop: 1,
  },
  messageText: {
    color: '#e0e0e0',
  },
  sendArea: {
    display: 'flex',
    gap: 8,
    padding: '8px 12px',
    background: '#252525',
    borderTop: '1px solid #333',
    flexShrink: 0,
  },
  sendInput: {
    flex: 1,
    padding: '6px 10px',
    background: '#1a1a1a',
    color: '#e0e0e0',
    border: '1px solid #444',
    borderRadius: 4,
    fontSize: 13,
    fontFamily: "'Courier New', Consolas, monospace",
    outline: 'none',
  },
  sendBtn: {
    padding: '6px 16px',
    background: '#4fc3f7',
    color: '#000',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontWeight: 'bold',
    fontSize: 13,
  },
};
