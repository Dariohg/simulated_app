import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class _ProcessRequest {
  final CameraImage cameraImage;
  final int rotation;
  final List<int> bbox;
  _ProcessRequest(this.cameraImage, this.rotation, this.bbox);
}

class ImageUtils {
  // Normalización ImageNet
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static bool _isProcessing = false;

  static Future<Float32List?> processCameraImageInIsolate(
      CameraImage image,
      int rotation,
      List<int> bbox,
      ) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      // Usamos compute para no bloquear el hilo principal
      return await compute(_processInIsolate, _ProcessRequest(image, rotation, bbox));
    } catch (e) {
      debugPrint('[ImageUtils] Error calling compute: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  static Float32List? _processInIsolate(_ProcessRequest request) {
    try {
      img.Image? convertedImage;

      // 1. Estrategia de conversión robusta
      // Algunos dispositivos reportan YUV420 pero entregan 1 plano (NV21/raw)
      // Otros reportan YUV420 y entregan 3 planos (Estándar)

      if (request.cameraImage.format.group == ImageFormatGroup.yuv420 ||
          request.cameraImage.format.group == ImageFormatGroup.nv21) {

        if (request.cameraImage.planes.length == 1) {
          // CASO ESPECIAL: Tu error ocurre aquí. El dispositivo entrega todo en 1 buffer.
          convertedImage = _convertSinglePlaneYUVToImage(request.cameraImage);
        } else {
          // CASO ESTÁNDAR: 3 planos separados
          convertedImage = _convertYUV420ToImage(request.cameraImage);
        }
      } else if (request.cameraImage.format.group == ImageFormatGroup.bgra8888) {
        convertedImage = _convertBGRA8888ToImage(request.cameraImage);
      }

      if (convertedImage == null) {
        // Si falló la conversión, intentamos fallback genérico si hay bytes
        if (request.cameraImage.planes.isNotEmpty) {
          // Último intento: tratar como Grayscale o Raw si coincide el tamaño
          // Por ahora retornamos null para no procesar basura
        }
        return null;
      }

      // 2. Rotar imagen (Corregir orientación del sensor)
      img.Image uprightImage = img.copyRotate(convertedImage, angle: request.rotation);

      // 3. Crop de la cara con validación de límites
      final bbox = request.bbox; // [left, top, width, height]

      // Padding 20%
      int padding = (min(bbox[2], bbox[3]) * 0.2).toInt();

      int x1 = (bbox[0] - padding).clamp(0, uprightImage.width - 1);
      int y1 = (bbox[1] - padding).clamp(0, uprightImage.height - 1);
      int w = (bbox[2] + padding * 2);
      int h = (bbox[3] + padding * 2);

      if (x1 + w > uprightImage.width) w = uprightImage.width - x1;
      if (y1 + h > uprightImage.height) h = uprightImage.height - y1;

      if (w < 10 || h < 10) return null;

      img.Image faceCrop = img.copyCrop(uprightImage, x: x1, y: y1, width: w, height: h);

      // 4. Resize a 224x224 (Entrada del modelo)
      img.Image resized = img.copyResize(
        faceCrop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // 5. Normalización (ImageNet)
      var floatList = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);

          // img.Image v4: pixel.r/g/b ya están normalizados 0-255 o 0-1 dependiendo formato
          // Asumimos formato uint8 estándar de image, dividimos por 255
          double r = pixel.r / 255.0;
          double g = pixel.g / 255.0;
          double b = pixel.b / 255.0;

          floatList[pixelIndex++] = (r - _mean[0]) / _std[0];
          floatList[pixelIndex++] = (g - _mean[1]) / _std[1];
          floatList[pixelIndex++] = (b - _mean[2]) / _std[2];
        }
      }

      return floatList;
    } catch (e) {
      debugPrint('[ImageUtils] Error crítico en procesamiento: $e');
      return null;
    }
  }

  // ===========================================================================
  // CONVERSORES
  // ===========================================================================

  /// CASO ESPECIAL: YUV empaquetado en un solo plano (NV21/YUV420sp)
  /// Soluciona el error "RangeError (length): Invalid value: Only valid value is 0: 1"
  static img.Image _convertSinglePlaneYUVToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final bytes = image.planes[0].bytes;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    // En formato NV21 de 1 plano:
    // Y ocupa los primeros W*H bytes
    // UV empieza inmediatamente después, intercalado
    final int uvOffset = width * height;

    // Verificación de seguridad de tamaño
    if (bytes.length < (width * height * 1.5).toInt()) {
      debugPrint('[ImageUtils] Buffer insuficiente para NV21 Single Plane');
      return imgBuffer; // Retorna negro en vez de crashear
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;

        // UV index (NV21): intercalado V, U
        // Cada bloque 2x2 comparte un valor UV
        final int uvIndex = uvOffset + ((y >> 1) * width) + (x & ~1);

        int yVal = bytes[yIndex];

        // Validar bounds para UV
        if (uvIndex + 1 >= bytes.length) continue;

        int vVal = bytes[uvIndex] - 128;     // V es el primero en NV21 a veces
        int uVal = bytes[uvIndex + 1] - 128; // U es el segundo

        // Conversión YUV -> RGB
        int r = (yVal + (1.370705 * vVal)).round().clamp(0, 255);
        int g = (yVal - (0.337633 * uVal) - (0.698001 * vVal)).round().clamp(0, 255);
        int b = (yVal + (1.732446 * uVal)).round().clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }
    return imgBuffer;
  }

  /// CASO ESTÁNDAR: YUV en 3 planos separados (Y, U, V)
  static img.Image _convertYUV420ToImage(CameraImage image) {
    // Validación extra para evitar el crash si entra aquí por error
    if (image.planes.length < 3) {
      return img.Image(width: image.width, height: image.height);
    }

    final width = image.width;
    final height = image.height;
    final yBytes = image.planes[0].bytes;
    final uBytes = image.planes[1].bytes;
    final vBytes = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        if (yIndex >= yBytes.length || uvIndex >= uBytes.length || uvIndex >= vBytes.length) continue;

        int yVal = yBytes[yIndex];
        int uVal = uBytes[uvIndex] - 128;
        int vVal = vBytes[uvIndex] - 128;

        int r = (yVal + (1.370705 * vVal)).round().clamp(0, 255);
        int g = (yVal - (0.337633 * uVal) - (0.698001 * vVal)).round().clamp(0, 255);
        int b = (yVal + (1.732446 * uVal)).round().clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }
    return imgBuffer;
  }

  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    if (image.planes.isEmpty) return img.Image(width: 1, height: 1);
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }
}