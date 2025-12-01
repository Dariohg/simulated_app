import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  // Constantes de normalización de ImageNet (CRÍTICO para la precisión del modelo)
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static Future<Float32List?> processCameraImageInIsolate(
      CameraImage cameraImage,
      int sensorOrientation,
      List<int> boundingBox,
      ) async {
    try {
      final bytes = _concatenatePlanes(cameraImage.planes);

      final result = await Isolate.run(() {
        return _processImageBytes(
          bytes,
          cameraImage.width,
          cameraImage.height,
          sensorOrientation,
          boundingBox,
        );
      });

      return result;
    } catch (e) {
      return null;
    }
  }

  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = <int>[];
    for (final plane in planes) {
      allBytes.addAll(plane.bytes);
    }
    return Uint8List.fromList(allBytes);
  }

  static Float32List? _processImageBytes(
      Uint8List bytes,
      int width,
      int height,
      int sensorOrientation,
      List<int> boundingBox,
      ) {
    try {
      img.Image? image = img.decodeImage(bytes);
      // Fallback para YUV420 si decodeImage falla
      image ??= _convertYUV420ToImage(bytes, width, height);

      if (image == null) return null;

      // Corregir orientación
      switch (sensorOrientation) {
        case 90:
          image = img.copyRotate(image, angle: 90);
          break;
        case 180:
          image = img.copyRotate(image, angle: 180);
          break;
        case 270:
          image = img.copyRotate(image, angle: 270);
          break;
      }

      // Efecto espejo (cámara frontal)
      image = img.flipHorizontal(image);

      // Recorte seguro del rostro
      final x = boundingBox[0].clamp(0, image.width - 1);
      final y = boundingBox[1].clamp(0, image.height - 1);
      final w = boundingBox[2].clamp(1, image.width - x);
      final h = boundingBox[3].clamp(1, image.height - y);

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

      // Redimensión a 224x224 (entrada estándar del modelo)
      final resized = img.copyResize(
          cropped,
          width: 224,
          height: 224,
          interpolation: img.Interpolation.linear
      );

      // Conversión a Float32 con Normalización Mean/Std
      final float32List = Float32List(224 * 224 * 3);
      int index = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);

          // Normalizar cada canal (RGB) independientemente
          double r = pixel.r / 255.0;
          double g = pixel.g / 255.0;
          double b = pixel.b / 255.0;

          float32List[index++] = (r - _mean[0]) / _std[0];
          float32List[index++] = (g - _mean[1]) / _std[1];
          float32List[index++] = (b - _mean[2]) / _std[2];
        }
      }

      return float32List;
    } catch (e) {
      return null;
    }
  }

  static img.Image? _convertYUV420ToImage(Uint8List bytes, int width, int height) {
    try {
      final image = img.Image(width: width, height: height);
      final ySize = width * height;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          if (yIndex >= ySize) continue;
          final yValue = bytes[yIndex];
          image.setPixelRgb(x, y, yValue, yValue, yValue);
        }
      }
      return image;
    } catch (e) {
      return null;
    }
  }
}