// ターミナルメッセージ
export interface TerminalMessage {
  id: number;
  text: string;
  timestamp: Date;
}

// プロットデータポイント
export interface PlotPoint {
  time: number; // 受信からの経過秒
  value: number;
}

// チャンネル情報
export interface PlotChannel {
  index: number;
  label: string;
  color: string;
  visible: boolean;
  data: PlotPoint[];
}

// BLE接続状態
export type BleStatus = 'disconnected' | 'scanning' | 'connecting' | 'connected' | 'error';

// 縦軸モード
export type YAxisMode = 'auto' | 'fixed';

// 横軸プリセット（秒）
export const TIME_PRESETS = [0.1, 1, 10] as const;
export type TimePreset = typeof TIME_PRESETS[number];

// チャンネルカラーパレット
export const CHANNEL_COLORS = [
  '#4fc3f7', // 水色
  '#ef5350', // 赤
  '#66bb6a', // 緑
  '#ffa726', // オレンジ
  '#ab47bc', // 紫
] as const;
