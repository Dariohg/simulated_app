import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Convierte un CameraImage (YUV420) a un objeto Image de la librería 'image'.
  static img.Image? convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(image);
      }
      return null;
    } catch (e) {
      debugPrint("Error convirtiendo imagen: $e");
      return null;
    }
  }

  /// Procesa la imagen para el modelo: Recorta la cara y redimensiona.
  static Float32List? processFaceForModel(
      img.Image fullImage,
      int left,
      int top,
      int width,
      int height,
      ) {
    // 1. Validar coordenadas de recorte
    int x = left.clamp(0, fullImage.width - 1);
    int y = top.clamp(0, fullImage.height - 1);
    int w = width;
    int h = height;

    if (x + w > fullImage.width) w = fullImage.width - x;
    if (y + h > fullImage.height) h = fullImage.height - y;

    if (w <= 0 || h <= 0) return null;

    // 2. Recortar cara (como face_detector.crop_face en Python)
    img.Image faceCrop = img.copyCrop(fullImage, x: x, y: y, width: w, height: h);

    // 3. Redimensionar a 224x224 (Input estándar de EfficientNet)
    img.Image resized = img.copyResize(faceCrop, width: 224, height: 224);

    // 4. Normalizar a Float32List [1, 224, 224, 3]
    // Valores entre 0.0 y 1.0 (o estandarización según tu modelo específico)
    var floatList = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(floatList.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 224; i++) {
      for (var j = 0; j < 224; j++) {
        var pixel = resized.getPixel(j, i);
        // Normalización estándar (0-1)
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return floatList;
  }

  // --- Funciones auxiliares de conversión YUV ---
  static img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
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
}