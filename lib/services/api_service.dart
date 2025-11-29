class ApiService {
  // Minimal placeholder for remote API interactions used by the app
  Future<Map<String, dynamic>> analyzeFrame(List<int> bytes) async {
    return {'status': 'ok'};
  }

  /// Check server status. Returns a small JSON-like map.
  Future<Map<String, dynamic>> checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'status': 'online'};
  }
}
