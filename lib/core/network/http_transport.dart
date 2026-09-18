import 'dart:convert';
import 'dart:io';

/// A minimal, vendor-neutral HTTP GET transport seam.
///
/// This exists so that a vendor-specific [FxRateProvider] implementation
/// (see `lib/core/fx/exchangerate_api_fx_rate_provider.dart`, Checkpoint
/// 9.4) never talks to `dart:io` directly -- it depends on this small
/// interface instead, which tests substitute with a hand-written fake
/// implementation so every FX provider test stays deterministic and
/// fully offline (CP9.4: "Tests MUST be deterministic and offline. No
/// live internet tests."). This is intentionally the *only* thing this
/// seam does -- no retries, no JSON handling, no FX-specific error
/// mapping. Keeping it this small is deliberate (CP9.4's "Speed Rule":
/// no elaborate generic network framework).
///
/// # Why `dart:io.HttpClient` rather than a new package dependency
///
/// This project's mandated target platforms are Android/iOS (ADR-001);
/// nothing in this codebase targets Flutter Web today (Drift is wired
/// through `NativeDatabase`, a native-only implementation -- see
/// `lib/core/database/connection/native_connection.dart` -- and
/// `sqlite3_flutter_libs` itself is not web-compatible). `dart:io` is a
/// Flutter/Dart SDK built-in on those platforms, so this seam needs
/// **no new pubspec dependency** -- see CP9.4's own Dependency Rule
/// ("if an appropriate HTTP client is already present, use it... do NOT
/// silently add packages"). Dart/Flutter already ships an appropriate
/// client here; nothing further was required, so no dependency approval
/// request was needed for this checkpoint.
///
/// If a Flutter Web target is ever added, this is the one seam that
/// would need a second implementation (`dart:io` is unavailable on
/// web -- a `package:http`-backed implementation, which *is*
/// web-compatible, would be the natural replacement then) -- nothing
/// above [HttpTransport], including [ExchangeRateApiFxRateProvider],
/// would need to change.
abstract class HttpTransport {
  /// Performs an HTTP GET against [url], returning the raw status code
  /// and response body as-received (no decoding beyond UTF-8 text
  /// decoding). [timeout] bounds the *entire* operation (connect, send,
  /// receive, and read the full body) as a single deadline.
  ///
  /// Implementations throw ordinary Dart exceptions (`SocketException`,
  /// `TimeoutException`, `HandshakeException`, `HttpException`, ...) on
  /// any transport-level failure -- they do NOT reduce failures to any
  /// FX-domain type themselves. Mapping those exceptions to
  /// `FxRateProviderFailure` is the vendor adapter's job (see
  /// `ExchangeRateApiFxRateProvider.fetchRates`), not this transport's --
  /// that keeps this seam reusable by any future vendor adapter without
  /// baking in FX-specific error semantics.
  Future<HttpTransportResponse> get(Uri url, {required Duration timeout});
}

/// The raw result of an [HttpTransport.get] call. No interpretation of
/// [body] (JSON or otherwise) happens at this layer.
class HttpTransportResponse {
  const HttpTransportResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// The production [HttpTransport], backed directly by `dart:io.HttpClient`.
/// See the class doc on [HttpTransport] for why no third-party HTTP
/// package is used.
///
/// Deliberately stateless/cheap to construct (a fresh `HttpClient` per
/// call, closed immediately after) -- see CP9.4 Task J: constructing this
/// (e.g. via Riverpod DI) must never itself perform or schedule any
/// network I/O, only [get] does.
class IoHttpTransport implements HttpTransport {
  @override
  Future<HttpTransportResponse> get(Uri url, {required Duration timeout}) {
    return _performGet(url).timeout(timeout);
  }

  Future<HttpTransportResponse> _performGet(Uri url) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      return HttpTransportResponse(statusCode: response.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }
}
