# EasyArduinoBleTerm (Web)

React + TypeScript + Vite を使用した EasyArduinoBleTerm の Web 版です。

## 動作環境
- Web Bluetooth API に対応したブラウザ（Chrome, Edge）
- HTTPS または localhost 環境

## 開発
```bash
pnpm install
pnpm dev
```

## ビルド
```bash
pnpm build
```

生成された `dist` ディレクトリを静的ホスティングサービスにデプロイしてください。
GitHub Actions で `main` ブランチにプッシュされると自動的に GitHub Pages にデプロイされます。
