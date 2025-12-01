# Sentiment Analyzer Package

**Versión:** 1.0.0+1  
**Compatibilidad:** Flutter 3.0+ | Dart SDK >=3.0.0 <4.0.0  
**Plataformas soportadas:** Android (API 21+), iOS (12.0+)

## Tabla de Contenidos

1. [Descripción General](#descripción-general)
2. [Requisitos del Sistema](#requisitos-del-sistema)
3. [Instalación](#instalación)
4. [Arquitectura del Paquete](#arquitectura-del-paquete)
5. [Componentes Principales](#componentes-principales)
6. [Guía de Integración](#guía-de-integración)
7. [Sistema de Calibración](#sistema-de-calibración)
8. [Gestión de Sesiones](#gestión-de-sesiones)
9. [Análisis Biométrico](#análisis-biométrico)
10. [Personalización Visual](#personalización-visual)
11. [Comunicación con Backend](#comunicación-con-backend)
12. [Manejo de Eventos](#manejo-de-eventos)
13. [Optimización y Rendimiento](#optimización-y-rendimiento)
14. [Solución de Problemas](#solución-de-problemas)
15. [Referencia de API](#referencia-de-api)

---

## Descripción General

El paquete `sentiment_analyzer` proporciona capacidades avanzadas de análisis biométrico y cognitivo en tiempo real mediante procesamiento de video facial. Utiliza modelos de aprendizaje automático optimizados para dispositivos móviles que permiten detectar:

- Estados emocionales (8 categorías: Angry, Contempt, Disgust, Fear, Happy, Neutral, Sad, Surprise)
- Nivel de atención y orientación visual
- Indicadores de somnolencia y fatiga
- Análisis de carga cognitiva

El sistema opera completamente en el dispositivo (on-device ML) para garantizar privacidad y baja latencia, con capacidad opcional de sincronización con servicios backend para análisis longitudinal.

---

## Requisitos del Sistema

### Requisitos de Hardware

- Cámara frontal funcional
- Mínimo 2GB de RAM (recomendado 4GB)
- Procesador ARMv7 o superior (Android) / ARM64 (iOS)

### Versiones de Software

```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.0.0'
```

### Dependencias Nativas

El paquete requiere las siguientes librerías nativas:

- **Android:** Google ML Kit Face Mesh Detection
- **iOS:** Vision Framework + Core ML
- **Multiplataforma:** TensorFlow Lite Flutter

---

## Instalación

### 1. Agregar el Paquete

En su archivo `pubspec.yaml`:

```yaml
dependencies:
  sentiment_analyzer:
    path: ./packages/sentiment_analyzer
    
  # Dependencias peer requeridas
  camera: ^0.11.0
  provider: ^6.1.5
  shared_preferences: ^2.2.0
  vibration: ^3.1.0
```

### 2. Configuración de Android

#### Actualizar `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

#### Permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.VIBRATE" />
    
    <uses-feature android:name="android.hardware.camera.front" android:required="false" />
    
    <application>
        <!-- Configuración de ML Kit -->
        <meta-data
            android:name="com.google.mlkit.vision.DEPENDENCIES"
            android:value="face_mesh" />
    </application>
</manifest>
```

### 3. Configuración de iOS

#### Actualizar `ios/Podfile`:

```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

#### Agregar claves de privacidad en `ios/Runner/Info.plist`:

```xml
<dict>
    <key>NSCameraUsageDescription</key>
    <string>Esta aplicación utiliza la cámara para analizar estados cognitivos y de atención durante las actividades de aprendizaje.</string>
    
    <key>NSMicrophoneUsageDescription</key>
    <string>El micrófono no se utiliza pero es requerido por la librería de cámara.</string>
</dict>
```

#### Ejecutar instalación de pods:

```bash
cd ios
pod install
cd ..
```

### 4. Instalación de Dependencias

```bash
flutter pub get
```

---

## Arquitectura del Paquete

### Estructura de Directorios

```
sentiment_analyzer/
├── lib/
│   ├── sentiment_analyzer.dart          # Punto de entrada público
│   └── src/
│       ├── core/
│       │   ├── constants/
│       │   │   └── app_colors.dart       # Paleta de colores
│       │   ├── logic/
│       │   │   ├── attention_analyzer.dart
│       │   │   ├── drowsiness_analyzer.dart
│       │   │   ├── emotion_analyzer.dart
│       │   │   ├── state_aggregator.dart
│       │   │   └── session_manager.dart
│       │   └── utils/
│       │       ├── landmark_indices.dart
│       │       └── image_utils.dart
│       ├── data/
│       │   ├── interfaces/
│       │   │   └── network_interface.dart
│       │   ├── models/
│       │   │   ├── calibration_result.dart
│       │   │   └── recommendation_model.dart
│       │   └── services/
│       │       ├── camera_service.dart
│       │       ├── face_mesh_service.dart
│       │       ├── emotion_service.dart
│       │       ├── calibration_service.dart
│       │       ├── calibration_storage.dart
│       │       └── monitoring_websocket_service.dart
│       ├── presentation/
│       │   ├── calibration/
│       │   │   ├── viewmodel/
│       │   │   │   └── calibration_view_model.dart
│       │   │   └── widgets/
│       │   │       └── calibration_screen.dart
│       │   └── analysis/
│       │       ├── viewmodel/
│       │       │   └── analysis_view_model.dart
│       │       └── widgets/
│       │           ├── analysis_overlay.dart
│       │           └── floating_menu_overlay.dart
│       └── sentiment_analysis_manager.dart
└── assets/
    └── emotion_model.tflite                # Modelo de ML
```

### Capas de Arquitectura

1. **Capa de Presentación:** Widgets y ViewModels que manejan la UI
2. **Capa de Lógica:** Analizadores especializados para cada métrica biométrica
3. **Capa de Datos:** Servicios de acceso a hardware y comunicación
4. **Capa de Modelos:** Estructuras de datos compartidas

---

## Componentes Principales

### 1. SentimentAnalysisManager

Widget principal que orquesta todo el sistema de análisis. Gestiona el ciclo de vida completo del monitoreo biométrico.

**Características:**
- Inicialización automática de cámara y servicios ML
- Procesamiento de frames en tiempo real (ajustable)
- Overlay visual con información del análisis
- Menú flotante con controles de usuario
- Sistema de callbacks para eventos

### 2. CalibrationScreen

Pantalla de calibración que establece líneas base personalizadas para cada usuario.

**Fases de calibración:**
1. **Detección facial:** Verifica que el rostro sea visible y estable
2. **Verificación de iluminación:** Asegura condiciones lumínicas adecuadas
3. **Línea base de ojos:** Mide apertura ocular en estado normal
4. **Medición de ojos cerrados:** Establece umbral de somnolencia

### 3. SessionManager

Clase de gestión de estado que coordina sesiones de monitoreo y actividades.

**Responsabilidades:**
- Crear y finalizar sesiones
- Iniciar, pausar y completar actividades
- Gestionar heartbeats con el servidor
- Modo offline automático en caso de pérdida de conexión

---

## Guía de Integración

### Integración Básica

```dart
import 'package:flutter/material.dart';
import 'package:sentiment_analyzer/sentiment_analyzer.dart';

class MyMonitoredActivity extends StatefulWidget {
  const MyMonitoredActivity({super.key});

  @override
  State<MyMonitoredActivity> createState() => _MyMonitoredActivityState();
}

class _MyMonitoredActivityState extends State<MyMonitoredActivity> {
  late final SessionManager _sessionManager;
  CalibrationResult? _calibration;
  
  @override
  void initState() {
    super.initState();
    _initializeSession();
    _loadCalibration();
  }
  
  Future<void> _initializeSession() async {
    _sessionManager = SessionManager(
      network: MyNetworkService(), // Implementación de SentimentNetworkInterface
      userId: 12345,
      disabilityType: 'TDAH',
      cognitiveAnalysisEnabled: true,
    );
    
    await _sessionManager.initializeSession();
    
    await _sessionManager.startActivity(
      externalActivityId: 501,
      title: 'Lectura Comprensiva',
      activityType: 'LECTURA',
    );
  }
  
  Future<void> _loadCalibration() async {
    final storage = CalibrationStorage();
    _calibration = await storage.load();
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Contenido principal de su aplicación
          Positioned.fill(
            child: MyActivityContent(),
          ),
          
          // Overlay de análisis
          if (_sessionManager.hasActiveSession)
            SentimentAnalysisManager(
              sessionManager: _sessionManager,
              externalActivityId: '501',
              gatewayUrl: 'https://api.example.com',
              apiKey: 'your_api_key',
              calibration: _calibration,
              onStateChanged: _handleStateChange,
              onVibrateRequested: _handleVibration,
              onInstructionReceived: _handleInstruction,
            ),
        ],
      ),
    );
  }
  
  void _handleStateChange(dynamic state) {
    // Procesar cambios de estado cognitivo
    debugPrint('Estado actual: ${state.finalState}');
  }
  
  void _handleVibration() async {
    // Implementar feedback háptico
    await Vibration.vibrate(duration: 500);
  }
  
  void _handleInstruction(String message) {
    // Mostrar instrucciones al usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
```

### Integración con Calibración

```dart
class CalibrationFlow extends StatelessWidget {
  final SessionManager sessionManager;
  final ActivityOption activity;
  
  const CalibrationFlow({
    super.key,
    required this.sessionManager,
    required this.activity,
  });
  
  @override
  Widget build(BuildContext context) {
    return CalibrationScreen(
      onCalibrationComplete: () async {
        // La calibración se guarda automáticamente
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityView(
              sessionManager: sessionManager,
              activity: activity,
            ),
          ),
        );
      },
      onSkip: () {
        // Permitir omitir calibración (menos preciso)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityView(
              sessionManager: sessionManager,
              activity: activity,
            ),
          ),
        );
      },
    );
  }
}
```

---

## Sistema de Calibración

### Proceso de Calibración

El sistema de calibración establece parámetros personalizados para maximizar la precisión del análisis biométrico.

#### Paso 1: Detección Facial

```dart
// Parámetros internos (no configurables)
static const int _targetGoodFrames = 45;
static const double _stabilityThreshold = 0.4;
```

El sistema analiza 60 frames y requiere que al menos 45 tengan un puntaje de estabilidad >= 0.4.

#### Paso 2: Verificación de Iluminación

```dart
// Umbrales de brillo aceptable
const double minBrightness = 0.2;  // 20% brillo mínimo
const double maxBrightness = 0.95; // 95% brillo máximo
```

Se analizan 25 frames para establecer el brillo promedio. El sistema rechaza condiciones de iluminación extremas.

#### Paso 3: Línea Base Ocular

```dart
// Medición de apertura ocular normal
const int framesForEyeOpen = 40;    // Frames con ojos abiertos
const int framesForEyeClosed = 25;  // Frames con ojos cerrados
```

El sistema calcula el EAR (Eye Aspect Ratio) promedio en ambos estados.

#### Paso 4: Cálculo de Umbral

```dart
// Fórmula del umbral de somnolencia
final earThreshold = avgClosedEAR + (avgOpenEAR - avgClosedEAR) * 0.4;
```

Este umbral personalizado mejora significativamente la detección de somnolencia.

### Almacenamiento de Calibración

```dart
// Cargar calibración guardada
final storage = CalibrationStorage();
final calibration = await storage.load();

if (calibration != null && calibration.isSuccessful) {
  // Usar calibración existente
  analyzer.applyCalibration(calibration);
} else {
  // Requiere nueva calibración
  navigateToCalibrationScreen();
}

// Borrar calibración
await storage.clear();
```

### Estructura de CalibrationResult

```dart
class CalibrationResult {
  final bool isSuccessful;
  final double? earThreshold;        // Umbral de somnolencia
  final double? baselinePitch;       // Inclinación de cabeza base
  final double? baselineYaw;         // Rotación de cabeza base
  final double? baselineEAR;         // EAR promedio con ojos abiertos
  final double? avgBrightness;       // Brillo promedio de calibración
  final DateTime? calibratedAt;      // Timestamp de calibración
}
```

---

## Gestión de Sesiones

### Ciclo de Vida de Sesión

```dart
final sessionManager = SessionManager(
  network: networkService,
  userId: 12345,
  disabilityType: 'TDAH',
  cognitiveAnalysisEnabled: true,
);

// 1. Iniciar sesión
await sessionManager.initializeSession();

// 2. Iniciar actividad
await sessionManager.startActivity(
  externalActivityId: 501,
  title: 'Ejercicio de Matemáticas',
  subtitle: 'Resolución de problemas',
  content: 'Resuelve las siguientes ecuaciones...',
  activityType: 'MATEMATICAS',
);

// 3. Pausar actividad (opcional)
await sessionManager.pauseActivity();

// 4. Reanudar actividad
await sessionManager.resumeActivity();

// 5. Completar actividad
await sessionManager.completeActivity(
  feedback: {
    'rating': 5,
    'completed': true,
    'time_spent': 600, // segundos
  },
);

// 6. Finalizar sesión
await sessionManager.finalizeSession();
```

### Estados de Sesión

```dart
enum SessionStatus {
  none,                   // Sin sesión activa
  active,                // Sesión en progreso
  paused,                // Pausada por el usuario
  pausedAutomatically,   // Pausada por el sistema
  expired,               // Sesión expirada
  finalized,             // Sesión finalizada
}

enum ActivityStatus {
  none,         // Sin actividad
  inProgress,   // Actividad en curso
  paused,       // Actividad pausada
  completed,    // Actividad completada
  abandoned,    // Actividad abandonada
}
```

### Modo Offline

El SessionManager detecta automáticamente pérdidas de conexión y opera en modo offline:

```dart
// Verificar estado offline
if (sessionManager.isOffline) {
  showSnackBar('Modo offline: Los datos se sincronizarán al reconectar');
}

// Los métodos continúan funcionando normalmente
await sessionManager.startActivity(...); // Genera UUID local
await sessionManager.completeActivity(...); // Guarda localmente
```

---

## Análisis Biométrico

### Analizadores Disponibles

#### 1. AttentionAnalyzer

Determina si el usuario está mirando la pantalla basándose en la orientación de la cabeza.

**Parámetros configurables:**

```dart
AttentionAnalyzer(
  pitchThreshold: 45.0,              // Grados de inclinación vertical
  yawThreshold: 45.0,                // Grados de rotación horizontal
  notLookingFramesThreshold: 25,     // Frames antes de marcar distracción
  calibrationFramesRequired: 30,     // Frames para auto-calibración
  calibrationStabilityThreshold: 15.0, // Estabilidad requerida
);
```

**Resultado:**

```dart
class AttentionResult {
  final double pitch;              // Inclinación actual
  final double yaw;                // Rotación actual
  final double roll;               // Giro lateral
  final bool isLookingAtScreen;    // true si está mirando
  final int notLookingFrames;      // Contador de frames sin mirar
}
```

#### 2. DrowsinessAnalyzer

Detecta signos de somnolencia mediante análisis de apertura ocular y bostezos.

**Parámetros configurables:**

```dart
DrowsinessAnalyzer(
  earThreshold: 0.21,                // Umbral de Eye Aspect Ratio
  marThreshold: 0.6,                 // Umbral de Mouth Aspect Ratio
  drowsyFramesThreshold: 20,         // Frames para detectar somnolencia
  yawnFramesThreshold: 15,           // Frames para detectar bostezo
  maxDrowsyBuffer: 30,               // Buffer máximo de frames
  maxYawnBuffer: 20,                 // Buffer máximo de bostezos
);
```

**Actualización de umbral calibrado:**

```dart
if (calibration != null && calibration.earThreshold != null) {
  drowsinessAnalyzer.updateEarThreshold(calibration.earThreshold!);
}
```

**Resultado:**

```dart
class DrowsinessResult {
  final double ear;           // Eye Aspect Ratio actual
  final double mar;           // Mouth Aspect Ratio actual
  final bool isDrowsy;        // true si está somnoliento
  final bool isYawning;       // true si está bostezando
  final int drowsyFrames;     // Contador de frames somnolientos
  final int yawnFrames;       // Contador de frames bostezando
}
```

#### 3. EmotionAnalyzer

Identifica emociones faciales usando un modelo CNN entrenado en 8 categorías.

**Emociones detectadas:**

```dart
static const List<String> emotionLabels = [
  'Angry',      // Enojo
  'Contempt',   // Desprecio
  'Disgust',    // Disgusto
  'Fear',       // Miedo
  'Happy',      // Felicidad
  'Neutral',    // Neutral
  'Sad',        // Tristeza
  'Surprise',   // Sorpresa
];
```

**Parámetros internos:**

```dart
static const int _historySize = 10;         // Frames para suavizado
static const double _minConfidence = 0.20;  // Confianza mínima
static const double _happyBoost = 1.1;      // Impulso para felicidad
```

**Resultado:**

```dart
class EmotionResult {
  final String emotion;                   // Emoción dominante
  final double confidence;                // Confianza (0.0-1.0)
  final String cognitiveState;            // Estado cognitivo derivado
  final Map<String, double> scores;       // Puntuaciones de todas las emociones
}
```

**Mapeo de emociones a estados cognitivos:**

```dart
String _mapToCognitiveState(String emotion) {
  switch (emotion) {
    case 'Happy':
      return 'entendiendo';    // Comprensión/Satisfacción
    case 'Angry':
    case 'Contempt':
    case 'Disgust':
    case 'Sad':
      return 'frustrado';      // Frustración
    case 'Fear':
    case 'Surprise':
      return 'distraido';      // Distracción/Confusión
    case 'Neutral':
    default:
      return 'concentrado';    // Atención estable
  }
}
```

### StateAggregator

Combina los resultados de todos los analizadores en un estado unificado.

**Prioridad de estados:**

1. **durmiendo:** Si el DrowsinessAnalyzer detecta somnolencia
2. **no_mirando:** Si el AttentionAnalyzer detecta que no mira la pantalla
3. **Estado cognitivo:** Del EmotionAnalyzer (concentrado, entendiendo, frustrado, distraido)

**Resultado combinado:**

```dart
class CombinedState {
  final String finalState;              // Estado final agregado
  final String emotion;                 // Emoción detectada
  final double confidence;              // Confianza de la emoción
  final Map<String, double>? emotionScores;  // Todas las puntuaciones
  final DrowsinessResult? drowsiness;   // Resultado de somnolencia
  final AttentionResult? attention;     // Resultado de atención
  final bool faceDetected;              // true si se detecta rostro
  final bool isCalibrating;             // true durante auto-calibración
}
```

---

## Personalización Visual

### Paleta de Colores

El paquete incluye una paleta de colores predefinida en `AppColors`:

```dart
import 'package:sentiment_analyzer/src/core/constants/app_colors.dart';

// Colores principales
AppColors.primary              // Color primario
AppColors.success              // Verde de éxito
AppColors.warning              // Naranja de advertencia
AppColors.error                // Rojo de error
AppColors.background           // Negro de fondo
AppColors.surface              // Blanco de superficie
AppColors.overlay              // Negro semitransparente
AppColors.transparent          // Transparente

// Colores de estado cognitivo
AppColors.statusConcentrated   // Verde (concentrado)
AppColors.statusDistracted     // Naranja (distraído)
AppColors.statusFrustrated     // Rojo (frustrado)
AppColors.statusSleeping       // Morado (durmiendo)
AppColors.statusNoLooking      // Gris (no mirando)

// Colores de calibración
AppColors.calibrationFaceDetection  // Azul (detección facial)
AppColors.calibrationLighting       // Amarillo (iluminación)
AppColors.calibrationEyeBaseline    // Morado (línea base)
AppColors.calibrationCompleted      // Verde (completado)

// Colores de controles
AppColors.iconPause            // Naranja (pausa)
AppColors.iconPlay             // Verde (reproducir)
AppColors.iconClose            // Gris (cerrar)
AppColors.notificationDot      // Rojo (punto de notificación)
```

### Personalizar Colores

Si necesita personalizar los colores, puede crear una implementación personalizada:

```dart
import 'package:flutter/material.dart';

class CustomAppColors {
  // Reemplazar con su paleta de marca
  static const Color primary = Color(0xFF6200EE);
  static const Color statusConcentrated = Color(0xFF00C853);
  // ... más colores
}

// Usar en su aplicación
Container(
  color: CustomAppColors.primary,
  // ...
)
```

### Overlay de Análisis

El `AnalysisOverlay` muestra información en tiempo real en la esquina inferior izquierda:

```dart
// Configuración del overlay (no expuesta públicamente)
Container(
  width: 120,  // Ancho del preview de cámara
  height: 160, // Alto del preview de cámara
  // ...
)
```

**Información mostrada:**

- Preview de cámara en miniatura
- Estado cognitivo actual (color codificado)
- Emoción detectada
- Nivel de confianza
- EAR (Eye Aspect Ratio) si disponible
- Indicador de rostro detectado (punto verde/rojo)

### Menú Flotante

El `FloatingMenuOverlay` proporciona controles de usuario:

```dart
// Posición inicial (configurable mediante drag)
Offset _position = const Offset(20, 100);

// Botones disponibles
- Pausar/Reanudar (icono pause/play)
- Ocultar/Mostrar cámara (icono videocam)
- Configuración (icono settings)
- Notificaciones (icono notifications con badge)
```

**Personalizar posición inicial:**

```dart
// No expuesto directamente, pero puede subclasificar
class CustomFloatingMenu extends FloatingMenuOverlay {
  @override
  void initState() {
    super.initState();
    _position = const Offset(100, 200); // Nueva posición
  }
}
```

---

## Comunicación con Backend

### Interfaz de Red

Implementar `SentimentNetworkInterface` para conectar con su backend:

```dart
import 'package:sentiment_analyzer/sentiment_analyzer.dart';
import 'package:dio/dio.dart';

class MyNetworkService implements SentimentNetworkInterface {
  final Dio _dio;
  
  MyNetworkService(String baseUrl) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer YOUR_API_KEY',
    },
  ));
  
  @override
  Future<Map<String, dynamic>> createSession({
    required int userId,
    required String disabilityType,
    required bool cognitiveAnalysisEnabled,
  }) async {
    final response = await _dio.post('/sessions/', data: {
      'user_id': userId,
      'disability_type': disabilityType,
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
    });
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _dio.get('/sessions/$sessionId');
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<void> sendHeartbeat(String sessionId) async {
    await _dio.post('/sessions/$sessionId/heartbeat');
  }
  
  @override
  Future<void> pauseSession(String sessionId) async {
    await _dio.post('/sessions/$sessionId/pause');
  }
  
  @override
  Future<void> resumeSession(String sessionId) async {
    await _dio.post('/sessions/$sessionId/resume');
  }
  
  @override
  Future<Map<String, dynamic>> finalizeSession(String sessionId) async {
    final response = await _dio.delete('/sessions/$sessionId');
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> startActivity({
    required String sessionId,
    required int externalActivityId,
    required String title,
    String? subtitle,
    String? content,
    required String activityType,
  }) async {
    final response = await _dio.post(
      '/sessions/$sessionId/activity/start',
      data: {
        'external_activity_id': externalActivityId,
        'title': title,
        'subtitle': subtitle,
        'content': content,
        'activity_type': activityType,
      },
    );
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> completeActivity({
    required String activityUuid,
    required Map<String, dynamic> feedback,
  }) async {
    final response = await _dio.post(
      '/activities/$activityUuid/complete',
      data: {'feedback': feedback},
    );
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> abandonActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/abandon');
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> pauseActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/pause');
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<Map<String, dynamic>> resumeActivity({
    required String activityUuid,
  }) async {
    final response = await _dio.post('/activities/$activityUuid/resume');
    return response.data as Map<String, dynamic>;
  }
  
  @override
  Future<void> updateConfig({
    required String sessionId,
    required bool cognitiveAnalysisEnabled,
    required bool textNotifications,
    required bool videoSuggestions,
    required bool vibrationAlerts,
    required bool pauseSuggestions,
  }) async {
    await _dio.post('/sessions/$sessionId/config', data: {
      'cognitive_analysis_enabled': cognitiveAnalysisEnabled,
      'text_notifications': textNotifications,
      'video_suggestions': videoSuggestions,
      'vibration_alerts': vibrationAlerts,
      'pause_suggestions': pauseSuggestions,
    });
  }
}
```

### Protocolo WebSocket

El paquete incluye `MonitoringWebSocketService` que gestiona automáticamente:

**Conexión:**

```
wss://{gatewayUrl}/ws/{sessionId}/{activityUuid}?api_key={apiKey}
```

**Handshake inicial:**

```json
{
  "type": "handshake",
  "user_id": 12345,
  "external_activity_id": 501
}
```

**Respuesta del servidor:**

```json
{
  "type": "handshake_ack",
  "status": "ready"
}
```

**Envío de frames (cliente -> servidor):**

```json
{
  "metadata": {
    "timestamp": "2025-01-15T10:30:00.000Z",
    "user_id": 12345,
    "session_id": "sess_abc123",
    "external_activity_id": 501
  },
  "analisis_sentimiento": {
    "emocion_principal": {
      "nombre": "Happy",
      "confianza": 0.85,
      "estado_cognitivo": "entendiendo"
    },
    "desglose_emociones": [
      {"emocion": "Happy", "confianza": 85.0},
      {"emocion": "Neutral", "confianza": 10.0},
      {"emocion": "Surprise", "confianza": 5.0}
    ]
  },
  "datos_biometricos": {
    "atencion": {
      "mirando_pantalla": true,
      "orientacion_cabeza": {
        "pitch": 2.5,
        "yaw": -1.2
      }
    },
    "somnolencia": {
      "esta_durmiendo": false,
      "apertura_ojos_ear": 0.28
    },
    "rostro_detectado": true
  }
}
```

**Recomendaciones del servidor (servidor -> cliente):**

```json
{
  "type": "recommendation",
  "session_id": "sess_abc123",
  "user_id": 12345,
  "action": "instruction",
  "content": {
    "type": "text",
    "message": "Parece que estás teniendo dificultades. Intenta releer el último párrafo.",
    "title": "Sugerencia de apoyo"
  },
  "metadata": {
    "cognitive_event": "frustration_detected",
    "confidence": 0.78,
    "topic": "reading_comprehension"
  },
  "timestamp": "2025-01-15T10:30:15.000Z"
}
```

**Tipos de acciones:**

- `vibration`: Solicitar vibración del dispositivo
- `instruction`: Mostrar mensaje de texto
- `pause`: Sugerir pausa
- `video`: Mostrar video de apoyo

### Estructura de Recommendation

```dart
class Recommendation {
  final String sessionId;
  final int? userId;
  final String action;                    // 'vibration', 'instruction', 'pause', 'video'
  final RecommendationContent? content;   // Contenido del mensaje/video
  final VibrationPattern? vibration;      // Patrón de vibración
  final RecommendationMetadata? metadata; // Metadatos del evento
  final String? timestamp;
  
  // Helpers
  bool get isVibration => action == 'vibration';
  bool get isInstruction => action == 'instruction';
  bool get isPause => action == 'pause';
  bool get hasVideo => content?.videoUrl != null;
  bool get hasMessage => content?.message != null;
}

class RecommendationContent {
  final String? type;       // 'text', 'video'
  final String? message;    // Texto del mensaje
  final String? videoUrl;   // URL del video
  final String? title;      // Título del contenido
}

class VibrationPattern {
  final int duration;       // Duración en milisegundos
  final int intensity;      // Intensidad 0-100
  final List<int>? pattern; // Patrón personalizado [on, off, on, off...]
}

class RecommendationMetadata {
  final String? cognitiveEvent;    // Evento que disparó la recomendación
  final double? precision;          // Precisión del análisis
  final double? confidence;         // Confianza de la detección
  final String? topic;              // Tópico relacionado
  final String? contentType;        // Tipo de contenido
}
```

---

## Manejo de Eventos

### Callbacks Disponibles

#### onStateChanged

Se dispara cada vez que cambia el estado cognitivo del usuario.

```dart
SentimentAnalysisManager(
  // ...
  onStateChanged: (dynamic state) {
    final combinedState = state as CombinedState;
    
    // Acceder a todos los datos
    print('Estado: ${combinedState.finalState}');
    print('Emoción: ${combinedState.emotion}');
    print('Confianza: ${combinedState.confidence}');
    
    if (combinedState.drowsiness?.isDrowsy == true) {
      print('ALERTA: Usuario somnoliento');
      showWarningDialog();
    }
    
    if (combinedState.attention?.isLookingAtScreen == false) {
      print('Usuario no está mirando la pantalla');
    }
    
    // Acceder a puntuaciones de emociones
    combinedState.emotionScores?.forEach((emotion, score) {
      print('$emotion: ${score.toStringAsFixed(1)}%');
    });
  },
)
```

#### onVibrateRequested

Se dispara cuando el servidor solicita vibración del dispositivo.

```dart
import 'package:vibration/vibration.dart';

SentimentAnalysisManager(
  // ...
  onVibrateRequested: () async {
    // Verificar si el dispositivo soporta vibración
    final hasVibrator = await Vibration.hasVibrator();
    
    if (hasVibrator == true) {
      // Vibración simple
      await Vibration.vibrate(duration: 500);
      
      // O patrón personalizado
      await Vibration.vibrate(
        pattern: [0, 200, 100, 200], // Espera, vibra, pausa, vibra
        intensities: [0, 128, 0, 255], // Intensidades
      );
    }
  },
)
```

#### onInstructionReceived

Se dispara cuando el servidor envía una instrucción de texto.

```dart
SentimentAnalysisManager(
  // ...
  onInstructionReceived: (String message) {
    // Mostrar como SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
    
    // O como Dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sugerencia'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  },
)
```

#### onVideoReceived

Se dispara cuando el servidor recomienda un video de apoyo.

```dart
import 'package:url_launcher/url_launcher.dart';

SentimentAnalysisManager(
  // ...
  onVideoReceived: (String videoUrl, String? title) async {
    // Abrir en navegador/app externa
    final uri = Uri.parse(videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    
    // O mostrar en player integrado
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Integrar video player aquí
            VideoPlayerWidget(url: videoUrl),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  },
)
```

#### onPauseReceived

Se dispara cuando el servidor sugiere una pausa.

```dart
SentimentAnalysisManager(
  // ...
  onPauseReceived: (String reason) async {
    // Pausar actividad automáticamente
    await sessionManager.pauseActivity();
    
    // Mostrar pantalla de descanso
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Tiempo de descanso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.self_improvement, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(reason),
              const SizedBox(height: 16),
              const Text('Tómate 5 minutos para descansar.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await sessionManager.resumeActivity();
                Navigator.pop(context);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  },
)
```

#### onConnectionStatusChanged

Se dispara cuando cambia el estado de conexión con el servidor.

```dart
SentimentAnalysisManager(
  // ...
  onConnectionStatusChanged: (bool isConnected) {
    if (isConnected) {
      print('Conectado al servidor de análisis');
      // Ocultar indicador de offline
    } else {
      print('Desconectado - Modo offline activado');
      // Mostrar indicador de offline
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión - Los datos se sincronizarán más tarde'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  },
)
```

#### onSettingsRequested

Se dispara cuando el usuario presiona el botón de configuración en el menú flotante.

```dart
SentimentAnalysisManager(
  // ...
  onSettingsRequested: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionConfigView(
          sessionId: sessionManager.sessionId!,
          networkService: networkService,
        ),
      ),
    );
  },
)
```

---

## Optimización y Rendimiento

### Configuración de Procesamiento

El sistema procesa frames a intervalos controlados para balancear precisión y rendimiento:

```dart
// Intervalo de procesamiento (interno)
final Duration _processInterval = const Duration(milliseconds: 200);
```

Esto resulta en aproximadamente 5 frames por segundo (5 FPS), suficiente para análisis preciso sin sobrecargar el dispositivo.

### Uso de Isolates

El procesamiento de imágenes se realiza en isolates para evitar bloquear el hilo principal:

```dart
// Procesamiento en isolate separado
final modelInput = await ImageUtils.processCameraImageInIsolate(
  image,
  sensorOrientation,
  boundingBox,
);
```

### Optimización de Memoria

**Resolución de cámara:**

```dart
CameraController(
  description,
  ResolutionPreset.low,  // Resolución baja es suficiente para Face Mesh
  enableAudio: false,
);
```

**Historial limitado:**

```dart
// Límite de frames en historial para suavizado
static const int _historySize = 10;
```

**Buffers circulares:**

```dart
final ListQueue<List<double>> _calibrationFrames = ListQueue();
if (_calibrationFrames.length > _calibrationFramesRequired) {
  _calibrationFrames.removeFirst();
}
```

### Recomendaciones de Rendimiento

1. **Limitar análisis:** Use `isPaused = true` cuando el análisis no sea necesario
2. **Calibración inicial:** La calibración mejora precisión y reduce falsos positivos
3. **Iluminación adecuada:** Mejora detección facial y reduce procesamiento innecesario
4. **Cerrar sesiones:** Siempre llame a `dispose()` o `finalizeSession()` al terminar

### Monitoreo de Recursos

```dart
import 'dart:developer' as developer;

class PerformanceMonitor {
  static void logFrameProcessing(Duration duration) {
    developer.log(
      'Frame procesado en ${duration.inMilliseconds}ms',
      name: 'sentiment_analyzer.performance',
    );
    
    if (duration.inMilliseconds > 300) {
      developer.log(
        'ADVERTENCIA: Procesamiento lento detectado',
        name: 'sentiment_analyzer.performance',
        level: 900, // Warning level
      );
    }
  }
}
```

---

## Solución de Problemas

### Error: CameraException - Camera not found

**Síntomas:**
```
PlatformException(CameraAccess, Camera permission denied, null, null)
```

**Causas posibles:**
1. Permisos de cámara no otorgados
2. Cámara no disponible en el emulador
3. Configuración incorrecta en AndroidManifest.xml o Info.plist

**Solución:**

**Android:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.front" android:required="false" />
```

**iOS:**
```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Descripción clara del uso de la cámara</string>
```

**Solicitar permisos en tiempo de ejecución:**
```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  
  if (status.isDenied) {
    // Permiso denegado
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: const Text('Esta aplicación necesita acceso a la cámara.'),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }
}
```

### Error: TFLite model not found

**Síntomas:**
```
Unable to load asset: packages/sentiment_analyzer/assets/emotion_model.tflite
```

**Causas:**
- Archivo de modelo no incluido correctamente
- Path incorrecto en pubspec.yaml

**Solución:**

Verificar `packages/sentiment_analyzer/pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/emotion_model.tflite
```

Verificar que el archivo existe:
```bash
ls packages/sentiment_analyzer/assets/emotion_model.tflite
```

### Error: Face Mesh detection fails

**Síntomas:**
- No se detecta rostro incluso estando frente a la cámara
- `faceDetected: false` constantemente

**Causas:**
1. Iluminación insuficiente
2. Rostro fuera del encuadre
3. Cámara con resolución muy baja

**Solución:**

```dart
// Verificar condiciones de iluminación
if (brightness < 0.2) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Iluminación insuficiente'),
      content: const Text('Por favor, busca un lugar con mejor iluminación.'),
    ),
  );
}

// Aumentar resolución de cámara si es necesario
CameraController(
  description,
  ResolutionPreset.medium, // Cambiar de low a medium
  enableAudio: false,
);
```

### Error: WebSocket connection failed

**Síntomas:**
```
WebSocketException: Connection to 'wss://...' failed
```

**Causas:**
1. URL incorrecta
2. API key inválida
3. Servidor no disponible
4. Problema de red

**Solución:**

```dart
// Verificar URL
print('Intentando conectar a: $gatewayUrl');

// Verificar API key
print('API Key (primeros 10 chars): ${apiKey.substring(0, 10)}...');

// Implementar modo offline
if (sessionManager.isOffline) {
  print('Operando en modo offline');
  // Los datos se almacenarán localmente
}

// Reintentar conexión
await Future.delayed(const Duration(seconds: 5));
await sessionManager.recoverSession(existingSessionId);
```

### Error: High battery consumption

**Síntomas:**
- Batería se consume rápidamente
- Dispositivo se calienta

**Causas:**
1. Procesamiento continuo sin pausas
2. Resolución de cámara muy alta
3. Múltiples instancias de AnalysisViewModel

**Solución:**

```dart
// Pausar cuando no sea necesario
SentimentAnalysisManager(
  isPaused: true, // Activar cuando el usuario no esté viendo
  // ...
)

// Reducir frecuencia de procesamiento
final Duration _processInterval = const Duration(milliseconds: 300); // Aumentar de 200 a 300

// Asegurarse de limpiar recursos
@override
void dispose() {
  sessionManager.finalizeSession();
  analysisViewModel.dispose();
  super.dispose();
}
```

### Error: Calibration fails repeatedly

**Síntomas:**
- Calibración no se completa
- Se queda en una fase específica

**Causas:**
1. Movimiento excesivo durante calibración
2. Iluminación irregular
3. Obstrucciones faciales (lentes oscuros, etc.)

**Solución:**

```dart
// Verificar estabilidad facial
if (faceStability < 0.4) {
  showMessage('Mantén tu rostro quieto y centrado');
}

// Verificar iluminación
if (brightness < 0.2 || brightness > 0.95) {
  showMessage('Ajusta la iluminación ambiental');
}

// Permitir omitir calibración
CalibrationScreen(
  onSkip: () {
    // Usar valores por defecto
    Navigator.pushReplacement(context, ...);
  },
)
```

### Error: Memory leaks

**Síntomas:**
- Memoria aumenta continuamente
- App se vuelve lenta con el tiempo

**Causas:**
1. Listeners no removidos
2. Streams no cerrados
3. Controllers no disposed

**Solución:**

```dart
class MyState extends State<MyWidget> {
  late final StreamSubscription _subscription;
  late final AnalysisViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    _viewModel = AnalysisViewModel(...);
    _subscription = _viewModel.stateStream.listen(...);
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    _viewModel.dispose();
    super.dispose();
  }
}
```

---

## Referencia de API

### Clases Principales

#### SentimentAnalysisManager

```dart
class SentimentAnalysisManager extends StatefulWidget {
  const SentimentAnalysisManager({
    Key? key,
    required this.sessionManager,
    required this.externalActivityId,
    required this.gatewayUrl,
    required this.apiKey,
    this.calibration,
    this.isPaused = false,
    this.onVibrateRequested,
    this.onInstructionReceived,
    this.onPauseReceived,
    this.onVideoReceived,
    this.onConnectionStatusChanged,
    this.onStateChanged,
    this.onSettingsRequested,
  }) : super(key: key);
}
```

#### SessionManager

```dart
class SessionManager extends ChangeNotifier {
  SessionManager({
    required this.network,
    required this.userId,
    this.disabilityType = 'none',
    this.cognitiveAnalysisEnabled = true,
  });
  
  // Getters
  String? get sessionId;
  SessionStatus get sessionStatus;
  ActivityStatus get activityStatus;
  ActivityInfo? get currentActivity;
  bool get hasActiveSession;
  bool get hasActiveActivity;
  bool get isOffline;
  Stream<Recommendation> get recommendationStream;
  
  // Métodos
  Future<bool> initializeSession();
  Future<bool> recoverSession(String existingSessionId);
  Future<bool> startActivity({...});
  Future<bool> completeActivity({...});
  Future<bool> abandonActivity();
  Future<bool> pauseActivity();
  Future<bool> resumeActivity();
  Future<bool> pauseSession();
  Future<bool> resumeSession();
  Future<bool> finalizeSession();
  void emitRecommendation(Recommendation recommendation);
}
```

#### CalibrationScreen

```dart
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    Key? key,
    required this.onCalibrationComplete,
    this.onSkip,
  }) : super(key: key);
}
```

#### CalibrationStorage

```dart
class CalibrationStorage {
  Future<void> save(CalibrationResult result);
  Future<CalibrationResult?> load();
  Future<void> clear();
}
```

### Modelos de Datos

#### CalibrationResult

```dart
class CalibrationResult {
  final bool isSuccessful;
  final double? earThreshold;
  final double? baselinePitch;
  final double? baselineYaw;
  final double? baselineEAR;
  final double? avgBrightness;
  final DateTime? calibratedAt;
  
  CalibrationResult({...});
  factory CalibrationResult.failed();
  factory CalibrationResult.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### CombinedState

```dart
class CombinedState {
  final String finalState;
  final String emotion;
  final double confidence;
  final Map<String, double>? emotionScores;
  final DrowsinessResult? drowsiness;
  final AttentionResult? attention;
  final bool faceDetected;
  final bool isCalibrating;
  
  CombinedState({...});
  Map<String, dynamic> toJson();
}
```

#### Recommendation

```dart
class Recommendation {
  final String sessionId;
  final int? userId;
  final String action;
  final RecommendationContent? content;
  final VibrationPattern? vibration;
  final RecommendationMetadata? metadata;
  final String? timestamp;
  
  bool get isVibration;
  bool get isInstruction;
  bool get isPause;
  bool get hasVideo;
  bool get hasMessage;
  
  factory Recommendation.fromJson(Map<String, dynamic> json);
}
```

### Interfaces

#### SentimentNetworkInterface

```dart
abstract class SentimentNetworkInterface {
  Future<Map<String, dynamic>> createSession({...});
  Future<Map<String, dynamic>> getSession(String sessionId);
  Future<void> sendHeartbeat(String sessionId);
  Future<void> pauseSession(String sessionId);
  Future<void> resumeSession(String sessionId);
  Future<Map<String, dynamic>> finalizeSession(String sessionId);
  Future<Map<String, dynamic>> startActivity({...});
  Future<Map<String, dynamic>> completeActivity({...});
  Future<Map<String, dynamic>> abandonActivity({...});
  Future<Map<String, dynamic>> pauseActivity({...});
  Future<Map<String, dynamic>> resumeActivity({...});
  Future<void> updateConfig({...});
}
```

### Enumeraciones

```dart
enum SessionStatus {
  none,
  active,
  paused,
  pausedAutomatically,
  expired,
  finalized,
}

enum ActivityStatus {
  none,
  inProgress,
  paused,
  completed,
  abandoned,
}

enum CalibrationStep {
  faceDetection,
  lighting,
  eyeBaseline,
  completed,
}

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  handshaking,
  ready,
  reconnecting,
  error,
}
```

---

## Licencia

Este paquete es propietario y su uso está restringido según los términos de la licencia del proyecto.

## Soporte

Para reportar problemas o solicitar nuevas características, contacte al equipo de desarrollo del proyecto principal.