import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toastification/toastification.dart';

enum ImageType { local, network, base64 }

/// 图片处理工具类
class ImageUtils {
  ImageUtils._();

  static ImageType judgeImageType(String src) {
    if (src.startsWith('http')) {
      return ImageType.network;
    } else if (src.startsWith('data:image')) {
      return ImageType.base64;
    } else {
      return ImageType.local;
    }
  }

  static ImageProvider getImageProvider(String src) {
    switch (judgeImageType(src)) {
      case ImageType.network:
        return NetworkImage(src);
      case ImageType.local:
        return AssetImage(src);
      case ImageType.base64:
        return MemoryImage(base64Decode(src.substring(src.indexOf(',') + 1)));
    }
  }

  /// 根据图片路径获取图片的字节数据
  static Future<Uint8List> getImageBytesFromSrc(String src) async {
    switch (judgeImageType(src)) {
      case ImageType.network:
        final response = await http.get(Uri.parse(src));
        if (response.statusCode != 200) {
          throw Exception('下载图片失败: ${response.statusCode}');
        }
        return response.bodyBytes;
      case ImageType.local:
        final byteData = await rootBundle.load(src);
        return byteData.buffer.asUint8List();
      case ImageType.base64:
        final base64Data = src.substring(src.indexOf(',') + 1);
        return base64Decode(base64Data);
    }
  }

  /// 异步加载图片，返回图片原始数据
  static Future<ui.Image> loadUIImage(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final image = await completer.future;
    return image;
  }

  /// 将指定路径（网络或本地资源）的图片保存到相册
  /// 返回一个 Map，包含 `isSuccess` (bool) 和 `message` (String)
  static Future<Map<String, dynamic>> saveImageToGallery({
    String? src,
    ui.Image? image,
    String? fileName,
  }) async {
    // 1. 请求权限
    var status = await Permission.storage.request();
    if (!status.isGranted) throw Exception('没有存储权限，请在设置中开启权限');

    try {
      // 2. 获取图片数据
      late final Uint8List imageBytes;
      if (image != null) {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw Exception('无法将图片转换为字节数据');
        }
        imageBytes = byteData.buffer.asUint8List();
      } else if (src != null) {
        imageBytes = await getImageBytesFromSrc(src);
      } else {
        throw Exception('必须提供图片路径或 ui.Image 对象');
      }

      // 3. 保存图片
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        name: fileName,
      );

      if (result['isSuccess']) {
        return {
          'isSuccess': true,
          'message': result['filePath'] ?? '图片已保存到相册',
          'title': '保存成功',
        };
      } else {
        throw Exception(result['errorMessage'] ?? '保存失败，未知错误');
      }
    } catch (e) {
      return {'isSuccess': false, 'message': e.toString(), 'title': '保存失败'};
    }
  }

  /// {"isSuccess": bool?, "message": String?, "title": String?}
  static void uiResult(Map<String, dynamic> result, BuildContext context) {
    var type = result['isSuccess'];
    var title = result['title'];
    var message = result['message'];
    if (type == true) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flatColored,
        title: title == null ? null : Text(title),
        description: message == null ? null : Text(message),
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12.0),
        showProgressBar: false,
        dragToClose: true,
        applyBlurEffect: true,
      );
    } else {
      toastification.show(
        context: context,
        type: type == null ? ToastificationType.warning : ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: title == null ? null : Text(title),
        description: message == null ? null : Text(message),
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(12.0),
        showProgressBar: true,
        dragToClose: true,
        applyBlurEffect: true,
      );
    }
  }
}

/// 图片预览详情页
class FullScreenImageViewer extends StatefulWidget {
  final String src;
  final String herotag;

  /// 优先使用传递而来的imageProviderNotifier，其次使用imageProvider，最后使用src加载
  final ValueNotifier<ImageProvider>? imageProviderNotifier;
  final ImageProvider? imageProvider; // 传递provider可以加速
  final void Function(String)? onChange; // 修改图片的回调
  const FullScreenImageViewer({
    super.key,
    required this.src,
    this.imageProviderNotifier,
    this.imageProvider,
    String? herotag,
    this.onChange,
  }) : herotag = herotag ?? src;

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  // 一切以imageProviderNotifier为准，而不是widget.src，因为前者可以更改
  late final ValueNotifier<ImageProvider> _imageProviderNotifier;

  @override
  void initState() {
    super.initState();
    if (widget.imageProviderNotifier != null) {
      _imageProviderNotifier = widget.imageProviderNotifier!;
    } else {
      _imageProviderNotifier = ValueNotifier<ImageProvider>(
        widget.imageProvider ?? ImageUtils.getImageProvider(widget.src),
      );
    }
  }

  @override
  void dispose() {
    if (widget.imageProviderNotifier == null) {
      _imageProviderNotifier.dispose();
    }
    super.dispose();
  }

  void _saveImage(BuildContext context, {String? fileName}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final result = await ImageUtils.saveImageToGallery(
      image: await ImageUtils.loadUIImage(_imageProviderNotifier.value),
      fileName: fileName,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ImageUtils.uiResult(result, context);
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final base64Str =
          'data:image/${picked.path.split('.').last};base64,${base64Encode(bytes)}';
      final before = _imageProviderNotifier.value;
      widget.onChange?.call(base64Str);
      if (_imageProviderNotifier.value == before) {
        _imageProviderNotifier.value = MemoryImage(bytes);
      }
    }
  }

  void _convertImage(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    ImageUtils.loadUIImage(_imageProviderNotifier.value)
        .then((uiImage) {
          return uiImage.toByteData(format: ui.ImageByteFormat.png);
        })
        .then((byteData) {
          if (byteData == null) throw Exception('无法转换图片为字节数据');
          final bytes = byteData.buffer.asUint8List();
          final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
          final before = _imageProviderNotifier.value;
          widget.onChange?.call(base64Str);
          if (_imageProviderNotifier.value == before) {
            _imageProviderNotifier.value = MemoryImage(bytes);
          }
          if (!context.mounted) return;
          ImageUtils.uiResult({
            'isSuccess': true,
            'message': 'base64长度: ${base64Str.length}',
            'title': '转换成功',
          }, context);
        })
        .catchError((e) {
          if (!context.mounted) return;
          ImageUtils.uiResult({
            'isSuccess': false,
            'message': e.toString(),
            'title': '转换失败',
          }, context);
        })
        .whenComplete(() {
          if (context.mounted) Navigator.of(context).pop();
        });
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('保存图片'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveImage(context);
                },
              ),
              if (widget.onChange != null)
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('更改图片'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage();
                  },
                ),
              if (widget.onChange != null &&
                  _imageProviderNotifier.value is NetworkImage)
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('内嵌入文档(保存后离线可看,显著增大文件,不推荐)'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _convertImage(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onLongPress: () {
          _showOptions(context);
        },
        child: SizedBox.expand(
          child: InteractiveViewer(
            panEnabled: false,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: widget.herotag,
              child: ValueListenableBuilder<ImageProvider>(
                valueListenable: _imageProviderNotifier,
                builder: (context, provider, _) {
                  return Image(image: provider, gaplessPlayback: true);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
