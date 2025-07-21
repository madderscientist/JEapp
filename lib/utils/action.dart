import 'package:url_launcher/url_launcher.dart';
export 'package:url_launcher/url_launcher.dart' show LaunchMode;

Future<bool> launchUrlWrap(String url, [LaunchMode mode = LaunchMode.externalApplication]) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: mode);
  }
  throw Exception('Could not launch $url');
}


Future<void> openFolder(String path) async {
  // 安卓似乎不让打开 file:///storage/emulated/0/Android/data/com.madderscientist.je/files/scores
  final Uri uri = Uri.file(path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
