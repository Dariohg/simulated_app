library sentiment_analyzer;

// Lógica Principal
export 'src/sentiment_analysis_manager.dart';

// Modelos
export 'src/logic/state_aggregator.dart' show CombinedState;
export 'src/calibration/calibration_service.dart' show CalibrationResult;

// Almacenamiento y Calibración
export 'src/calibration/calibration_storage.dart';
export 'src/calibration/calibration.dart';

// Interfaces de Servicio
export 'src/services/network_interface.dart';