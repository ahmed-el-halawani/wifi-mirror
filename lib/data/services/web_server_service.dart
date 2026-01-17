import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger.dart';

/// Service to serve the embedded web app over local WiFi network
/// Works on Mac, iOS, and Android platforms
class WebServerService {
  static const String _tag = 'WebServerService';

  HttpServer? _server;
  String? _localIpAddress;
  int _port = 8080;
  String? _webAppPath;

  /// Stream controller for server status
  final _statusController = StreamController<WebServerStatus>.broadcast();

  /// Stream of server status updates
  Stream<WebServerStatus> get statusStream => _statusController.stream;

  /// Current server status
  WebServerStatus _status = WebServerStatus(
    isRunning: false,
    url: null,
    ipAddress: null,
    port: 0,
  );

  WebServerStatus get status => _status;

  /// Get the local IP address of this device
  Future<String?> _getLocalIpAddress() async {
    if (_localIpAddress != null) return _localIpAddress;

    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Prefer WiFi interface addresses
            if (interface.name.toLowerCase().contains('wlan') ||
                interface.name.toLowerCase().contains('wifi') ||
                interface.name.toLowerCase().contains('en0') ||
                interface.name.toLowerCase().contains('en1')) {
              _localIpAddress = addr.address;
              AppLogger.info(
                'Found WiFi IP: $_localIpAddress on ${interface.name}',
                _tag,
              );
              return _localIpAddress;
            }
          }
        }
      }

      // Fallback to first non-loopback IPv4 address
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _localIpAddress = addr.address;
            AppLogger.info(
              'Using fallback IP: $_localIpAddress on ${interface.name}',
              _tag,
            );
            return _localIpAddress;
          }
        }
      }
    } catch (e, stack) {
      AppLogger.error('Failed to get local IP', e, stack, _tag);
    }

    return null;
  }

  /// Extract web app assets to a temporary directory for serving
  Future<String?> _prepareWebAppFiles() async {
    if (_webAppPath != null) {
      final dir = Directory(_webAppPath!);
      if (await dir.exists()) {
        // Check if index.html exists to verify integrity
        final indexFile = File('$_webAppPath/index.html');
        if (await indexFile.exists()) {
          return _webAppPath;
        }
      }
    }

    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final webAppDir = Directory('${tempDir.path}/web_app_server');

      // Create directory if needed
      if (await webAppDir.exists()) {
        // Clean up old files
        await webAppDir.delete(recursive: true);
      }
      await webAppDir.create(recursive: true);

      // Load the manifest file that lists all web app files
      List<String> webAppFiles = [];
      try {
        final manifestContent = await rootBundle.loadString(
          'assets/web_app/web_app_manifest.txt',
        );
        webAppFiles = manifestContent
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && line != 'web_app_manifest.txt')
            .toList();
        AppLogger.info(
          'Loaded manifest with ${webAppFiles.length} files',
          _tag,
        );
      } catch (e) {
        // Fallback: try to load essential files manually
        AppLogger.warning(
          'Could not load manifest, using fallback list: $e',
          _tag,
        );
        webAppFiles = [
          'index.html',
          'main.dart.js',
          'flutter.js',
          'flutter_bootstrap.js',
          'flutter_service_worker.js',
          'manifest.json',
          'version.json',
          'favicon.png',
        ];
      }

      if (webAppFiles.isEmpty) {
        AppLogger.error('No web app files found', null, null, _tag);
        return null;
      }

      // Copy each file to the temp directory
      int extractedCount = 0;
      for (final relativePath in webAppFiles) {
        try {
          final assetPath = 'assets/web_app/$relativePath';
          final targetFile = File('${webAppDir.path}/$relativePath');

          // Create parent directories
          await targetFile.parent.create(recursive: true);

          // Load and write asset
          final data = await rootBundle.load(assetPath);
          await targetFile.writeAsBytes(data.buffer.asUint8List());
          extractedCount++;
        } catch (e) {
          // Log but continue - some files might not be bundled
          AppLogger.warning('Could not extract: $relativePath - $e', _tag);
        }
      }

      AppLogger.info(
        'Extracted $extractedCount/${webAppFiles.length} web app files',
        _tag,
      );

      // Verify index.html exists
      final indexFile = File('${webAppDir.path}/index.html');
      if (!await indexFile.exists()) {
        AppLogger.error(
          'index.html not found after extraction',
          null,
          null,
          _tag,
        );
        return null;
      }

      _webAppPath = webAppDir.path;
      AppLogger.info('Web app extracted to: $_webAppPath', _tag);
      return _webAppPath;
    } catch (e, stack) {
      AppLogger.error('Failed to prepare web app files', e, stack, _tag);
      return null;
    }
  }

  /// Get MIME type for file extension
  String _getMimeType(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.html')) return 'text/html';
    if (ext.endsWith('.css')) return 'text/css';
    if (ext.endsWith('.js')) return 'application/javascript';
    if (ext.endsWith('.json')) return 'application/json';
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.svg')) return 'image/svg+xml';
    if (ext.endsWith('.ico')) return 'image/x-icon';
    if (ext.endsWith('.woff')) return 'font/woff';
    if (ext.endsWith('.woff2')) return 'font/woff2';
    if (ext.endsWith('.ttf')) return 'font/ttf';
    if (ext.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }

  /// Start the HTTP server
  Future<bool> startServer({int port = 8080}) async {
    if (kIsWeb) {
      AppLogger.warning('Web server cannot run on web platform', _tag);
      return false;
    }

    if (_server != null) {
      AppLogger.info('Server already running', _tag);
      return true;
    }

    try {
      _port = port;

      // Get local IP
      _localIpAddress = await _getLocalIpAddress();
      if (_localIpAddress == null) {
        AppLogger.error(
          'Could not determine local IP address',
          null,
          null,
          _tag,
        );
        _updateStatus(
          WebServerStatus(
            isRunning: false,
            url: null,
            ipAddress: null,
            port: _port,
            error: 'Could not determine local IP address',
          ),
        );
        return false;
      }

      // Prepare web app files
      final webAppPath = await _prepareWebAppFiles();
      if (webAppPath == null) {
        AppLogger.error('Could not prepare web app files', null, null, _tag);
        _updateStatus(
          WebServerStatus(
            isRunning: false,
            url: null,
            ipAddress: _localIpAddress,
            port: _port,
            error:
                'Could not prepare web app files. Make sure to run build_and_copy_web.sh first.',
          ),
        );
        return false;
      }

      // Try to bind to port, try alternatives if busy
      int attempts = 0;
      while (attempts < 10) {
        try {
          _server = await HttpServer.bind(
            InternetAddress.anyIPv4,
            _port,
            shared: true,
          );
          break;
        } catch (e) {
          if (e is SocketException && e.osError?.errorCode == 48) {
            // Port in use, try next
            _port++;
            attempts++;
          } else {
            rethrow;
          }
        }
      }

      if (_server == null) {
        throw Exception('Could not find available port');
      }

      AppLogger.info('Server started on $_localIpAddress:$_port', _tag);

      // Handle requests
      _server!.listen((request) => _handleRequest(request, webAppPath));

      // Update status
      _updateStatus(
        WebServerStatus(
          isRunning: true,
          url: 'http://$_localIpAddress:$_port',
          ipAddress: _localIpAddress,
          port: _port,
        ),
      );

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to start server', e, stack, _tag);
      _updateStatus(
        WebServerStatus(
          isRunning: false,
          url: null,
          ipAddress: _localIpAddress,
          port: _port,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  /// Handle HTTP request
  Future<void> _handleRequest(HttpRequest request, String webAppPath) async {
    try {
      // Get requested path
      var path = request.uri.path;
      if (path.isEmpty || path == '/') {
        path = '/index.html';
      }

      // Security: prevent directory traversal
      if (path.contains('..')) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
        return;
      }

      // Build file path
      final filePath = '$webAppPath$path';
      final file = File(filePath);

      if (await file.exists()) {
        // Set headers
        request.response.headers.contentType = ContentType.parse(
          _getMimeType(filePath),
        );

        // Enable CORS for local network access
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add(
          'Access-Control-Allow-Methods',
          'GET, OPTIONS',
        );
        request.response.headers.add('Access-Control-Allow-Headers', '*');

        // Serve file
        await request.response.addStream(file.openRead());
        await request.response.close();
      } else {
        // Try to serve index.html for SPA routing
        final indexFile = File('$webAppPath/index.html');
        if (await indexFile.exists()) {
          request.response.headers.contentType = ContentType.html;
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          await request.response.addStream(indexFile.openRead());
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('File not found: $path');
          await request.response.close();
        }
      }
    } catch (e, stack) {
      AppLogger.error('Error handling request: ${request.uri}', e, stack, _tag);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Internal server error');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Stop the HTTP server
  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
      _server = null;

      AppLogger.info('Server stopped', _tag);

      _updateStatus(
        WebServerStatus(
          isRunning: false,
          url: null,
          ipAddress: _localIpAddress,
          port: _port,
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to stop server', e, stack, _tag);
    }
  }

  /// Update status and notify listeners
  void _updateStatus(WebServerStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Dispose resources
  void dispose() {
    stopServer();
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
