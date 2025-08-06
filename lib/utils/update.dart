import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:toastification/toastification.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'action.dart';

class ReleaseInfo {
  final String version;
  final String htmlUrl;

  ReleaseInfo({required this.version, required this.htmlUrl});

  void openReleasePage() {
    launchUrlWrap(htmlUrl);
  }

  static Future<ReleaseInfo?> getLatestRelease() async {
    const url =
        'https://api.github.com/repos/madderscientist/JEapp/releases/latest';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final Map<String, dynamic> data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );
    String? tagName = data['tag_name'] as String?;
    String? htmlUrl = data['html_url'] as String?;
    if (tagName == null || htmlUrl == null) return null;
    // 规定要以'v'开头
    if (tagName.startsWith('v') || tagName.startsWith('V')) {
      tagName = tagName.replaceFirst(RegExp(r'^[^0-9]+'), '');
    }
    if (tagName.isEmpty) return null; // 确保tagName不为空
    return ReleaseInfo(version: tagName, htmlUrl: htmlUrl);
  }
}

void appUpdateCheck(BuildContext context, {bool secretly = false}) async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String currentVersion = packageInfo.version;

  ReleaseInfo? latestRelease = await ReleaseInfo.getLatestRelease();

  if (!context.mounted) return;
  if (latestRelease == null) {
    if (secretly) return;
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: const Text('检查更新失败'),
      description: Text('无法获取最新版本信息\n当前版本: $currentVersion'),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: false,
      dragToClose: true,
      applyBlurEffect: true,
    );
    return;
  }

  if (latestRelease.version == currentVersion) {
    if (secretly) return;
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      title: const Text('已是最新版本'),
      description: Text('当前版本: $currentVersion'),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: false,
      dragToClose: true,
      applyBlurEffect: true,
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('发现新版本'),
      content: Text('当前版本: $currentVersion\n最新版本: ${latestRelease.version}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            latestRelease.openReleasePage();
          },
          child: const Text('浏览器中更新'),
        ),
      ],
    ),
  );
}
