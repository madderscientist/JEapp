// 主要服务于img的src
class MdContext {
  /// when true, inlineImages will be useless
  final bool autoRef;

  /// referred to when autoImages is false
  final bool inlineImages;
  final bool inlineLinks;

  /// when true, img link will be turned into base64
  final bool localImages;

  MdContext({
    this.autoRef = true,
    this.inlineImages = true,
    this.inlineLinks = true,
    this.localImages = false,
  });

  /// storage for image and link references
  final ref = <String, String>{};

  String references() =>
      ref.entries.map((e) => '[${e.key}]: ${e.value}').join('\n').trim();

  int _id = 1;
  String nextId() => 'id${_id++}';
}
