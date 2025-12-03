
# Cliente de Monitoreo Cognitivo en Tiempo Real

## 1. Descripción del Proyecto

`simulated_app` es el cliente móvil de una arquitectura de microservicios distribuida, diseñado para el monitoreo cognitivo en tiempo real. La aplicación, desarrollada en Flutter/Dart, se encarga de la captura, el procesamiento local y la transmisión continua de datos biométricos faciales. Su función principal es analizar y cuantificar indicadores de estado cognitivo como la emoción, la somnolencia y el nivel de atención, transmitiendo los resultados a un backend para su posterior análisis y almacenamiento.

Este documento constituye la base para la documentación de la implementación del cliente, detallando su arquitectura, la lógica de los agentes de análisis, la pila tecnológica y los protocolos de comunicación.

---

## 2. Arquitectura de la Aplicación Móvil

### 2.1. Estrategia Arquitectónica: Arquitectura Hexagonal (Clean Architecture)

La aplicación y su subsistema de análisis (`sentiment_analyzer`) están estructurados siguiendo los principios de la **Arquitectura Hexagonal (Clean Architecture)**. Este enfoque garantiza una estricta separación de preocupaciones, desacoplando la lógica de negocio de los detalles de la interfaz de usuario y la infraestructura externa. Esta separación maximiza la mantenibilidad, la testeabilidad y la portabilidad del código.

La estructura se divide en tres capas principales:

*   **Capa de Dominio (Core Logic):** Representa el núcleo del sistema. Contiene los modelos de datos (`/lib/core/models`), las reglas de negocio y la lógica pura de los agentes analizadores. Esta capa es completamente independiente de cualquier framework de UI o servicio externo, lo que permite que su lógica sea reutilizable en cualquier entorno Dart.

*   **Capa de Presentación (UI/Widgets):** Responsable de la visualización de datos y la interacción con el usuario. Se encuentra en el directorio `/lib/features`, donde cada funcionalidad tiene su propia carpeta de presentación. Esta capa implementa el patrón de diseño **Model-View-ViewModel (MVVM)** para la gestión del estado, separando la lógica de la vista (Widgets) del estado y las acciones (ViewModels).

*   **Capa de Infraestructura/Datos (Services/Network):** Contiene la implementación de detalles técnicos y la comunicación con el mundo exterior. Esto incluye la lógica de captura de la cámara, los clientes de red para la comunicación HTTP y WebSocket (`/lib/core/network`), y el acceso a almacenamiento local. Esta capa depende de la capa de Dominio, implementando las interfaces (puertos) que esta define.

### 2.2. Patrones de Integración

El cliente se integra con la arquitectura de microservicios del backend a través de un **API Gateway**. Este actúa como un punto de entrada único, simplificando la comunicación y la seguridad. Las interacciones se gestionan mediante dos protocolos distintos, seleccionados según la naturaleza de la comunicación (ver Sección 4).

---

## 3. Implementación Central: El Subsistema de Agentes `sentiment_analyzer`

El paquete local `packages/sentiment_analyzer` encapsula toda la lógica de percepción y análisis cognitivo en el dispositivo.

### 3.1. Pila Tecnológica de Captura y Procesamiento

*   **Plataforma/Lenguaje:** Flutter (v3.x) / Dart (v3.x).
*   **Detección Facial y Malla Facial (Face Mesh):** Se utilizan librerías de visión por computador para procesar el stream de la cámara en tiempo real. Para cada frame, se extrae una malla facial de alta densidad, compuesta por más de 468 puntos de referencia faciales (landmarks). Estos landmarks son las entradas para los algoritmos de análisis.
*   **Modelos de Inferencia:** Para la clasificación de emociones, se emplea un modelo de **TensorFlow Lite (TFLite)** pre-entrenado (`emotion_model.tflite`), ubicado en `packages/sentiment_analyzer/assets/`. Este enfoque de *edge computing* asegura que los datos faciales sensibles se procesen localmente en el dispositivo, mejorando la privacidad y reduciendo la latencia.

### 3.2. Configuración para Captura de Biométricos

La inicialización del subsistema de captura requiere una configuración precisa del hardware para optimizar el rendimiento:
*   **Selección de Cámara:** Se utiliza exclusivamente la cámara frontal del dispositivo.
*   **Resolución y Formato del Stream:** Se configura un formato de stream de video y una resolución que equilibren la calidad de la imagen para la detección de landmarks y el rendimiento del procesamiento, evitando la sobrecarga de la CPU y manteniendo una alta tasa de frames por segundo (FPS) para un monitoreo fluido.

### 3.3. Lógica de Agentes y Extracción de Características

Los analizadores lógicos procesan los 468+ landmarks faciales para extraer características biométricas clave.

*   **Detección de Somnolencia (Eye Aspect Ratio - EAR):**
    *   **Algoritmo:** Se implementa el algoritmo **Eye Aspect Ratio (EAR)**, que calcula una proporción basada en las distancias entre los landmarks verticales y horizontales de cada ojo. Un valor de EAR bajo indica que el ojo está cerrado.
    *   **Lógica de Detección:** Un contador de frames monitorea el tiempo durante el cual el EAR del usuario cae por debajo de un umbral personalizado (establecido durante la calibración). Si el estado de "ojo cerrado" persiste durante un número de frames consecutivos que supera un umbral de tiempo predefinido, se genera un evento de somnolencia.

*   **Análisis de Atención (Head Pose Estimation):**
    *   **Algoritmo:** Se utiliza un algoritmo de **Estimación de Postura de la Cabeza (Head Pose Estimation)** para calcular los ángulos de Euler (Yaw, Pitch, Roll) a partir de un subconjunto de landmarks faciales.
    *   **Lógica de Detección:** El sistema mide la desviación de estos ángulos con respecto a una postura "neutral" o "atenta" establecida durante la calibración. Si los ángulos de Yaw (giro horizontal) o Pitch (inclinación vertical) superan un umbral de desviación definido, se infiere una pérdida de atención o una distracción visual.

*   **Protocolo de Calibración:**
    *   **Propósito:** Antes de iniciar una sesión de monitoreo, es obligatorio realizar una fase de **Calibración Inicial**. Este proceso es esencial para la precisión del sistema, ya que establece los valores basales personalizados para cada usuario y condición de iluminación.
    *   **Implementación:** Durante la calibración, el usuario debe mantener una postura neutral mirando a la cámara. El sistema recopila datos durante varios segundos y calcula los umbrales promedio para el EAR (ojos abiertos), el MAR (Mouth Aspect Ratio, para detectar bostezos) y los ángulos de la cabeza. Estos umbrales se utilizan durante toda la sesión de monitoreo para normalizar las detecciones.

---

## 4. Protocolo de Comunicación Asíncrona con el Backend

### 4.1. Implementación del Servicio: `AppNetworkService`

La comunicación con el backend se gestiona a través de los servicios definidos en `/lib/core/network/`, que encapsulan la lógica de conexión y el manejo de protocolos.

### 4.2. Contraste de Protocolos: HTTP/REST vs. WebSockets

El cliente emplea una estrategia de comunicación dual para optimizar la eficiencia y la latencia:

*   **HTTP/REST:** Se utiliza para transacciones de baja frecuencia y naturaleza síncrona, como la autenticación de usuarios, la gestión de perfiles y el inicio/fin de sesiones de monitoreo.
*   **WebSockets:** Se emplea para la transmisión de alta frecuencia de los `BiometricFrameModel`. Esta elección responde a la necesidad de una comunicación **Event-Driven** de baja latencia, fundamental para el monitoreo en tiempo real. El canal WebSocket permanece abierto durante toda la sesión, permitiendo un flujo de datos bidireccional y continuo desde el cliente hacia el `monitoring_service` del backend.

### 4.3. Estructura del Payload: `BiometricFrameModel`

Cada paquete de datos transmitido a través del WebSocket sigue la estructura del `BiometricFrameModel`, definido en `/lib/core/models/biometric_frame_model.dart`. Este payload está optimizado para contener toda la información relevante de un único instante de tiempo.

**Formato del Payload (JSON):**
```json
{
  "sessionId": "string",
  "timestamp": "integer (unix_epoch_milliseconds)",
  "ear": "double",
  "mar": "double",
  "headPose": {
    "yaw": "double",
    "pitch": "double",
    "roll": "double"
  },
  "emotion": "string"
}
```
*   `sessionId`: Identificador único de la sesión de monitoreo.
*   `timestamp`: Marca de tiempo precisa de la captura del frame.
*   `ear`: Valor calculado del Eye Aspect Ratio.
*   `mar`: Valor calculado del Mouth Aspect Ratio.
*   `headPose`: Objeto que contiene los ángulos de la cabeza.
*   `emotion`: Predicción de la emoción clasificada por el modelo TFLite.

---

## 5. Requisitos e Instrucciones de Despliegue

### 5.1. Requisitos de Software

*   Flutter SDK: Versión 3.19.0 o superior.
*   Dart SDK: Versión 3.3.0 o superior.
*   Entorno de desarrollo configurado para Android (Android Studio) o iOS (Xcode).
*   Un dispositivo físico con cámara frontal es recomendado para un rendimiento óptimo.

### 5.2. Instrucciones de Instalación y Ejecución

1.  **Clonar el Repositorio:**
    ```bash
    git clone <URL_DEL_REPOSITORIO>
    cd simulated_app
    ```

2.  **Instalar Dependencias:**
    Ejecute el siguiente comando para descargar todas las dependencias del proyecto especificadas en `pubspec.yaml`.
    ```bash
    flutter pub get
    ```

3.  **Configurar Variables de Entorno (si aplica):**
    Si el proyecto requiere claves de API o URLs de backend, cree un archivo `.env` en la raíz del proyecto y defina las variables según el archivo de ejemplo `.env.example`.

4.  **Ejecutar la Aplicación en Modo Desarrollo:**
    Conecte un dispositivo o inicie un emulador y ejecute el siguiente comando:
    ```bash
    flutter run
    ```
