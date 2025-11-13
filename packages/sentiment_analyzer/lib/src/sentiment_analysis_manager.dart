import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/face_mesh_view_model.dart';
import 'services/camera_service.dart';
import 'services/face_mesh_service.dart';
import 'services/network_service.dart';

/// Un widget invisible que gestiona el ciclo de vida del análisis de sentimientos.
///
/// Simplemente añade este widget al árbol de widgets (por ejemplo, en un Stack)
/// en la pantalla donde el análisis deba estar activo.
class SentimentAnalysisManager extends StatefulWidget {
  final String userId;
  final String lessonId;

  const SentimentAnalysisManager({
    super.key,
    required this.userId,
    required this.lessonId,
    // Aquí puedes añadir más parámetros, como callbacks:
    // final Function(String)? onEmotionDetected,
  });

  @override
  State<SentimentAnalysisManager> createState() =>
      _SentimentAnalysisManagerState();
}

class _SentimentAnalysisManagerState extends State<SentimentAnalysisManager> {
  // Aquí creamos los servicios. Vivirán mientras este widget viva.
  late final CameraService _cameraService;
  late final FaceMeshService _faceMeshService;
  late final NetworkService _networkService;
  late final FaceMeshViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    // 1. Instanciamos todos los servicios
    _cameraService = CameraService();
    _faceMeshService = FaceMeshService();
    _networkService = NetworkService(); // Pasará el userId y lessonId al JSON

    // 2. Creamos el ViewModel que los orquesta a todos
    _viewModel = FaceMeshViewModel(
      cameraService: _cameraService,
      faceMeshService: _faceMeshService,
      networkService: _networkService,
    );

    // NOTA: El ViewModel (gracias a su método 'initialize()')
    // se encargará automáticamente de pedir permisos de cámara,
    // encenderla y empezar el stream.
  }

  @override
  void dispose() {
    // 3. Cuando la App 1 quita este widget (sale de la lección),
    // limpiamos todo y apagamos la cámara.
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 4. El widget en sí es invisible.
    // Usamos un ChangeNotifierProvider para mantener vivo el ViewModel
    // sin necesidad de exponerlo al resto de la app.
    return ChangeNotifierProvider.value(
      value: _viewModel,
      // SizedBox.shrink() es un widget vacío que no ocupa espacio y dibuja nada.
      child: const SizedBox.shrink(),
    );
  }
}