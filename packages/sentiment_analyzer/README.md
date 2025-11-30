# Sentiment Analyzer - Especificaciones de Comunicacion

## Endpoints HTTP (via API Gateway)

Base URL: `{GATEWAY_URL}` (ej: `http://hdbyfeygfrey:3000`)

Header requerido en todas las peticiones:
```
Authorization: Bearer {API_KEY}
```

---

### Sesiones

#### Crear sesion
```
POST /sessions/
```
Body:
```json
{
  "user_id": 12345,
  "disability_type": "none",
  "cognitive_analysis_enabled": true
}
```
Response:
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "activa",
  "created_at": "2025-11-29T10:00:00.000Z"
}
```

#### Obtener sesion
```
GET /sessions/{session_id}
```
Response:
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "activa",
  "current_activity": {
    "external_activity_id": 101,
    "title": "Leccion de matematicas",
    "started_at": "2025-11-29T10:05:00.000Z"
  }
}
```

#### Heartbeat
```
POST /sessions/{session_id}/heartbeat
```
Body: `{}`

Response:
```json
{
  "status": "ok",
  "last_heartbeat_at": "2025-11-29T10:05:30.000Z"
}
```

#### Pausar sesion
```
POST /sessions/{session_id}/pause
```
Body: `{}`

Response:
```json
{
  "status": "pausada"
}
```

#### Reanudar sesion
```
POST /sessions/{session_id}/resume
```
Body: `{}`

Response:
```json
{
  "status": "activa"
}
```

#### Finalizar sesion
```
DELETE /sessions/{session_id}
```
Response:
```json
{
  "status": "finalizada"
}
```

---

### Actividades

#### Iniciar actividad
```
POST /sessions/{session_id}/activity/start
```
Body:
```json
{
  "external_activity_id": 101,
  "title": "Leccion de matematicas",
  "subtitle": "Fracciones basicas",
  "content": "Contenido de la leccion...",
  "activity_type": "leccion"
}
```
Response:
```json
{
  "status": "activity_started"
}
```

#### Completar actividad
```
POST /sessions/{session_id}/activity/complete
```
Body:
```json
{
  "external_activity_id": 101,
  "feedback": {
    "rating": 5,
    "comments": "Muy util"
  }
}
```
Response:
```json
{
  "status": "completada"
}
```

#### Abandonar actividad
```
POST /sessions/{session_id}/activity/abandon
```
Body:
```json
{
  "external_activity_id": 101
}
```
Response:
```json
{
  "status": "abandonada"
}
```

---

### Configuracion

#### Actualizar configuracion
```
POST /sessions/{session_id}/config
```
Body:
```json
{
  "cognitive_analysis_enabled": true,
  "text_notifications": true,
  "video_suggestions": true,
  "vibration_alerts": true,
  "pause_suggestions": true
}
```
Response:
```json
{
  "status": "ok"
}
```

---

## WebSocket (Monitoring Service)

Conexion: `ws://{MONITORING_HOST}:3008/ws/{session_id}`

### Frame enviado (Flutter -> Monitoring)

Frecuencia: 1 frame por segundo

```json
{
  "metadata": {
    "user_id": 12345,
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "external_activity_id": 101,
    "timestamp": "2025-11-29T10:05:23.456Z"
  },
  "analisis_sentimiento": {
    "emocion_principal": {
      "nombre": "Happiness",
      "confianza": 0.78,
      "estado_cognitivo": "entendiendo"
    },
    "desglose_emociones": [
      {"emocion": "Happiness", "confianza": 78.0},
      {"emocion": "Neutral", "confianza": 15.0},
      {"emocion": "Surprise", "confianza": 5.0},
      {"emocion": "Anger", "confianza": 0.5},
      {"emocion": "Contempt", "confianza": 0.5},
      {"emocion": "Disgust", "confianza": 0.2},
      {"emocion": "Fear", "confianza": 0.3},
      {"emocion": "Sadness", "confianza": 0.5}
    ]
  },
  "datos_biometricos": {
    "atencion": {
      "mirando_pantalla": true,
      "orientacion_cabeza": {
        "pitch": 4.5,
        "yaw": -1.2
      }
    },
    "somnolencia": {
      "esta_durmiendo": false,
      "apertura_ojos_ear": 0.32
    },
    "rostro_detectado": true
  }
}
```

### Respuesta de intervencion (Monitoring -> Flutter)

Solo se envia cuando el modelo ML detecta necesidad de intervencion:

```json
{
  "intervention_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "type": "instruction",
  "confidence": 0.82
}
```

Tipos de intervencion:
- `vibration`: Alerta por vibracion
- `instruction`: Mostrar ayuda o video
- `pause`: Sugerir descanso

---

## AMQP (RabbitMQ)

### Cola: monitoring_events

Publicado por: Monitoring Service
Consumido por: Recommendation Service

```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": 12345,
  "external_activity_id": 101,
  "evento_cognitivo": "frustracion",
  "accion_sugerida": "instruction",
  "precision_cognitiva": 0.65,
  "confianza": 0.82,
  "contexto": {
    "precision_cognitiva": 0.65,
    "intentos_previos": 1,
    "tiempo_en_estado": 30
  },
  "timestamp": 1732878323456
}
```

Valores de evento_cognitivo:
- `desatencion`: Usuario no presta atencion
- `frustracion`: Usuario frustrado o confundido
- `cansancio_cognitivo`: Usuario cansado mentalmente

### Cola: recommendations.session.{session_id}

Publicado por: Recommendation Service
Consumido por: Flutter (via AMQP directo)

```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": 12345,
  "accion": "mostrar_video",
  "contenido": {
    "tipo": "video",
    "url": "https://example.com/video.mp4",
    "titulo": "Repaso de fracciones"
  },
  "prioridad": "alta",
  "timestamp": 1732878325000
}
```

Valores de accion:
- `nada`: Sin accion requerida
- `vibrar`: Enviar vibracion al dispositivo
- `mostrar_texto`: Mostrar mensaje de ayuda
- `mostrar_video`: Mostrar video explicativo
- `sugerir_pausa`: Recomendar descanso

---

## Campos del Frame Biometrico

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| user_id | int | ID del usuario |
| session_id | UUID | ID de sesion del Session Service |
| external_activity_id | int | ID de la actividad actual |
| timestamp | ISO 8601 | Momento de captura |
| emocion_principal.nombre | string | Emocion dominante |
| emocion_principal.confianza | float | Confianza 0-1 |
| emocion_principal.estado_cognitivo | string | entendiendo, neutral, confundido |
| desglose_emociones | array | 8 emociones con confianza 0-100 |
| mirando_pantalla | bool | Si mira la pantalla |
| orientacion_cabeza.pitch | float | Inclinacion vertical (grados) |
| orientacion_cabeza.yaw | float | Rotacion horizontal (grados) |
| esta_durmiendo | bool | Deteccion de sueno |
| apertura_ojos_ear | float | Eye Aspect Ratio 0-1 |
| rostro_detectado | bool | Si se detecto rostro |