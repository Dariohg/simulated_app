import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Utilidades de procesamiento de imagen para el modelo de emociones.
///
/// IMPORTANTE: El modelo HSEmotion (EfficientNet-B0) espera:
/// - Tamaño de entrada: 224x224x3
/// - Formato de color: RGB
/// - Normalización: ImageNet (mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
/// - Rango de entrada normalizado: aproximadamente [-2.1, 2.6]
class ImageUtils {
  // Constantes de normalización ImageNet (usadas por EfficientNet/HSEmotion)
  static const List<double> _imagenetMean = [0.485, 0.456, 0.406]; // RGB
  static const List<double> _imagenetStd = [0.229, 0.224, 0.225];  // RGB

  static int _callCount = 0;
  static int _lastLogFrame = 0;

  /// Convierte CameraImage a img.Image
  /// Soporta múltiples formatos de cámara (YUV420, NV21, BGRA8888)
  static img.Image? convertCameraImage(CameraImage image) {
    _callCount++;

    try {
      img.Image? result;

      // Log cada 100 frames para debug
      if (_callCount - _lastLogFrame >= 100) {
        _lastLogFrame = _callCount;
        print('[ImageUtils] Frame $_callCount | Formato: ${image.format.group} | '
            'Tamaño: ${image.width}x${image.height} | Planes: ${image.planes.length}');
      }

      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          result = _convertYUV420ToImage(image);
          break;
        case ImageFormatGroup.nv21:
          result = _convertNV21ToImage(image);
          break;
        case ImageFormatGroup.bgra8888:
          result = _convertBGRA8888ToImage(image);
          break;
        default:
          print('[ImageUtils] Formato no soportado: ${image.format.group}');
          return null;
      }

      return result;
    } catch (e, stackTrace) {
      print('[ImageUtils] ERROR convertCameraImage: $e');
      print('[ImageUtils] StackTrace: $stackTrace');
      return null;
    }
  }

  /// Procesa la región del rostro para el modelo de emociones.
  ///
  /// Pasos:
  /// 1. Recorta la región del rostro con padding
  /// 2. Redimensiona a 224x224
  /// 3. Convierte a RGB normalizado con ImageNet stats
  ///
  /// Retorna Float32List en formato [1, 224, 224, 3] aplanado
  static Float32List? processFaceForModel(
      img.Image fullImage,
      int left,
      int top,
      int width,
      int height,
      ) {
    try {
      // Validación de entrada
      if (width <= 0 || height <= 0) {
        print('[ImageUtils] BBox inválido: width=$width, height=$height');
        return null;
      }

      if (fullImage.width <= 0 || fullImage.height <= 0) {
        print('[ImageUtils] Imagen inválida: ${fullImage.width}x${fullImage.height}');
        return null;
      }

      // Clamping de coordenadas al rango válido
      int x = left.clamp(0, fullImage.width - 1);
      int y = top.clamp(0, fullImage.height - 1);
      int w = width;
      int h = height;

      // Ajustar si se sale de los límites
      if (x + w > fullImage.width) w = fullImage.width - x;
      if (y + h > fullImage.height) h = fullImage.height - y;

      // Mínimo tamaño de cara para procesamiento confiable
      if (w < 20 || h < 20) {
        return null;
      }

      // Agregar padding alrededor de la cara (20% del tamaño menor)
      // Esto es importante para capturar contexto facial completo
      int padding = (min(w, h) * 0.2).toInt();
      int x1 = max(0, x - padding);
      int y1 = max(0, y - padding);
      int x2 = min(fullImage.width, x + w + padding);
      int y2 = min(fullImage.height, y + h + padding);

      int cropW = x2 - x1;
      int cropH = y2 - y1;

      if (cropW < 20 || cropH < 20) {
        return null;
      }

      // Recortar la región de la cara
      img.Image faceCrop = img.copyCrop(
        fullImage,
        x: x1,
        y: y1,
        width: cropW,
        height: cropH,
      );

      // Redimensionar a 224x224 (tamaño esperado por EfficientNet)
      // Usar interpolación bilinear para mejor calidad
      img.Image resized = img.copyResize(
        faceCrop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Crear buffer para el tensor de entrada
      // Formato: [batch=1, height=224, width=224, channels=3]
      var floatList = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;

      // Convertir a float con normalización ImageNet
      for (int py = 0; py < 224; py++) {
        for (int px = 0; px < 224; px++) {
          final pixel = resized.getPixel(px, py);

          // Obtener valores RGB en rango [0, 255]
          double r = pixel.r.toDouble();
          double g = pixel.g.toDouble();
          double b = pixel.b.toDouble();

          // Normalización ImageNet:
          // 1. Dividir por 255 para obtener [0, 1]
          // 2. Restar media ImageNet
          // 3. Dividir por desviación estándar ImageNet
          floatList[pixelIndex++] = ((r / 255.0) - _imagenetMean[0]) / _imagenetStd[0];
          floatList[pixelIndex++] = ((g / 255.0) - _imagenetMean[1]) / _imagenetStd[1];
          floatList[pixelIndex++] = ((b / 255.0) - _imagenetMean[2]) / _imagenetStd[2];
        }
      }

      return floatList;
    } catch (e, stackTrace) {
      print('[ImageUtils] ERROR processFaceForModel: $e');
      print('[ImageUtils] StackTrace: $stackTrace');
      return null;
    }
  }

  /// Versión alternativa sin normalización ImageNet (para debug/comparación)
  static Float32List? processFaceForModelSimple(
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

      if (w < 20 || h < 20) return null;

      int padding = (min(w, h) * 0.2).toInt();
      int x1 = max(0, x - padding);
      int y1 = max(0, y - padding);
      int x2 = min(fullImage.width, x + w + padding);
      int y2 = min(fullImage.height, y + h + padding);

      int cropW = x2 - x1;
      int cropH = y2 - y1;

      if (cropW < 20 || cropH < 20) return null;

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
          // Solo normalización 0-1 sin ImageNet stats
          floatList[pixelIndex++] = pixel.r / 255.0;
          floatList[pixelIndex++] = pixel.g / 255.0;
          floatList[pixelIndex++] = pixel.b / 255.0;
        }
      }

      return floatList;
    } catch (e) {
      print('[ImageUtils] ERROR processFaceForModelSimple: $e');
      return null;
    }
  }

  // ============ Conversores de formato de cámara ============

  /// Convierte YUV420 (Android estándar) a img.Image RGB
  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgBuffer = img.Image(width: width, height: height);

    if (image.planes.length < 3) {
      print('[ImageUtils] YUV420 requiere 3 planos, tiene ${image.planes.length}');
      return imgBuffer;
    }

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

        if (yIndex >= yPlane.length ||
            uvIndex >= uPlane.length ||
            uvIndex >= vPlane.length) {
          continue;
        }

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

  /// Convierte NV21 (común en Android) a img.Image RGB
  /// Soporta tanto formato de un plano como de dos planos
  static img.Image _convertNV21ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgBuffer = img.Image(width: width, height: height);

    Uint8List yPlane;
    Uint8List vuPlane;
    int yRowStride;
    int vuRowStride;
    int vuPixelStride = 2;

    // Detección automática: un plano combinado vs planos separados
    if (image.planes.length == 1) {
      // CASO: Todo en un solo buffer (algunos dispositivos como OPPO)
      final bytes = image.planes[0].bytes;
      int ySize = width * height;

      if (bytes.length < ySize) {
        print('[ImageUtils] Buffer NV21 muy pequeño: ${bytes.length} < $ySize');
        return imgBuffer;
      }

      yPlane = Uint8List.sublistView(bytes, 0, ySize);
      vuPlane = Uint8List.sublistView(bytes, ySize);
      yRowStride = width;
      vuRowStride = width;
    } else if (image.planes.length >= 2) {
      // CASO: Planos separados (estándar)
      yPlane = image.planes[0].bytes;
      vuPlane = image.planes[1].bytes;
      yRowStride = image.planes[0].bytesPerRow;
      vuRowStride = image.planes[1].bytesPerRow;

      if (image.planes[1].bytesPerPixel != null) {
        vuPixelStride = image.planes[1].bytesPerPixel!;
      }
    } else {
      print('[ImageUtils] NV21 sin planos válidos');
      return imgBuffer;
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int vuIndex = (y ~/ 2) * vuRowStride + (x ~/ 2) * vuPixelStride;

        if (yIndex >= yPlane.length) continue;
        if (vuIndex + 1 >= vuPlane.length) continue;

        final int yValue = yPlane[yIndex];
        // NV21: V primero, luego U
        final int vValue = vuPlane[vuIndex];
        final int uValue = vuPlane[vuIndex + 1];

        _yuvToRgb(yValue, uValue, vValue, (r, g, b) {
          imgBuffer.setPixelRgb(x, y, r, g, b);
        });
      }
    }
    return imgBuffer;
  }

  /// Convierte BGRA8888 (iOS) a img.Image RGB
  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Convierte YUV a RGB usando la fórmula estándar BT.601
  static void _yuvToRgb(int y, int u, int v, Function(int r, int g, int b) onColor) {
    // Fórmula BT.601 para conversión YUV -> RGB
    int r = (y + 1.370705 * (v - 128)).round().clamp(0, 255);
    int g = (y - 0.337633 * (u - 128) - 0.698001 * (v - 128)).round().clamp(0, 255);
    int b = (y + 1.732446 * (u - 128)).round().clamp(0, 255);
    onColor(r, g, b);
  }

  /// Utilidad para debug: guarda una imagen como bytes PNG
  static Uint8List? imageToBytes(img.Image image) {
    try {
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      print('[ImageUtils] Error encodePng: $e');
      return null;
    }
  }
}