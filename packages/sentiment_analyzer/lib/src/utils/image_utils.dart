import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// DTO para enviar datos al Isolate
class _ProcessRequest {
  final CameraImage cameraImage;
  final int rotation;
  final List<int> bbox; // [left, top, width, height]

  _ProcessRequest(this.cameraImage, this.rotation, this.bbox);
}

class ImageUtils {
  // Normalización ImageNet (EfficientNet)
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static bool _isProcessing = false;

  /// Procesa la imagen de cámara en un hilo separado (Isolate) para no bloquear la UI.
  ///
  /// [image]: La imagen cruda de la cámara (YUV420/NV21).
  /// [rotation]: La rotación del sensor (ej. 270 para cámara frontal en muchos Android).
  /// [bbox]: Rectángulo de la cara [left, top, width, height].
  static Future<Float32List?> processCameraImageInIsolate(
      CameraImage image,
      int rotation,
      List<int> bbox,
      ) async {
    // Evitar encolar demasiadas tareas si una ya está corriendo
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      // Ejecutar en background
      final result = await compute(
        _processInIsolate,
        _ProcessRequest(image, rotation, bbox),
      );
      return result;
    } catch (e) {
      debugPrint('[ImageUtils] Error en Isolate: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Función estática que corre en el Isolate
  static Float32List? _processInIsolate(_ProcessRequest request) {
    try {
      // 1. Convertir YUV/BGRA a img.Image RGB
      img.Image? convertedImage;

      // Nota: CameraImage no es fácil de pasar entre isolates por sus punteros nativos en algunas versiones.
      // Si esto falla, se debe copiar los bytes antes de enviar.
      // Asumimos que en versiones recientes de Flutter esto es manejable o copiamos bytes críticos.

      if (request.cameraImage.format.group == ImageFormatGroup.yuv420 ||
          request.cameraImage.format.group == ImageFormatGroup.nv21) {
        convertedImage = _convertYUV420ToImage(request.cameraImage);
      } else if (request.cameraImage.format.group == ImageFormatGroup.bgra8888) {
        convertedImage = _convertBGRA8888ToImage(request.cameraImage);
      }

      if (convertedImage == null) return null;

      // 2. Rotar la imagen para que esté "derecha" (Upright)
      // Las cámaras frontales suelen venir rotadas 270 grados (sensor landscape).
      // ML Kit devuelve coordenadas basadas en la imagen rotada correctamente.
      // Por ende, debemos rotar la imagen RAW para que coincida con las coordenadas.
      img.Image uprightImage = img.copyRotate(convertedImage, angle: request.rotation);

      // 3. Recortar la cara con padding y chequeo de límites
      final bbox = request.bbox;
      int left = bbox[0];
      int top = bbox[1];
      int width = bbox[2];
      int height = bbox[3];

      // Padding del 20% para capturar contexto (pelo, barbilla)
      int padding = (min(width, height) * 0.2).toInt();
      int x1 = (left - padding).clamp(0, uprightImage.width);
      int y1 = (top - padding).clamp(0, uprightImage.height);
      int x2 = (left + width + padding).clamp(0, uprightImage.width);
      int y2 = (top + height + padding).clamp(0, uprightImage.height);

      int cropW = x2 - x1;
      int cropH = y2 - y1;

      if (cropW < 20 || cropH < 20) return null;

      img.Image faceCrop = img.copyCrop(
        uprightImage,
        x: x1,
        y: y1,
        width: cropW,
        height: cropH,
      );

      // 4. Redimensionar a 224x224 (Input del Modelo)
      img.Image resized = img.copyResize(
        faceCrop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // 5. Normalizar a Float32List (ImageNet stats)
      var floatList = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);

          // Normalización: (Valor/255 - Mean) / Std
          floatList[pixelIndex++] = ((pixel.r / 255.0) - _mean[0]) / _std[0];
          floatList[pixelIndex++] = ((pixel.g / 255.0) - _mean[1]) / _std[1];
          floatList[pixelIndex++] = ((pixel.b / 255.0) - _mean[2]) / _std[2];
        }
      }

      return floatList;
    } catch (e) {
      // En isolate print puede no salir, pero intentamos
      debugPrint('[ImageUtils-Isolate] Error: $e');
      return null;
    }
  }

  // ===========================================================================
  // CONVERSORES (Optimizados para ejecutarse dentro del Isolate)
  // ===========================================================================

  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    // Acceso directo a bytes para velocidad
    final yBytes = image.planes[0].bytes;
    final uBytes = image.planes[1].bytes;
    final vBytes = image.planes[2].bytes;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * image.planes[0].bytesPerRow + x;
        final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * (uvPixelStride ?? 1);

        if (yIndex >= yBytes.length || uvIndex >= uBytes.length || uvIndex >= vBytes.length) continue;

        // Conversión YUV a RGB optimizada con enteros
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
}