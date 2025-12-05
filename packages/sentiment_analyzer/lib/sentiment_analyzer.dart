library sentiment_analyzer;

export 'src/presentation/calibration/widgets/calibration_screen.dart';
export 'src/presentation/analysis/widgets/analysis_overlay.dart';
export 'src/presentation/analysis/widgets/floating_menu.dart';
export 'src/presentation/notifications/widgets/notification_bell.dart';
export 'src/presentation/notifications/widgets/notification_modal.dart';
export 'src/presentation/notifications/widgets/video_player_modal.dart';

export 'src/data/interfaces/network_interface.dart';
export 'src/data/models/analysis_frame.dart';
export 'src/data/models/calibration_result.dart';
export 'src/data/models/intervention_event.dart';
export 'src/data/models/user_config.dart';
export 'src/data/services/calibration_storage.dart';
export 'src/data/services/session_service.dart';
export 'src/data/services/notification_service.dart';

export 'src/core/logic/state_aggregator.dart' show CombinedState;
export 'src/core/logic/drowsiness_analyzer.dart' show DrowsinessResult;
export 'src/core/logic/attention_analyzer.dart' show AttentionResult;