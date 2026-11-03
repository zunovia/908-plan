// テストから実コンテンツ／フィクスチャを読むための共通ヘルパー（rootBundle ではなく File）。
// 作業ディレクトリは zero_app 直下（flutter test の既定）。

import 'dart:io';

import 'package:zero_app/features/release/data/content_repository.dart';

const String releaseAssetsRoot = 'assets/release';
const String releaseFixturesRoot = 'test/release/fixtures';

File releaseAsset(String lang, String name) => File('$releaseAssetsRoot/$lang/$name');
File releaseCommonAsset(String name) => File('$releaseAssetsRoot/common/$name');
File releaseFixture(String name) => File('$releaseFixturesRoot/$name');

String readUtf8(File f) => f.readAsStringSync();

/// File から読むローダー（無ければ null）。
class FileContentLoader implements ContentAssetLoader {
  const FileContentLoader();

  @override
  Future<String?> load(String path) async {
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync() : null;
  }
}
