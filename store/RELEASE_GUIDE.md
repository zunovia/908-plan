# Google Play Store リリースガイド

## applicationId
`com.voxna.app`

## リリース前にやること（手動作業）

### 1. Firebase Console でパッケージ名を更新
1. https://console.firebase.google.com/ → zero-app-d63df
2. プロジェクト設定 → アプリを追加 → Android
3. パッケージ名: `com.voxna.app`
4. 新しい `google-services.json` をダウンロード
5. プロジェクトルートの `google-services.json` を差し替え

### 2. 署名方式: Google Play App Signing（自動）
- キーストアの自前管理は不要
- 初回AABアップロード時にPlay Consoleが自動で署名鍵を生成・管理
- GitHub Secretsの設定も不要
- CIではdebug署名のAABをビルドし、Play Console側で再署名される

### 4. Google Play Console アカウント作成
1. https://play.google.com/console/ で $25 を支払い
2. 個人アカウントを選択
3. 本人確認（身分証明書の提出）
4. デベロッパー名を設定（法人名やブランド名も可）
5. 審査通過を待つ（数日）

### 5. リリースAABをビルド
GitHub Actions → "Build Android" → "Run workflow" ボタンをクリック。
`release` ジョブがAABをビルドし、Artifactsにアップロードされる。

### 6. Play Store にアップロード
1. Play Console → アプリを作成
2. アプリ名: Voxna
3. カテゴリ: 健康＆フィットネス or ライフスタイル
4. `store/metadata/` の内容をストア掲載情報に入力
5. スクリーンショットをアップロード（`store/screenshots/` に配置予定）
6. AABをアップロード → 内部テスト → 製品版リリース

## スクリーンショット要件
- 最低2枚、最大8枚
- サイズ: 16:9 または 9:16
- 推奨解像度: 1080x1920 px（縦）
- フィーチャーグラフィック: 1024x500 px

## コンテンツレーティング
- IARC質問票に回答が必要
- Voxnaは暴力/性的コンテンツなし → 「全年齢」になるはず

## データセーフティ
Play Console で以下を申告:
- 音声データ: 収集するが端末内のみ（サーバー送信なし）
- アカウントデータ: Firebase Anonymous Auth（オプションでGoogle/Apple）
- 暗号化: はい（SecureStorage）
- データ削除: アプリ内から可能
