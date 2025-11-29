import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class _CameraData {
  final List<Uint8List> planes;
  final int width;
  final int height;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;
  final int sensorOrientation;
  final List<int> boundingBox;

  _CameraData({
    required this.planes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.bytesPerPixel,
    required this.sensorOrientation,
    required this.boundingBox,
  });
}

class ImageUtils {

  static Future<Float32List?> processCameraImageInIsolate(
      CameraImage cameraImage,
      int sensorOrientation,
      List<int> boundingBox,
      ) async {
    final planesCopy = cameraImage.planes.map((p) => Uint8List.fromList(p.bytes)).toList();

    final data = _CameraData(
      planes: planesCopy,
      width: cameraImage.width,
      height: cameraImage.height,
      bytesPerRow: cameraImage.planes.map((p) => p.bytesPerRow).toList(),
      bytesPerPixel: cameraImage.planes.map((p) => p.bytesPerPixel).toList(),
      sensorOrientation: sensorOrientation,
      boundingBox: boundingBox,
    );

    return compute(_processInIsolate, data);
  }

  static Float32List? _processInIsolate(_CameraData data) {
    try {
      img.Image? image = _convertYUV420ToImage(data);
      if (image == null) return null;

      image = img.copyRotate(image, angle: data.sensorOrientation);

      int safeLeft = data.boundingBox[0].clamp(0, image.width - 1);
      int safeTop = data.boundingBox[1].clamp(0, image.height - 1);
      int safeWidth = data.boundingBox[2];
      int safeHeight = data.boundingBox[3];

      if (safeLeft + safeWidth > image.width) safeWidth = image.width - safeLeft;
      if (safeTop + safeHeight > image.height) safeHeight = image.height - safeTop;

      if (safeWidth < 10 || safeHeight < 10) return null;

      img.Image faceCrop = img.copyCrop(image, x: safeLeft, y: safeTop, width: safeWidth, height: safeHeight);
      img.Image resized = img.copyResize(faceCrop, width: 224, height: 224);

      var floatList = Float32List(1 * 224 * 224 * 3);
      var buffer = Float32List.view(floatList.buffer);
      int pixelIndex = 0;

      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          var pixel = resized.getPixel(x, y);
          buffer[pixelIndex++] = pixel.r / 255.0;
          buffer[pixelIndex++] = pixel.g / 255.0;
          buffer[pixelIndex++] = pixel.b / 255.0;
        }
      }

      return floatList;
    } catch (e) {
      return null;
    }
  }

  static img.Image? _convertYUV420ToImage(_CameraData data) {
    try {
      final width = data.width;
      final height = data.height;
      var image = img.Image(width: width, height: height);

      final yPlane = data.planes[0];
      final uPlane = data.planes[1];
      final vPlane = data.planes[2];

      final uvRowStride = data.bytesPerRow[1];
      final uvPixelStride = data.bytesPerPixel[1] ?? 1;

      for (int h = 0; h < height; h++) {
        final int uvRowIndex = (h >> 1) * uvRowStride;
        final int yRowIndex = h * width;

        for (int w = 0; w < width; w++) {
          final int uvIndex = uvRowIndex + (w >> 1) * uvPixelStride;
          final int index = yRowIndex + w;

          if (index >= yPlane.length) continue;
          final y = yPlane[index];

          if (uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;
          final u = uPlane[uvIndex];
          final v = vPlane[uvIndex];

          int r = (y + 1.370705 * (v - 128)).toInt();
          int g = (y - 0.337633 * (u - 128) - 0.698001 * (v - 128)).toInt();
          int b = (y + 1.732446 * (u - 128)).toInt();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          image.setPixelRgb(w, h, r, g, b);
        }
      }
      return image;
    } catch (e) {
      return null;
    }
  }
}