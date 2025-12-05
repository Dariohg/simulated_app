# Sentiment Analyzer Package

**Versión:** 1.0.0+1  
**Tecnología:** Flutter / Dart / TensorFlow Lite  
**Compatibilidad:** Android (API 21+) & iOS (12.0+)

## 1. Visión General Técnica

El paquete `sentiment_analyzer` es un motor de inferencia biométrica autónomo diseñado para aplicaciones Flutter de alto rendimiento. Su arquitectura encapsula la complejidad del acceso a hardware (cámara), el procesamiento de imágenes en tiempo real y la inferencia de modelos de Deep Learning (Edge AI), exponiendo una API de alto nivel para el consumo de datos cognitivos y emocionales.

Este sistema opera localmente en el dispositivo para garantizar la privacidad del usuario y reducir la latencia, enviando únicamente metadatos de telemetría anonimizados al servidor.

![Arquitectura del Motor](assets/images/4.png)

## 2. Capacidades de Análisis

El motor procesa el flujo de video cuadro a cuadro para extraer cuatro vectores de información biométrica principales:

### 2.1. Geometría Facial (Face Mesh)
Utiliza una red neuronal liviana para mapear 468 puntos tridimensionales en el rostro del usuario. Esta malla permite normalizar la geometría independientemente de la distancia o el ángulo de la cámara, sirviendo como base para todos los cálculos posteriores.

### 2.2. Inferencia Emocional
Una Red Neuronal Convolucional (CNN) procesa la región de interés facial (ROI) para clasificar el estado emocional en 8 categorías discretas: *Neutral, Felicidad, Tristeza, Enojo, Miedo, Sorpresa, Disgusto y Desprecio*. Se aplica un algoritmo de suavizado temporal para reducir el ruido ("flickering") en la predicción.


### 2.3. Atención y Postura (Head Pose)
Mediante la resolución del problema PnP (Perspective-n-Point) sobre los landmarks faciales, se calculan los ángulos de Euler (Pitch, Yaw, Roll). Esto determina geométricamente si el vector de la mirada del usuario intersecta con el plano de la pantalla del dispositivo, permitiendo medir la atención visual efectiva.


### 2.4. Detección de Fatiga (EAR/MAR)
Se implementan algoritmos geométricos para calcular la Relación de Aspecto del Ojo (EAR) y de la Boca (MAR). Esto permite la detección determinista de eventos de fatiga como parpadeos lentos, cierre ocular prolongado (microsueños) y bostezos.


## 3. Instalación y Configuración

### Dependencias
Agregue el paquete a su archivo `pubspec.yaml`:

```yaml
dependencies:
  sentiment_analyzer:
    path: ./packages/sentiment_analyzer
  # Dependencias peer requeridas
  camera: ^0.11.0
  google_mlkit_face_mesh_detection: ^0.0.1
````

### Configuración Nativa

**Android (`AndroidManifest.xml`):**

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**iOS (`Info.plist`):**

```xml
<key>NSCameraUsageDescription</key>
<string>Requerido para el análisis biométrico facial en tiempo real.</string>
```

## 4\. Protocolo de Calibración

Para garantizar la fiabilidad de los datos, el paquete exige una fase de calibración inicial que establece la línea base fisiológica del usuario.

**Parámetros Calibrados:**

* **Umbral EAR Personal:** Ajusta la sensibilidad de detección de ojos cerrados según la anatomía del usuario.
* **Vector de Mirada Neutra:** Define el "centro" de atención para compensar la posición relativa con la que el usuario sostiene el dispositivo.
* **Iluminación Ambiental:** Valida que las condiciones de luz sean suficientes para la inferencia del modelo.

## 5\. Integración y Uso

### Inicialización

El widget `SentimentAnalysisManager` maneja el ciclo de vida completo (cámara, modelos, red). Debe insertarse en el árbol de widgets sobre la actividad a monitorear.

```dart
SentimentAnalysisManager(
  sessionManager: _sessionManager,
  externalActivityId: 'ACT_MATH_101',
  gatewayUrl: EnvConfig.websocketUrl,
  apiKey: EnvConfig.token,
  // Callbacks de eventos
  onStateChanged: (state) {
    // Acceso síncrono al estado local para depuración UI
    print("Estado actual: ${state.finalState}");
  },
  onInstructionReceived: (message) {
    // Manejo de instrucciones de texto del servidor
  },
)
```

### Modelo de Datos de Telemetría

El paquete genera y transmite objetos JSON estandarizados hacia el backend a través de WebSocket.

**Estructura del Frame (Cliente -\> Servidor):**

```json
{
  "metadata": {
    "timestamp": "2024-05-20T10:00:00Z",
    "session_id": "sess_001",
    "user_id": 123
  },
  "metrics": {
    "emotion": { "label": "concentrado", "confidence": 0.85 },
    "attention": { "is_looking": true, "pitch": 5.2, "yaw": -2.1 },
    "drowsiness": { "is_drowsy": false, "ear_value": 0.32 }
  }
}
```

## 6\. Componentes de UI Incluidos

El paquete provee componentes de interfaz optimizados ("Overlay") para no interferir con la carga cognitiva de la tarea principal:

* **Overlay de Depuración:** Visualización semitransparente de la malla facial y métricas crudas.
* **Menú Flotante (FAB):** Controles de sesión (Pausa/Reanudar, Recalibrar) y notificaciones pasivas.
* **Modales de Intervención:** Reproductores de video y diálogos de alerta pre-estilizados.

## 7\. Manejo de Errores y Resiliencia

* **Fallo de Red:** El sistema encola los eventos críticos y continúa el análisis local si se pierde la conexión WebSocket (Modo Offline).
* **Fallo de Cámara:** Gestiona reinicios automáticos del servicio de cámara en caso de interrupciones por el sistema operativo o cambios de ciclo de vida de la app.
* **Baja Confianza:** Descarta frames donde la calidad de detección facial es inferior al umbral confiable para evitar falsos positivos en los datos.

## 8\. Referencia de API Externa

Para la integración completa, este paquete requiere un backend que implemente los endpoints de sesión y el servidor de WebSockets. Consulte la documentación del servidor de prueba para más detalles sobre los contratos de datos:

**Repositorio de API:** [https://github.com/Crisgod112/Example\_test](https://github.com/Crisgod112/Example_test)

-----

**Nota:** El rendimiento de inferencia depende directamente de la capacidad de la GPU/NPU del dispositivo móvil. Se recomienda probar en dispositivos de gama media-alta para mantener 30 FPS estables.
