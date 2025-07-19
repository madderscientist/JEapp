import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

export 'dart:io' show File, Directory, FileSystemEntity;

class FileUtils {
  /// 路径 按照“用户可见”划分
  static Future<String> get _documentPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String> get _externalPath async {
    // 保存到 /storage/emulated/0/Android/data/包名/ 仅Android可用
    final directory = await getExternalStorageDirectory();
    return directory?.path ?? '';
  }

  static Future<String> get publicPath async {
    if (Platform.isIOS) return await _documentPath;
    final path = await _externalPath;
    return path.isNotEmpty ? path : await _documentPath;
  }

  static Future<String> get privatePath => _documentPath;

  /// 读取文件夹，返回文件列表
  static Future<List<File>> listFiles(
    String folder, [
    bool private = false,
    String extension = '.md',
  ]) async {
    final path = private ? await privatePath : await publicPath;
    final dir = Directory('$path/$folder');
    if (await dir.exists()) {
      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith(extension))
          .toList();
    }
    return [];
  }

  /// 获取文件句柄 filename前不要加斜杠
  static Future<File> _file(String filename, [bool private = false]) async {
    final path = private ? await privatePath : await publicPath;
    return File('$path/$filename');
  }

  /// 文本文件读写
  static Future<String> readText(
    String filename, [
    bool private = false,
  ]) async {
    try {
      final file = await _file(filename);
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        throw FileSystemException('File not found', file.path);
      }
    } catch (e) {
      return '';
    }
  }

  static Future<File> writeText(
    String filename,
    String contents, [
    bool private = false,
  ]) async {
    final file = await _file(filename);
    // 确保目录存在
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  static Future<void> deleteFile(
    String filename, [
    bool private = false,
  ]) async {
    final file = await _file(filename, private);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
