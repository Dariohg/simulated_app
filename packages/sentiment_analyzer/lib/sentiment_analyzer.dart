library sentiment_analyzer;

// Exportar UI Principal
export 'src/sentiment_analysis_manager.dart';

// Exportar UI de Calibración
export 'src/presentation/calibration/widgets/calibration_screen.dart';

// Exportar Modelos y Estados Lógicos
export 'src/core/logic/state_aggregator.dart' show CombinedState;
export 'src/core/logic/session_manager.dart' show SessionManager;

// IMPORTANTE: Exportar el modelo de calibración desde su nueva ubicación
export 'src/data/models/calibration_result.dart';

// Exportar Interfaces y Storage
export 'src/data/interfaces/network_interface.dart';
export 'src/data/services/calibration_storage.dart';