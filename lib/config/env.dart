// ignore_for_file: avoid_print

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ANSI color helpers (visible in terminal / flutter run; no-op in release)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _C {
  static const r = '\x1b[0m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';
  static const red = '\x1b[31m';
  static const green = '\x1b[32m';
}

// ─────────────────────────────────────────────────────────────────────────────
// AppEnvironment
// ─────────────────────────────────────────────────────────────────────────────

enum AppEnvironment { development, production }

// ─────────────────────────────────────────────────────────────────────────────
// EnvValidationError
// Thrown when one or more required env vars are missing or invalid.
// ─────────────────────────────────────────────────────────────────────────────

class EnvValidationError extends Error {
  final List<String> issues;

  EnvValidationError(this.issues);

  @override
  String toString() {
    final lines = issues.map((raw) {
      final colon = raw.indexOf(':');
      final field = colon > 0 ? raw.substring(0, colon) : raw;
      final msg = colon > 0 ? raw.substring(colon + 1).trim() : '';
      return '  ${_C.red}✗${_C.r} ${_C.bold}$field${_C.r}  ${_C.dim}$msg${_C.r}';
    }).join('\n');

    return '\n${_C.bold}${_C.red}Environment validation failed${_C.r}\n\n$lines\n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EnvField helpers  (inspired by Zod's z.string(), z.url(), z.enum())
// ─────────────────────────────────────────────────────────────────────────────

/// Validates that [value] is a non-empty string.
String? _validateString(String key, String? value) {
  if (value == null || value.trim().isEmpty) {
    return '$key: required string is missing or empty';
  }
  return null;
}

/// Validates that [value] is a well-formed http/https URL.
String? _validateUrl(String key, String? value) {
  final stringIssue = _validateString(key, value);
  if (stringIssue != null) return stringIssue;

  final uri = Uri.tryParse(value!);
  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
    return '$key: must be a valid http or https URL (got "$value")';
  }
  return null;
}

/// Validates that [value] matches one of the [allowed] values.
String? _validateEnum(String key, String? value, List<String> allowed) {
  final stringIssue = _validateString(key, value);
  if (stringIssue != null) return stringIssue;

  if (!allowed.contains(value)) {
    return '$key: must be one of [${allowed.join(', ')}] (got "$value")';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// EnvSchema
//
// Define every variable your app needs here.
// The static validate() method runs all checks and either:
//   • throws EnvValidationError listing every failing field  (hard stop)
//   • returns a validated Env instance ready for use
// ─────────────────────────────────────────────────────────────────────────────

class Env {
  /// Which environment is active.
  final AppEnvironment appEnv;

  /// Full base URL for the backend API (no trailing slash).
  final String apiBaseUrl;

  // Private constructor — only EnvSchema.validate() may produce an instance.
  const Env._({
    required this.appEnv,
    required this.apiBaseUrl,
  });

  bool get isDevelopment => appEnv == AppEnvironment.development;
  bool get isProduction => appEnv == AppEnvironment.production;

  @override
  String toString() => 'Env(appEnv: $appEnv, apiBaseUrl: $apiBaseUrl)';
}

// ─────────────────────────────────────────────────────────────────────────────
// EnvSchema — the validation schema (analogous to a Zod schema object)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class EnvSchema {
  /// Reads every variable from the loaded dotenv and validates it.
  ///
  /// Throws [EnvValidationError] if ANY field is missing or invalid.
  /// This is intentionally a hard crash — the app should not start
  /// with a broken environment.
  static Env validate() {
    final issues = <String>[];

    // ── APP_ENV ──────────────────────────────────────────────────────────────
    final rawAppEnv = dotenv.maybeGet('APP_ENV');
    final appEnvIssue = _validateEnum('APP_ENV', rawAppEnv, [
      'development',
      'production',
    ]);
    if (appEnvIssue != null) issues.add(appEnvIssue);

    // ── API_BASE_URL ──────────────────────────────────────────────────────────
    final rawApiBaseUrl = dotenv.maybeGet('API_BASE_URL');
    final apiUrlIssue = _validateUrl('API_BASE_URL', rawApiBaseUrl);
    if (apiUrlIssue != null) issues.add(apiUrlIssue);

    // ── Fail fast if any issues were found ───────────────────────────────────
    if (issues.isNotEmpty) {
      throw EnvValidationError(issues);
    }

    // ── Parse typed values ───────────────────────────────────────────────────
    final appEnv = rawAppEnv == 'production'
        ? AppEnvironment.production
        : AppEnvironment.development;

    return Env._(
      appEnv: appEnv,
      apiBaseUrl: rawApiBaseUrl!.trimRight().replaceAll(RegExp(r'/+$'), ''),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global singleton — set once in main() after successful validation.
// Access anywhere as:  Env.instance.apiBaseUrl
// ─────────────────────────────────────────────────────────────────────────────

Env? _envInstance;

extension EnvInstance on Env {
  static Env get instance {
    assert(
      _envInstance != null,
      'Env.instance accessed before EnvSchema.validate() was called. '
      'Call EnvLoader.load() inside main() before runApp().',
    );
    return _envInstance!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EnvLoader
// Loads the correct .env file for the current build flavor and validates it.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class EnvLoader {
  /// Determines the correct .env file from [flavor] (defaults to
  /// the compile-time dart-define `APP_FLAVOR`, falling back to 'development'),
  /// loads it via flutter_dotenv, validates it, and stores the result.
  ///
  /// Pass [flavor] explicitly in tests or when using `--dart-define`.
  ///
  /// ```dart
  /// // Run with production env:
  /// flutter run --dart-define=APP_FLAVOR=production
  ///
  /// // Or pass directly (e.g. from a flavored main_production.dart):
  /// await EnvLoader.load(flavor: 'production');
  /// ```
  static Future<Env> load({String? flavor}) async {
    // 1. Resolve flavor
    const compileFlavor = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'development',
    );
    final resolvedFlavor = flavor ?? compileFlavor;

    // 2. Map flavor → file name
    final fileName = switch (resolvedFlavor) {
      'production' => '.env.production',
      'development' => '.env.development',
      _ => throw ArgumentError(
        'Unknown APP_FLAVOR "$resolvedFlavor". '
        'Valid values: development, production.',
      ),
    };

    print('${_C.dim}[Env] loading $fileName …${_C.r}');

    // 3. Load the file (throws if the asset is missing from pubspec.yaml)
    try {
      await dotenv.load(fileName: fileName);
    } catch (e) {
      throw StateError(
        '[Env] Failed to load "$fileName". '
        'Make sure the file exists and is listed under flutter › assets '
        'in pubspec.yaml.\nOriginal error: $e',
      );
    }

    // 4. Validate — throws EnvValidationError with every missing/bad field
    final env = EnvSchema.validate();

    // 5. Store singleton
    _envInstance = env;

    print('${_C.green}✓${_C.r} ${_C.dim}[Env] $fileName loaded${_C.r}');
    return env;
  }
}
