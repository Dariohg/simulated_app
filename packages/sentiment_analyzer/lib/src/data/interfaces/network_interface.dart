abstract class SentimentNetworkInterface {
  Future<void> sendSessionStart(int userId);
  Future<void> sendSessionEnd(int userId);
  Future<void> sendHeartbeat(int userId);
  Future<void> sendAnalysisData(Map<String, dynamic> data);
}