import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static late final Logger _logger;
  static late final File _logFile;
  static bool _initialized = false;

  /// 🔧 Panggil ini sekali (misal di main.dart)
  static Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/app_log.txt');

    // Buat file kalau belum ada
    if (!(await _logFile.exists())) {
      await _logFile.create(recursive: true);
    }

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 3,
        lineLength: 80,
        colors: false, // disable warna untuk hasil file
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _FileAndConsoleOutput(_logFile),
      level: kReleaseMode ? Level.info : Level.debug,
    );

    _initialized = true;
  }

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  static Future<String> getLogFilePath() async => _logFile.path;

  static Future<void> clearLogs() async {
    if (await _logFile.exists()) {
      await _logFile.writeAsString('');
    }
  }
}

/// 🔹 Output ke file + console (debug)
class _FileAndConsoleOutput extends LogOutput {
  final File file;
  final _console = ConsoleOutput();

  _FileAndConsoleOutput(this.file);

  @override
  void output(OutputEvent event) {
    final text = event.lines.join('\n');

    // Tulis ke console hanya jika debug
    if (kDebugMode) {
      _console.output(event);
    }

    // Simpan ke file
    file.writeAsStringSync(
      '${DateTime.now().toIso8601String()} | $text\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
