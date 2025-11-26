import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  static int _callCount = 0;

  static img.Image? convertCameraImage(CameraImage image) {
    _callCount++;

    try {
      img.Image? result;

      if (_callCount % 100 == 1) {
        print('[ImageUtils] Formato: ${image.format.group} | Planes: ${image.planes.length}');
      }

      if (image.format.group == ImageFormatGroup.yuv420) {
        result = _convertYUV420ToImage(image);
      } else if (image.format.group == ImageFormatGroup.nv21) {
        result = _convertNV21ToImage(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        result = _convertBGRA8888ToImage(image);
      }

      return result;
    } catch (e) {
      print('[ImageUtils] ERROR CRITICO: $e');
      return null;
    }
  }

  static Float32List? processFaceForModel(
      img.Image fullImage,
      int left,
      int top,
      int width,
      int height,
      ) {
    try {
      if (width <= 0 || height <= 0) return null;

      int x = left.clamp(0, fullImage.width - 1);
      int y = top.clamp(0, fullImage.height - 1);
      int w = width;
      int h = height;

      if (x + w > fullImage.width) w = fullImage.width - x;
      if (y + h > fullImage.height) h = fullImage.height - y;

      if (w < 10 || h < 10) return null;

      int padding = (min(w, h) * 0.2).toInt();
      int x1 = max(0, x - padding);
      int y1 = max(0, y - padding);
      int x2 = min(fullImage.width, x + w + padding);
      int y2 = min(fullImage.height, y + h + padding);

      int cropW = x2 - x1;
      int cropH = y2 - y1;

      if (cropW < 10 || cropH < 10) return null;

      img.Image faceCrop = img.copyCrop(
        fullImage,
        x: x1,
        y: y1,
        width: cropW,
        height: cropH,
      );

      img.Image resized = img.copyResize(
        faceCrop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      var floatList = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;

      for (int py = 0; py < 224; py++) {
        for (int px = 0; px < 224; px++) {
          final pixel = resized.getPixel(px, py);
          floatList[pixelIndex++] = pixel.r / 255.0;
          floatList[pixelIndex++] = pixel.g / 255.0;
          floatList[pixelIndex++] = pixel.b / 255.0;
        }
      }

      return floatList;
    } catch (e) {
      print('[ImageUtils] ERROR processFace: $e');
      return null;
    }
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    // Implementación estándar para YUV420 (3 planos)
    final int width = image.width;
    final int height = image.height;
    final img.Image imgBuffer = img.Image(width: width, height: height);

    if (image.planes.length < 3) return imgBuffer;

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        if (yIndex >= yPlane.length || uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;

        final int yValue = yPlane[yIndex];
        final int uValue = uPlane[uvIndex];
        final int vValue = vPlane[uvIndex];

        _yuvToRgb(yValue, uValue, vValue, (r, g, b) {
          imgBuffer.setPixelRgb(x, y, r, g, b);
        });
      }
    }
    return imgBuffer;
  }

  // [CORREGIDO] Soporte universal para NV21 (OPPO/MediaTek + Estándar)
  static img.Image _convertNV21ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgBuffer = img.Image(width: width, height: height);

    Uint8List yPlane;
    Uint8List vuPlane;
    int yRowStride;
    int vuRowStride;
    int vuPixelStride = 2;

    // Detección automática de formato plano vs separado
    if (image.planes.length == 1) {
      // CASO OPPO: Todo en un solo buffer
      final bytes = image.planes[0].bytes;
      int ySize = width * height;
      if (bytes.length < ySize) return imgBuffer;

      yPlane = bytes.sublist(0, ySize);
      // El plano VU empieza justo después de Y
      vuPlane = bytes.sublist(ySize);

      yRowStride = width;
      vuRowStride = width;
    } else {
      // CASO ESTÁNDAR: Planos separados
      yPlane = image.planes[0].bytes;
      vuPlane = image.planes[1].bytes;
      yRowStride = image.planes[0].bytesPerRow;
      vuRowStride = image.planes[1].bytesPerRow;
      if (image.planes[1].bytesPerPixel != null) {
        vuPixelStride = image.planes[1].bytesPerPixel!;
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int vuIndex = (y ~/ 2) * vuRowStride + (x ~/ 2) * vuPixelStride;

        if (yIndex >= yPlane.length) continue;
        // Validación segura para no salirnos del array VU
        if (vuIndex + 1 >= vuPlane.length) continue;

        final int yValue = yPlane[yIndex];
        // En NV21: V primero, luego U
        final int vValue = vuPlane[vuIndex];
        final int uValue = vuPlane[vuIndex + 1];

        _yuvToRgb(yValue, uValue, vValue, (r, g, b) {
          imgBuffer.setPixelRgb(x, y, r, g, b);
        });
      }
    }
    return imgBuffer;
  }

  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static void _yuvToRgb(int y, int u, int v, Function(int r, int g, int b) onColor) {
    int r = (y + 1.370705 * (v - 128)).round().clamp(0, 255);
    int g = (y - 0.337633 * (u - 128) - 0.698001 * (v - 128)).round().clamp(0, 255);
    int b = (y + 1.732446 * (u - 128)).round().clamp(0, 255);
    onColor(r, g, b);
  }
}