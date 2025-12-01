import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
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
      if (image == null) {
        image = _convertYUV420ToImage(bytes, width, height);
      }
      if (image == null) return null;

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

      image = img.flipHorizontal(image);

      final x = boundingBox[0].clamp(0, image.width - 1);
      final y = boundingBox[1].clamp(0, image.height - 1);
      final w = boundingBox[2].clamp(1, image.width - x);
      final h = boundingBox[3].clamp(1, image.height - y);

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final resized = img.copyResize(cropped, width: 48, height: 48);
      final grayscale = img.grayscale(resized);

      final float32List = Float32List(48 * 48);
      int index = 0;

      for (int y = 0; y < 48; y++) {
        for (int x = 0; x < 48; x++) {
          final pixel = grayscale.getPixel(x, y);
          float32List[index++] = pixel.r / 255.0;
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