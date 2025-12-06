# Simulated App - Cliente de Monitoreo Cognitivo

**Repositorio del Cliente:** [https://github.com/Dariohg/simulated_app.git](https://github.com/Dariohg/simulated_app.git)  
**Repositorio del Backend (API):** [https://github.com/Crisgod112/Example_test](https://github.com/Crisgod112/Example_test)

## 1. Descripción del Proyecto

Simulated App es una aplicación móvil desarrollada en **Flutter** que sirve como entorno de ejecución y validación para el motor de análisis biométrico `sentiment_analyzer`. La aplicación simula una plataforma educativa donde se monitorea en tiempo real el estado cognitivo (atención, somnolencia, emoción) del usuario a través de la cámara frontal, sin almacenar video en el servidor.

El sistema implementa una arquitectura distribuida donde el procesamiento pesado de visión por computadora ocurre en el dispositivo (Edge AI), enviando únicamente metadatos de telemetría ligera al servidor para su análisis longitudinal y respuesta inmediata (intervenciones).


## 2. Funcionalidades del Cliente

* **Perfilado de Usuarios:** Configuración de sesiones adaptadas a condiciones específicas.
* **Simulación de Actividades:** Módulos interactivos (Lectura, Cálculo, Seguimiento Visual) diseñados para provocar respuestas cognitivas medibles.
* **Feedback en Tiempo Real:** Sistema de superposición (Overlay) que presenta métricas de depuración biométrica sobre la actividad en curso.
* **Gestión de Intervenciones:** Recepción y ejecución de comandos remotos (WebSocket) para mostrar alertas, pausas o contenido multimedia terapéutico.


## 3. Arquitectura de Comunicación

La aplicación actúa como un cliente híbrido que utiliza REST para la gestión transaccional y WebSockets para la transmisión de telemetría de alta frecuencia.


### Especificación de la API

La aplicación requiere un backend compatible con los siguientes contratos de interfaz (consulte el [repositorio de la API](https://github.com/Crisgod112/Example_test) para los esquemas JSON detallados):

#### Endpoints REST (Control)
* **POST** `/sessions/`: Inicializa una nueva sesión de monitoreo y devuelve un `session_id`.
* **POST** `/sessions/{id}/activity/start`: Registra el inicio de una actividad específica y devuelve un `activity_uuid` para el canal de WebSocket.
* **POST** `/activities/{uuid}/complete`: Cierra el ciclo de vida de una actividad con métricas de rendimiento.

#### Canal WebSocket (Telemetría)
* **URL:** `ws://{host}/ws/{sessionId}/{activityUuid}`
* **Protocolo:** Envío de frames JSON a ~5Hz y escucha asíncrona de eventos de recomendación.

## 4. Guía de Instalación y Despliegue

### Requisitos Previos
* Flutter SDK: 3.0.0 o superior.
* Dispositivo Físico: Android (API 21+) o iOS (12.0+). *Nota: Los simuladores no soportan la cámara adecuadamente para este análisis.*
* Red: Conexión estable para la comunicación con la API de prueba.

### Configuración del Entorno

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/Dariohg/simulated_app.git](https://github.com/Dariohg/simulated_app.git)
    cd simulated_app
    ```

2.  **Configurar Variables de Entorno:**
    Duplique el archivo de ejemplo y renombre a `.env`. Defina la URL donde se está ejecutando la API `Example_test`.
    ```properties
    API_GATEWAY_URL=http://<IP_DE_SU_SERVIDOR>:3000
    API_TOKEN=token_de_acceso_desarrollo
    ```

3.  **Instalación de Dependencias:**
    El proyecto utiliza una arquitectura monorepo híbrida. Instale las dependencias en orden:
    ```bash
    # 1. Instalar dependencias del paquete de análisis
    cd packages/sentiment_analyzer
    flutter pub get

    # 2. Instalar dependencias de la aplicación principal
    cd ../..
    flutter pub get
    ```

4.  **Ejecución:**
    ```bash
    flutter run
    ```

## 5. Estructura del Proyecto

* `lib/core`: Capa de infraestructura (Cliente HTTP, WebSocket Manager, Configuración).
* `lib/features`: Módulos de funcionalidad (Home, Activity, Calibration).
* `packages/sentiment_analyzer`: Módulo de visión por computadora aislado.

---
© 2024 Simulated App Team. Documentación confidencial para desarrollo interno.