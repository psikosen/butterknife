import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppLogger {
  static const _derivedTag = '[The 17 Commandments of Quality Code]';

  const AppLogger._();

  static void logDebug({
    required String filename,
    required String classname,
    required String function,
    required String systemSection,
    required String message,
    int? lineNumber,
    String method = 'NONE',
    String dbPhase = 'none',
  }) {
    _log(
      level: 'DEBUG',
      filename: filename,
      classname: classname,
      function: function,
      systemSection: systemSection,
      message: message,
      lineNumber: lineNumber,
      method: method,
      dbPhase: dbPhase,
    );
  }

  static void logInfo({
    required String filename,
    required String classname,
    required String function,
    required String systemSection,
    required String message,
    int? lineNumber,
    String method = 'NONE',
    String dbPhase = 'none',
  }) {
    _log(
      level: 'INFO',
      filename: filename,
      classname: classname,
      function: function,
      systemSection: systemSection,
      message: message,
      lineNumber: lineNumber,
      method: method,
      dbPhase: dbPhase,
    );
  }

  static void logError({
    required String filename,
    required String classname,
    required String function,
    required String systemSection,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    int? lineNumber,
    String method = 'NONE',
    String dbPhase = 'none',
  }) {
    _log(
      level: 'ERROR',
      filename: filename,
      classname: classname,
      function: function,
      systemSection: systemSection,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      lineNumber: lineNumber,
      method: method,
      dbPhase: dbPhase,
    );
  }

  static void _log({
    required String level,
    required String filename,
    required String classname,
    required String function,
    required String systemSection,
    required String message,
    String? error,
    String? stackTrace,
    int? lineNumber,
    String method = 'NONE',
    String dbPhase = 'none',
  }) {
    final payload = <String, dynamic>{
      'level': level,
      'filename': filename,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'classname': classname,
      'function': function,
      'system_section': systemSection,
      'line_num': lineNumber,
      'error': error,
      'stack_trace': stackTrace,
      'db_phase': dbPhase,
      'method': method,
      'message': message,
    };

    debugPrint(jsonEncode(payload));
    debugPrint('$_derivedTag $message');
  }
}
