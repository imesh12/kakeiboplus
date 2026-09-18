/// Thrown by [ReferenceFxRate]'s constructor when a would-be reference
/// rate fails a domain-level invariant that does not depend on any
/// particular request context -- currently: an empty/whitespace-only
/// [ReferenceFxRate.source].
///
/// This mirrors the existing [MoneyParseException]/[FxRateParseException]
/// convention: a dedicated, typed exception carrying a user-displayable
/// [message], rather than a bare `ArgumentError` or a stripped-in-release
/// `assert`. Validations that DO depend on request context -- whether a
/// provider's pair matches what was actually requested, or whether an
/// observed timestamp is in the future relative to "now" -- are not
/// raised here; only [ReferenceFxRateService] has enough context to make
/// those calls (see that class's doc).
class InvalidReferenceFxRateException implements Exception {
  InvalidReferenceFxRateException(this.message);

  final String message;

  @override
  String toString() => 'InvalidReferenceFxRateException: $message';
}
