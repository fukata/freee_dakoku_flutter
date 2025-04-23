# freee打刻アプリ (freee_dakoku_flutter)

freeeの勤怠管理システムと連携して、出勤・退勤の打刻を行うクロスプラットフォーム Flutter アプリケーションです。

![アプリアイコン](icon.png)

## 機能

- freee APIを使用した出勤・退勤の打刻
- OAuth2による安全な認証
- 出勤・退勤時間のリマインダー通知
- マルチプラットフォーム対応（Windows, macOS, Linux）
- カスタマイズ可能な勤務時間設定

## スクリーンショット

*スクリーンショットがあれば追加してください*

## 動作環境

- Flutter SDK: ^3.7.2
- Dart: ^3.7.2
- サポートプラットフォーム:
  - Windows
  - macOS
  - Linux

## インストール方法

### 前提条件

- [Flutter](https://flutter.dev/docs/get-started/install) がインストールされていること
- freee APIの開発者アカウントとOAuth2認証情報（Client ID, Client Secret）が必要

### セットアップ手順

1. リポジトリをクローン:
```bash
git clone https://github.com/fukata/freee_dakoku_flutter.git
cd freee_dakoku_flutter
```

2. 依存関係のインストール:
```bash
flutter pub get
```

3. アプリの実行:
```bash
flutter run
```

## 使い方

1. 初回起動時、OAuth設定画面が表示されます
2. freeeで取得したClient IDとClient Secretを入力
3. ログイン画面でfreeeアカウントにログイン
4. メイン画面で出勤・退勤ボタンを使用して打刻

## 設定

アプリ内の設定メニューから以下の設定が可能です:

- **OAuth設定**: freeeアプリのClient IDとClient Secretの設定
- **アプリ設定**: 勤務開始・終了時間の設定、通知の有効/無効

## 主な使用ライブラリ

- `shared_preferences`: アプリ設定の保存
- `oauth2_client`: OAuth2認証の実装
- `http`: HTTPリクエスト
- `flutter_local_notifications`: ローカル通知の実装
- `flutter_secure_storage`: 認証情報の安全な保存
- `window_size`: デスクトッププラットフォームでのウィンドウサイズ制御
- `url_launcher`: ブラウザでのURLオープン
- `flutter_launcher_icons`: アプリアイコンの生成

## 開発者向け情報

### ディレクトリ構成

- `lib/`
  - `main.dart`: アプリのエントリーポイント
  - `screens/`: アプリの各画面
  - `services/`: バックエンドサービスとの連携

### ビルド方法

各プラットフォーム向けのビルド方法:

**Android:**
```bash
flutter build apk
```

**iOS:**
```bash
flutter build ios
```

**デスクトッププラットフォーム:**
```bash
flutter build linux
flutter build windows
flutter build macos
```

## freee API連携について

このアプリはfreee APIを使用して勤怠情報の取得・打刻を行います。連携には以下の設定が必要です:

1. [freee Developer Hub](https://developer.freee.co.jp/)でアプリケーションを登録
2. OAuth2認証情報（Client ID, Client Secret）を取得
3. リダイレクトURIを適切に設定

## ライセンス

*適切なライセンス情報を追加してください*

## 貢献について

プルリクエストは歓迎します。大きな変更を加える場合は、まずIssueを立てて変更内容を議論してください。

## 作者

[fukata](https://github.com/fukata)
