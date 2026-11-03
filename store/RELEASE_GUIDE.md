# Google Play Store リリースガイド

## applicationId
`app.voxna.android`（namespace = applicationId）

- CI は `flutter create` で `android/` を毎回作り直し、`com.voxna.zero_app` を `app.voxna.android` に置き換える（`.github/workflows/build-apk.yml`）。
- MainActivity の移動・package 宣言・Manifest の完全修飾名の 3 点は CI が行う。変更するときは `908-plan/CLAUDE.md` の「CI 変更時の必須チェック」に従う。

## リリース前にやること（手動作業）

### 1. Firebase Console でパッケージ名を更新
1. https://console.firebase.google.com/ → zero-app-d63df
2. プロジェクト設定 → アプリを追加 → Android
3. パッケージ名: `app.voxna.android`
4. 新しい `google-services.json` をダウンロード
5. プロジェクトルートの `google-services.json` を差し替え

### 2. 署名方式: アップロード鍵 + Google Play App Signing
- アプリの署名鍵は Play Console（Play App Signing）が管理する。CI は**アップロード鍵**で AAB に署名する。
- アップロード鍵は GitHub Secrets に置く（リポジトリには入れない）:
  - `UPLOAD_KEYSTORE`: アップロード鍵の `.jks` を base64 にしたもの
  - `KEYSTORE_STORE_PASSWORD` / `KEYSTORE_KEY_PASSWORD`: そのパスワード
  - 鍵の別名（alias）は `upload`（CI が `android/key.properties` を書き出す）
- アップロード鍵を失くしたときは Play Console の「アップロード鍵のリセット」を申請する（署名鍵は Google 側にあるので、アプリは引き続き更新できる）。

### 3. Google Play Console アカウント作成
1. https://play.google.com/console/ で $25 を支払い
2. 個人アカウントを選択
3. 本人確認（身分証明書の提出）
4. デベロッパー名を設定（法人名やブランド名も可）
5. 審査通過を待つ（数日）

### 4. リリースAABをビルド
GitHub Actions → "Build Android" → "Run workflow" ボタンをクリック。
`release` ジョブ（`workflow_dispatch` のときだけ動く）がアップロード鍵で署名した AAB をビルドし、Artifacts（`voxna-release-aab`）にアップロードされる。
version は `pubspec.yaml` の `version:`（例 `1.2.0+9`）。versionCode は毎回上げる。

### 5. Play Store にアップロード
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
- 「手放す」の記録・対話の履歴・「手放す」の設定: 端末内のみ（外部送信なし）。対話は端末内の定型応答で AI は使わない。読み上げは端末の TTS エンジン。→ 「収集」の申告は変わらない
