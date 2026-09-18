import 'fx_rate.dart';

/// Thrown by [FxConverter.convert] when the given [FxRate]'s currency
/// pair does not match the requested conversion direction.
///
/// CP9.1 never silently inverts or substitutes a rate -- a `USD -> JPY`
/// rate can only ever convert USD to JPY. Converting JPY to USD requires
/// a separately-quoted `JPY -> USD` rate. A mismatch is always a
/// deterministic rejection, never a guess.
class FxRatePairMismatchException implements Exception {
  const FxRatePairMismatchException({
    required this.requiredBaseCurrencyCode,
    required this.requiredQuoteCurrencyCode,
    required this.rate,
  });

  /// The source currency the conversion actually needs a rate *from*.
  final String requiredBaseCurrencyCode;

  /// The target currency the conversion actually needs a rate *to*.
  final String requiredQuoteCurrencyCode;

  /// The rate that was supplied, whose pair didn't match.
  final FxRate rate;

  @override
  String toString() =>
      'FxRatePairMismatchException: conversion requires a '
      '$requiredBaseCurrencyCode -> $requiredQuoteCurrencyCode rate, but the '
      'given rate is ${rate.baseCurrencyCode} -> ${rate.quoteCurrencyCode}. '
      'Rates are never silently inverted or substituted.';
}
