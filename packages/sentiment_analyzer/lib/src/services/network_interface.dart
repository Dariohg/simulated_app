/// Interfaz para delegar las peticiones HTTP a la aplicación principal.
/// El paquete usa esto para no depender de http o dio directamente.
abstract class SentimentNetworkInterface {
  /// Realiza una petición POST al backend.
  /// [endpoint]: La ruta, ej: '/sessions'
  /// [body]: Los datos a enviar.
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body);

  /// Realiza una petición DELETE al backend.
  Future<Map<String, dynamic>> delete(String endpoint);

  /// Opcional: Para peticiones GET si fueran necesarias.
  Future<Map<String, dynamic>> get(String endpoint);
}