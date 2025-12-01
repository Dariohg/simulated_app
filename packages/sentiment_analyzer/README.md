Aquí tienes una versión **extremadamente detallada y técnica** del `README.md`.

Esta versión profundiza en cada componente, explica los flujos de datos, detalla la configuración de la calibración (que es un componente exportado que no habíamos mencionado antes pero es crucial), y desglosa la arquitectura de comunicación.

-----

# Sentiment Analyzer Package

**Versión:** 1.0.0
**Compatibilidad:** Flutter 3.x+ (Android/iOS)

El paquete `sentiment_analyzer` es una solución de ingeniería de software para la integración de capacidades de computación afectiva y biometría conductual en aplicaciones móviles. Este módulo encapsula la complejidad del uso de redes neuronales convulacionales (CNN) ligeras para el análisis facial (Face Mesh), procesando flujos de video en tiempo real para extraer métricas de atención, carga cognitiva y estados emocionales, sincronizando esta telemetría con un servidor remoto para análisis longitudinal.

## Índice de Contenidos

1.  [Requisitos del Sistema e Instalación](https://www.google.com/search?q=%23requisitos-del-sistema-e-instalaci%C3%B3n)
2.  [Arquitectura del Componente](https://www.google.com/search?q=%23arquitectura-del-componente)
3.  [Módulo de Calibración](https://www.google.com/search?q=%23m%C3%B3dulo-de-calibraci%C3%B3n)
4.  [Integración del Monitor de Análisis](https://www.google.com/search?q=%23integraci%C3%B3n-del-monitor-de-an%C3%A1lisis)
5.  [Referencia de API y Configuración](https://www.google.com/search?q=%23referencia-de-api-y-configuraci%C3%B3n)
6.  [Sistema de Eventos y Callbacks](https://www.google.com/search?q=%23sistema-de-eventos-y-callbacks)
7.  [Protocolo de Comunicación Backend](https://www.google.com/search?q=%23protocolo-de-comunicaci%C3%B3n-backend)
8.  [Guía de Solución de Problemas](https://www.google.com/search?q=%23gu%C3%ADa-de-soluci%C3%B3n-de-problemas)

-----

## Requisitos del Sistema e Instalación

Este paquete depende de hardware nativo (cámara) y capacidades de procesamiento gráfico.

### 1\. Dependencias (`pubspec.yaml`)

Agregue el paquete a su proyecto Flutter:

```yaml
dependencies:
  sentiment_analyzer:
    path: ./packages/sentiment_analyzer
  # Asegúrese de tener versiones compatibles de:
  camera: ^0.10.5
  provider: ^6.0.0
```

### 2\. Configuración Nativa

#### Android

El paquete requiere una versión mínima de SDK de 21. Modifique `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdkVersion 21
    // ...
}
```

En `android/app/src/main/AndroidManifest.xml`, añada los permisos:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS

En `ios/Runner/Info.plist`, es obligatorio añadir la descripción de uso de la cámara para cumplir con las políticas de privacidad de Apple:

```xml
<key>NSCameraUsageDescription</key>
<string>Esta aplicación utiliza la cámara para analizar niveles de atención y detectar signos de fatiga durante la actividad.</string>
```

Asegúrese de ejecutar `pod install` en el directorio `ios` después de añadir la dependencia.

-----

## Arquitectura del Componente

El paquete expone tres artefactos principales:

1.  **`SentimentAnalysisManager`**: Widget orquestador que gestiona el ciclo de vida de la cámara, el procesamiento de ML y la comunicación WebSocket.
2.  **`CalibrationScreen`**: Pantalla de utilidad para establecer una línea base biométrica del usuario antes de iniciar actividades.
3.  **`SessionManager`**: Clase lógica (sin UI) que mantiene el estado de la sesión de monitoreo.

El flujo de datos sigue el patrón: `Cámara -> Detección Facial (Local) -> Extracción de Métricas -> Envío WebSocket -> Servidor -> Respuesta (Recomendación/Instrucción)`.

-----

## Módulo de Calibración

Para maximizar la precisión de la detección de somnolencia (EAR - Eye Aspect Ratio) y la distancia de atención, se recomienda realizar una calibración previa.

### Implementación

```dart
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

void launchCalibration(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => CalibrationScreen(
        onCalibrationComplete: (CalibrationResult result) {
          // Guarde este objeto 'result'. Es necesario para inicializar el Manager.
          // Puede persistirlo localmente o pasarlo directamente a la siguiente pantalla.
          print("Calibración completada. Umbral de ojos: ${result.eyeOpenThreshold}");
          Navigator.of(context).pop(result);
        },
      ),
    ),
  );
}
```

El objeto `CalibrationResult` contiene métricas normalizadas específicas para la fisonomía del usuario actual.

-----

## Integración del Monitor de Análisis

El widget `SentimentAnalysisManager` debe ser insertado en la jerarquía de widgets (`Stack`) sobre el contenido que el usuario debe consumir.

### Ejemplo Completo de Integración

```dart
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class LearningActivityView extends StatefulWidget {
  final CalibrationResult? userCalibration;

  const LearningActivityView({Key? key, this.userCalibration}) : super(key: key);

  @override
  State<LearningActivityView> createState() => _LearningActivityViewState();
}

class _LearningActivityViewState extends State<LearningActivityView> {
  late final SessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Capa de Contenido (La aplicación principal)
          Positioned.fill(
            child: MyEducationalContent(),
          ),

          // 2. Capa de Análisis (Sentiment Analyzer)
          SentimentAnalysisManager(
            sessionManager: _sessionManager,
            externalActivityId: "math_module_101",
            gatewayUrl: "https://api.edutech-backend.com",
            apiKey: "sk_live_...",
            calibration: widget.userCalibration, // Pasar resultado de calibración
            
            // Configuración de comportamiento
            isPaused: false,
            
            // Manejadores de eventos (Callbacks)
            onInstructionReceived: (text) => _showToast(text),
            onVideoReceived: (url, msg) => _showVideoDialog(url, msg),
            onPauseReceived: (reason) => _handlePauseRequest(reason),
            onStateChanged: (state) {
                // state es un objeto dinámico con {emotion, confidence, drowsiness...}
                if (state.drowsiness.isSleeping) {
                    print("ALERTA: Usuario dormido");
                }
            },
          ),
        ],
      ),
    );
  }
}
```

-----

## Referencia de API y Configuración

### Constructor: `SentimentAnalysisManager`

| Parámetro | Tipo | Obligatorio | Descripción Técnica |
| :--- | :--- | :---: | :--- |
| `sessionManager` | `SessionManager` | Sí | Singleton o instancia que gestiona el estado de conexión de la sesión actual. |
| `externalActivityId` | `String` | Sí | ID foráneo que vincula los datos biométricos con un registro en su base de datos principal. |
| `gatewayUrl` | `String` | Sí | Endpoint base. El paquete inferirá las rutas HTTP y WS. (ej. convierte `https://` a `wss://` para sockets). |
| `apiKey` | `String` | Sí | Token Bearer o clave de API enviada en las cabeceras de autorización. |
| `calibration` | `CalibrationResult?` | No | Datos de referencia. Si es `null`, se usarán valores promedio estándar (menos precisos). |
| `isPaused` | `bool` | No | `true` detiene el procesamiento de la cámara y cierra el stream de video para ahorrar batería/CPU. |
| `onSettingsRequested`| `VoidCallback?` | No | Se invoca cuando el usuario pulsa el engranaje en el menú flotante del overlay. |

-----

## Sistema de Eventos y Callbacks

El paquete no solo monitorea, sino que actúa como un canal de control bidireccional. Implemente estos callbacks para reaccionar a la lógica del servidor.

1.  **`onInstructionReceived(String instruction)`**:

    * **Disparador:** El servidor detecta confusión o estancamiento.
    * **Uso:** Mostrar un mensaje tipo "Snackbar" o modal con el texto de ayuda.

2.  **`onVideoReceived(String videoUrl, String? caption)`**:

    * **Disparador:** El servidor recomienda un material de refuerzo.
    * **Uso:** Pausar la actividad actual y reproducir el video sugerido en un overlay.

3.  **`onPauseReceived(String reason)`**:

    * **Disparador:** Fatiga extrema detectada o fin de tiempo sugerido.
    * **Uso:** Bloquear la interacción de la actividad hasta que el usuario descanse.

4.  **`onVibrateRequested()`**:

    * **Disparador:** Pérdida de atención momentánea (distracción).
    * **Uso:** Invocar `HapticFeedback.mediumImpact()` o similar.

5.  **`onConnectionStatusChanged(bool isConnected)`**:

    * **Uso:** Mostrar un indicador de "Offline" si se pierde la conexión con el servidor de análisis.

-----

## Protocolo de Comunicación Backend

Para que el paquete funcione, el servidor especificado en `gatewayUrl` debe implementar la interfaz `SentimentNetworkInterface` implícita:

### Endpoints REST Requeridos

* `POST /sessions`: Inicio de sesión de monitoreo.
* `POST /activities`: Registro de inicio de actividad.
* `POST /activities/{uuid}/feedback`: Envío de feedback explícito del usuario.

### Protocolo WebSocket

El paquete intentará conectar a `{gatewayUrl}/ws/monitoring`.

* **Payload de Envío (Cliente -\> Servidor):** JSON con frecuencia de 1-5Hz conteniendo `face_metrics`, `emotion_vector`, y `attention_score`.
* **Payload de Recepción (Servidor -\> Cliente):** Comandos de control estructurados (`type: "INSTRUCTION" | "VIDEO" | "PAUSE"`).

-----

## Guía de Solución de Problemas

### Error: `CameraException: Camera not found`

* **Causa:** El emulador no tiene cámara configurada o los permisos no fueron otorgados en tiempo de ejecución.
* **Solución:** Pruebe en dispositivo físico. En iOS, asegúrese de que la clave `NSCameraUsageDescription` está en el `Info.plist`.

### Error: `[OUTPUT NOT AVAILABLE]` en el Overlay

* **Causa:** El modelo de TFLite (`emotion_model.tflite`) no se está cargando o la cámara está bloqueada por otro proceso.
* **Solución:** Verifique que `assets/emotion_model.tflite` está incluido en el `pubspec.yaml` interno del paquete y que no hay otra instancia de `CameraController` activa en su app.

### Estado "Desconocido" o Color Gris Persistente

* **Causa:** Baja iluminación o rostro no detectado.
* **Solución:** Mejore la iluminación. Si el problema persiste, la calibración (`CalibrationResult`) podría tener valores corruptos; intente recalibrar o pasar `null` para usar valores por defecto.