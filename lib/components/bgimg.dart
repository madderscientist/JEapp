import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 背景图片组件
/// 接收 ui.Image，图片保持比例，宽度撑满父组件
/// 如果图片高度大于屏幕高度，则不创建遮罩层【未实现，没必要】
/// 如果图片高度小于屏幕高度，则创建一个遮罩层，高度为背景图片的0.35，从背景色到透明
/// 当上滑浏览下面内容时，图片随位置而淡化。
/// 当下滑时，图片略微中心放大。【给home实现】
/// 当更改图片内容（被动修改）时，先后两个widget的样子做淡入淡出
class BgImage extends StatelessWidget {
  final ui.Image? image; // 用rawImage可以获取宽高，计算遮罩的位置(虽然并未使用) 但如果要保存随机图像API的图像，不能再次get，因为会随机，必须要先保存
  final double opacity;

  const BgImage({super.key, this.image, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final displayWidth = size.width;
    final displayHeight = image == null
        ? displayWidth
        : (displayWidth / image!.width * image!.height);

    return Opacity(
      opacity: opacity,
      child: AnimatedSize(
        // 解决图片大小不一的切换动画
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
        child: AnimatedSwitcher(
          // 解决内容不一样的切换动画
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: ShaderMask(
            key: ValueKey(image),
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.transparent],
              stops: [0.65, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: RawImage(
              image: image,
              width: displayWidth,
              height: displayHeight,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
    );
  }
}