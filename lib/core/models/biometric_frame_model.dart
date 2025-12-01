class BiometricFrameModel {
  final String timestamp;
  final Map<String, dynamic> emocionPrincipal;
  final List<Map<String, dynamic>> desgloseEmociones;
  final Map<String, dynamic> atencion;
  final Map<String, dynamic> somnolencia;
  final bool rostroDetectado;

  BiometricFrameModel({
    required this.timestamp,
    required this.emocionPrincipal,
    required this.desgloseEmociones,
    required this.atencion,
    required this.somnolencia,
    required this.rostroDetectado,
  });
}