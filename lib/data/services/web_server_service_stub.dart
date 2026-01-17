import 'dart:async';
import '../../core/utils/logger.dart';

/// Stub implementation for web platform
/// Web server cannot run on web platform - this is a no-op
class WebServerService {
  static const String _tag = 'WebServerService';

  final _statusController = StreamController<WebServerStatus>.broadcast();

  Stream<WebServerStatus> get statusStream => _statusController.stream;

  final WebServerStatus _status = const WebServerStatus(
    isRunning: false,
    url: null,
    ipAddress: null,
    port: 0,
    error: 'Web server is not available on web platform',
  );

  WebServerStatus get status => _status;

  Future<bool> startServer({int port = 8080}) async {
    AppLogger.warning('Web server cannot run on web platform', _tag);
    return false;
  }

  Future<void> stopServer() async {
    // No-op
  }

  void dispose() {
    _statusController.close();
  }
}

/// Status of the web server
class WebServerStatus {
  final bool isRunning;
  final String? url;
  final String? ipAddress;
  final int port;
  final String? error;

  const WebServerStatus({
    required this.isRunning,
    required this.url,
    required this.ipAddress,
    required this.port,
    this.error,
  });
}
