import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:splitwise_clone/db.dart';
import 'package:splitwise_clone/api.dart';

Middleware dbConnectionCheck() {
  final dbHelper = DatabaseHelper();
  return (Handler handler) {
    return (Request request) async {
      await dbHelper.ensureConnected();
      return await handler(request);
    };
  };
}

void main() async {
  // Initialize Database Connection
  final dbHelper = DatabaseHelper();
  await dbHelper.connect();

  // Load port configuration
  int port = 3000;
  final envPort = Platform.environment['PORT'];
  if (envPort != null) {
    port = int.tryParse(envPort) ?? port;
  } else {
    try {
      final file = File('config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final config = jsonDecode(content);
        port = config['port'] ?? port;
      }
    } catch (e) {
      print("Could not load server port from config.json, using default: $e");
    }
  }

  // Set up API routes and middleware pipeline
  final apiService = ApiService();

  // Set up static files handler if build directory exists
  Handler staticFilesHandler;
  if (await Directory('build/web').exists()) {
    final staticHandler = createStaticHandler('build/web', defaultDocument: 'index.html');
    staticFilesHandler = (Request request) async {
      final response = await staticHandler(request);
      if (response.statusCode == 404 && !request.url.path.startsWith('api')) {
        // Fallback for SPA routing: serve index.html for any sub-routes except APIs
        return await staticHandler(request.change(path: ''));
      }
      return response;
    };
  } else {
    staticFilesHandler = (Request request) => Response.notFound('Not Found');
  }

  final cascade = Cascade()
      .add(apiService.router.call)
      .add(staticFilesHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(dbConnectionCheck())
      .addHandler(cascade.handler);

  // Start Server
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Split-Buddy Backend Server listening on http://0.0.0.0:${server.port}');
}
