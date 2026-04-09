import { useState } from 'react';
import { useBle } from './hooks/useBle';
import { TerminalPage } from './pages/TerminalPage';
import { PlotterPage } from './pages/PlotterPage';

type Tab = 'terminal' | 'plotter';

function App() {
  const [tab, setTab] = useState<Tab>('terminal');
  const {
    connected, deviceName, isConnecting, error,
    connect, disconnect,
    messages, clearTerminal, sendText,
    channels, clearPlot, toggleChannel,
    isSupported,
  } = useBle();

  return (
    <div style={styles.root}>
      <header style={styles.header}>
        <div style={styles.headerLeft}>
          <span style={styles.appTitle}>EasyBLETerm</span>
          <div style={styles.statusBadge}>
            <span style={{
              ...styles.statusDot,
              background: connected ? '#4caf50' : isConnecting ? '#ffa726' : '#666',
            }} />
            <span style={styles.statusText}>
              {connected ? deviceName || '接続中' : isConnecting ? 'スキャン中...' : '未接続'}
            </span>
          </div>
        </div>
        <div style={styles.headerRight}>
          {!isSupported && (
            <span style={styles.unsupportedBadge}>⚠ Web BLE 非対応ブラウザ</span>
          )}
          {error && (
            <span style={styles.errorBadge} title={error}>⚠ エラー</span>
          )}
          {connected ? (
            <button onClick={disconnect} style={styles.disconnectBtn}>切断</button>
          ) : (
            <button
              onClick={connect}
              disabled={!isSupported || isConnecting}
              style={styles.connectBtn}
            >
              {isConnecting ? '接続中...' : 'BLE 接続'}
            </button>
          )}
        </div>
      </header>

      <div style={styles.tabBar}>
        <button
          onClick={() => setTab('terminal')}
          style={{ ...styles.tab, ...(tab === 'terminal' ? styles.tabActive : {}) }}
        >
          ⌨ ターミナル
        </button>
        <button
          onClick={() => setTab('plotter')}
          style={{ ...styles.tab, ...(tab === 'plotter' ? styles.tabActive : {}) }}
        >
          📈 プロッター
        </button>
      </div>

      <main style={styles.main}>
        {tab === 'terminal' ? (
          <TerminalPage
            messages={messages}
            connected={connected}
            onSend={sendText}
            onClear={clearTerminal}
          />
        ) : (
          <PlotterPage
            channels={channels}
            onToggleChannel={toggleChannel}
            onClear={clearPlot}
          />
        )}
      </main>

      {!isSupported && (
        <div style={styles.overlay}>
          <div style={styles.overlayCard}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>🔵</div>
            <h2 style={{ fontSize: 20, fontWeight: 'bold', marginBottom: 16, color: '#e0e0e0' }}>
              Web Bluetooth API 非対応
            </h2>
            <p style={{ fontSize: 14, color: '#aaa', lineHeight: 1.7, marginBottom: 8 }}>
              このアプリは <strong>Google Chrome</strong> または <strong>Microsoft Edge</strong> が必要です。
            </p>
            <p style={{ fontSize: 14, color: '#aaa', lineHeight: 1.7 }}>
              また HTTPS または localhost 環境が必要です。
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    display: 'flex',
    flexDirection: 'column',
    height: '100dvh',
    background: '#1a1a1a',
    color: '#e0e0e0',
    fontFamily: 'system-ui, -apple-system, sans-serif',
    overflow: 'hidden',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '8px 16px',
    background: '#212121',
    borderBottom: '1px solid #333',
    flexShrink: 0,
    gap: 12,
  },
  headerLeft: { display: 'flex', alignItems: 'center', gap: 16, minWidth: 0 },
  appTitle: { fontWeight: 'bold', fontSize: 16, color: '#4fc3f7', whiteSpace: 'nowrap' },
  statusBadge: {
    display: 'flex', alignItems: 'center', gap: 6,
    padding: '3px 10px', background: '#2a2a2a',
    borderRadius: 12, border: '1px solid #444', minWidth: 100,
  },
  statusDot: { width: 8, height: 8, borderRadius: '50%', flexShrink: 0 },
  statusText: { fontSize: 13, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 200 },
  headerRight: { display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 },
  connectBtn: {
    padding: '6px 18px', background: '#4fc3f7', color: '#000',
    border: 'none', borderRadius: 6, cursor: 'pointer', fontWeight: 'bold', fontSize: 13,
  },
  disconnectBtn: {
    padding: '6px 18px', background: '#333', color: '#e0e0e0',
    border: '1px solid #555', borderRadius: 6, cursor: 'pointer', fontSize: 13,
  },
  unsupportedBadge: {
    fontSize: 12, color: '#ffa726', background: '#2a2000',
    padding: '3px 8px', borderRadius: 4, border: '1px solid #ffa72644',
  },
  errorBadge: {
    fontSize: 12, color: '#ef5350', background: '#2a0000',
    padding: '3px 8px', borderRadius: 4, border: '1px solid #ef535044', cursor: 'help',
  },
  tabBar: { display: 'flex', background: '#1e1e1e', borderBottom: '1px solid #333', flexShrink: 0 },
  tab: {
    padding: '10px 24px', background: 'transparent', color: '#888',
    border: 'none', borderBottom: '2px solid transparent',
    cursor: 'pointer', fontSize: 13, fontWeight: 500,
  },
  tabActive: { color: '#4fc3f7', borderBottomColor: '#4fc3f7' },
  main: { flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' },
  overlay: {
    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100,
  },
  overlayCard: {
    background: '#252525', borderRadius: 12, padding: '40px 48px',
    maxWidth: 480, textAlign: 'center', border: '1px solid #444',
  },
};

export default App;
