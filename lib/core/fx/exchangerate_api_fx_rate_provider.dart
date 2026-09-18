import 'dart:convert';

import '../currency/currency_registry.dart';
import '../network/http_transport.dart';
import 'fx_rate.dart';
import 'fx_rate_parse_exception.dart';
import 'fx_rate_provider.dart';
import 'reference_fx_rate.dart';

/// [FxRateProvider] backed by ExchangeRate-API's "Open Access" endpoint
/// (`https://open.er-api.com/v6/latest/{BASE}`,
/// https://www.exchangerate-api.com/docs/free) -- Checkpoint 9.4's first
/// real (non-fake, non-in-memory) reference-rate vendor integration.
///
/// # Why this vendor -- see the CP9.4 report's "PROVIDER SELECTION"
/// section for the full comparison. In short: it is the only V1-suitable
/// candidate that (a) supports every currency in [CurrencyRegistry]'s
/// Beta 0 seed set including VND/KWD/MMK/LKR/NPR/BDT/QAR (several
/// well-known providers -- e.g. Frankfurter -- do not yet), (b) supports
/// an arbitrary requested base currency on its free tier (several other
/// well-known providers -- e.g. Open Exchange Rates, Fixer -- restrict
/// the free tier to a fixed USD/EUR base, which [FxRateProvider]'s own
/// contract, an arbitrary [baseCurrencyCode], cannot be satisfied by
/// without triangulating through a hidden second currency -- exactly the
/// kind of implicit-inversion/complexity CP9.4 prohibits), (c) needs no
/// API key at all (nothing to keep secret, no configuration boundary
/// required for V1), and (d) is HTTPS, documented, and states rates are
/// daily reference/indicative data (never described as an executable,
/// bank, or remittance rate) -- exactly the reference-rate framing
/// [ReferenceFxRate]/ADR-011 already require.
///
/// # Contract
///
/// Implements [FxRateProvider] exactly -- see that class's doc for the
/// shared contract (never throws for an ordinary failure; never inverts
/// or substitutes a pair; a partial response naming only some of the
/// requested quotes is valid). This class adds no policy beyond that
/// contract: freshness, staleness, and cache read/write are entirely
/// [ReferenceFxRateService]'s job (CP9.4 Task E: "do not duplicate this
/// policy inside the vendor adapter") -- this class only ever answers
/// "what did the vendor say right now", never "is that answer usable".
///
/// # No silent binary-floating-point corruption of rates
///
/// ExchangeRate-API's JSON response encodes each rate as a bare JSON
/// number literal (e.g. `"JPY": 149.85`), not a quoted string. Decoding
/// that through `dart:convert`'s standard `jsonDecode` would materialize
/// it as a `double` -- which is exactly the "authoritative binary
/// floating point" CP9.4's "CRITICAL JSON NUMBER RULE" forbids anywhere
/// near an [FxRate]. This class never does that: [_extractRawRateToken]
/// re-scans the *raw response text* for the exact decimal literal
/// belonging to the requested quote code and hands that literal string
/// straight to [FxRate]'s own constructor -- `jsonDecode` is used only
/// to validate structure/shape (is this a JSON object, does `result`
/// say `"success"`, does `base_code` match, is `rates` a map, which
/// keys does it contain) and never touches the numeric rate value
/// itself.
class ExchangeRateApiFxRateProvider implements FxRateProvider {
  ExchangeRateApiFxRateProvider({
    required HttpTransport transport,
    DateTime Function()? nowUtc,
    this.timeout = const Duration(seconds: 10),
    Uri Function(String baseCurrencyCode)? baseUrlBuilder,
  })  : _transport = transport,
        _nowUtc = nowUtc ?? DateTime.now,
        _baseUrlBuilder = baseUrlBuilder ?? _defaultBaseUrl;

  /// Stable provider identifier stored as every produced
  /// [ReferenceFxRate.source] -- suitable for later UI display (CP9.4
  /// Task G). Never a vendor-internal code, never localized here.
  static const String sourceId = 'exchangerate-api.com';

  final HttpTransport _transport;
  final DateTime Function() _nowUtc;

  /// Bounds the entire request (connect + response body fully read) --
  /// see CP9.4 Task E ("sensible request timeout"). No retry is
  /// performed on expiry (Task E: "no retries unless clearly
  /// justified") -- a timeout is reported exactly like any other
  /// transport failure, to [FxRateProviderFailure].
  final Duration timeout;

  final Uri Function(String baseCurrencyCode) _baseUrlBuilder;

  static Uri _defaultBaseUrl(String baseCurrencyCode) =>
      Uri.parse('https://open.er-api.com/v6/latest/$baseCurrencyCode');

  @override
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  }) async {
    // Canonicalize inputs the same way every other CurrencyRegistry call
    // site in this codebase does. An unknown code here is a programmer
    // error at the call site (see FxRateProvider's own doc) -- letting
    // CurrencyRegistry.require's ArgumentError propagate is correct, not
    // a "raw exception escaping the contract" (that rule is about
    // *transport/vendor* failures, not caller-supplied garbage).
    final String canonicalBase = CurrencyRegistry.require(baseCurrencyCode).code;
    final Set<String> canonicalQuotes = quoteCurrencyCodes
        .map((String code) => CurrencyRegistry.require(code).code)
        .toSet();

    final HttpTransportResponse response;
    try {
      response = await _transport.get(
        _baseUrlBuilder(canonicalBase),
        timeout: timeout,
      );
    } catch (e) {
      // Every ordinary transport failure (DNS/socket failure, timeout,
      // TLS handshake failure, ...) lands here -- CP9.4 Task F: "No raw
      // network exception should escape through the normal
      // FxRateProvider contract."
      return FxRateProviderFailure('exchangerate-api.com request failed: $e');
    }

    // The actual UTC retrieval instant -- CP9.4 Task G's [fetchedAt].
    // Captured once, immediately after the response is in hand (not
    // re-read later), exactly like ReferenceFxRateService's own
    // single-nowUtc-call-per-decision discipline.
    final DateTime fetchedAt = _nowUtc().toUtc();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return FxRateProviderFailure(
        'exchangerate-api.com returned HTTP ${response.statusCode}.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      final dynamic parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        return const FxRateProviderFailure(
          'exchangerate-api.com response was not a JSON object.',
        );
      }
      decoded = parsed;
    } catch (_) {
      return const FxRateProviderFailure(
        'exchangerate-api.com response was not valid JSON.',
      );
    }

    if (decoded['result'] != 'success') {
      return FxRateProviderFailure(
        'exchangerate-api.com reported result: ${decoded['result']}.',
      );
    }

    final dynamic returnedBase = decoded['base_code'];
    if (returnedBase is! String || returnedBase.toUpperCase() != canonicalBase) {
      return FxRateProviderFailure(
        'exchangerate-api.com returned base_code "$returnedBase", '
        'expected "$canonicalBase".',
      );
    }

    final dynamic ratesShape = decoded['rates'];
    if (ratesShape is! Map) {
      return const FxRateProviderFailure(
        'exchangerate-api.com response is missing a "rates" object.',
      );
    }

    final DateTime? observedAt = _observedAtFor(decoded);
    final List<ReferenceFxRate> results = <ReferenceFxRate>[];

    for (final String quote in canonicalQuotes) {
      // Not every requested quote must come back -- see FxRateProvider's
      // own "partial response is valid" contract. Never invented, never
      // synthesized from another pair.
      if (!ratesShape.containsKey(quote)) continue;

      final String? token = _extractRawRateToken(response.body, quote);
      if (token == null) {
        // Present in the decoded shape but not a bare plain-decimal
        // numeric literal in the raw text (a quoted string, null, an
        // object, or -- deliberately, since the pattern below does not
        // match 'e'/'E' -- exponent notation). Untrusted provider data:
        // skip this one quote rather than fail the whole batch.
        continue;
      }

      try {
        final FxRate rate = FxRate(
          baseCurrencyCode: canonicalBase,
          quoteCurrencyCode: quote,
          rate: token,
        );
        results.add(
          ReferenceFxRate(
            rate: rate,
            source: sourceId,
            observedAt: observedAt ?? fetchedAt,
            fetchedAt: fetchedAt,
          ),
        );
      } on FxRateParseException {
        // Zero, negative, or (redundantly, defense-in-depth) excess
        // fractional precision -- untrusted provider data, skip this
        // one quote. See CP9.4 Task D: "malformed/missing fields become
        // deterministic provider failure" -- here scoped to the single
        // affected quote, consistent with the partial-response contract
        // above, rather than failing quotes that parsed just fine.
        continue;
      }
    }

    return FxRateProviderSuccess(results);
  }

  /// Extracts the EXACT raw JSON-number literal text for [quoteCode]'s
  /// entry inside the response's top-level `"rates"` object --
  /// deliberately bypassing `jsonDecode`'s own number parsing (which
  /// would materialize the value as a `double`) for this one field. See
  /// this class's doc, "No silent binary-floating-point corruption of
  /// rates" -- this is the "exact raw-response parsing boundary that
  /// preserves the decimal token" CP9.4's CRITICAL JSON NUMBER RULE
  /// calls for.
  ///
  /// Scoped to the `"rates"` object's own substring (from that key's
  /// `{` to its matching `}`, brace-depth- and string-literal-aware) so
  /// this can never accidentally match a same-named key anywhere else
  /// in the response -- defensive margin, not a load-bearing assumption
  /// (this API's response shape has no other object nesting
  /// currency-code-shaped keys).
  ///
  /// Returns `null` (never throws) if [quoteCode]'s value in the raw
  /// text isn't a bare `-?\d+(\.\d+)?` token -- e.g. a quoted string,
  /// `null`, a nested object, or (deliberately, matching [FxRate]'s own
  /// contract) exponent notation like `1.5e10`, which this pattern does
  /// not match at all.
  String? _extractRawRateToken(String rawBody, String quoteCode) {
    final int ratesKeyIndex = rawBody.indexOf('"rates"');
    if (ratesKeyIndex == -1) return null;
    final int objectStart = rawBody.indexOf('{', ratesKeyIndex);
    if (objectStart == -1) return null;
    final int objectEnd = _matchingBraceIndex(rawBody, objectStart);
    if (objectEnd == -1) return null;
    final String ratesObjectText = rawBody.substring(objectStart, objectEnd + 1);

    // The trailing lookahead `(?=\s*[,}])` requires the captured number
    // to be immediately followed by the next JSON object delimiter
    // (`,` or the object's closing `}`), NOT just "however much of a
    // leading numeric prefix happens to parse". Without it, a malformed
    // value like `1.4985e2` (exponent notation, deliberately
    // unsupported -- see [FxRate]'s own contract) would let `\d+` greedily
    // match only its leading `1.4985` and stop there, silently truncating
    // "1.4985e2" into an accepted-looking "1.4985" instead of correctly
    // failing to match at all. With the lookahead, every possible
    // backtracked prefix of a token like `1.4985e2` is still followed by
    // `e2...`, never `,`/`}`, so the match fails outright and this
    // correctly returns `null` (skip this quote) instead of a truncated
    // value.
    final RegExp pattern = RegExp(
      '"${RegExp.escape(quoteCode)}"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)(?=\\s*[,}])',
    );
    final RegExpMatch? match = pattern.firstMatch(ratesObjectText);
    return match?.group(1);
  }

  /// Finds the index of the `}` that closes the `{` at [openIndex],
  /// tracking nested braces and skipping over JSON string-literal
  /// contents (so a `{`/`}` inside a quoted string is never mistaken for
  /// structural JSON). Returns -1 if unbalanced/not found.
  int _matchingBraceIndex(String text, int openIndex) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = openIndex; i < text.length; i++) {
      final String ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// [ReferenceFxRate.observedAt] semantics -- see CP9.4 Task G.
  ///
  /// ExchangeRate-API's `time_last_update_unix` field is the provider's
  /// own daily-snapshot timestamp (Unix epoch seconds, a bare JSON
  /// *integer*). Unlike the rate values, decoding this one field via
  /// `jsonDecode`/Dart `int` is safe: an epoch-seconds integer has no
  /// fractional part for a `double` to perturb, `jsonDecode` only ever
  /// materializes a JSON integer literal as a Dart `int` (never a
  /// `double`) when it has no `.`/exponent, and Dart's native `int` is
  /// 64-bit -- far beyond any real epoch value.
  ///
  /// When present and a valid non-negative integer, this becomes
  /// [ReferenceFxRate.observedAt]. When absent or malformed, this
  /// returns `null` and the caller uses [fetchedAt] instead --
  /// documented policy, not invented precision: "we don't know when the
  /// vendor computed this rate, so the only honest timestamp we have is
  /// when we ourselves retrieved it." (CP9.4 Task G: "If the provider
  /// doesn't expose a meaningful rate timestamp, document the chosen
  /// observedAt semantics rather than inventing historical precision.")
  DateTime? _observedAtFor(Map<String, dynamic> decoded) {
    final dynamic raw = decoded['time_last_update_unix'];
    if (raw is! int || raw < 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
  }
}
