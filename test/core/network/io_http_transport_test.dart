import 'dart:async';
import 'dart:io';

import 'package:ai_financial_coach/core/network/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.4 -- covers the one piece of production networking code
// the fake-transport-based FX provider tests deliberately never
// exercise: `IoHttpTransport` itself.
//
// This does NOT reach the real internet (CP9.4 Task I: "no live
// internet tests") -- every server here is a `dart:io.HttpServer` bound
// to the IPv4 loopback address (127.0.0.1) on an ephemeral port chosen
// by the OS, closed at the end of each test. It is the standard,
// fully-offline way to test `dart:io` HTTP client code without either
// touching the real network or adding a mocking dependency.
void main() {
  group('IoHttpTransport', () {
    test('returns the server\'s status code and full body', () async {
      final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((HttpRequest request) {
        request.response.statusCode = 200;
        request.response.write('{"hello":"world"}');
        request.response.close();
      });

      final HttpTransportResponse response = await IoHttpTransport().get(
        Uri.parse('http://${server.address.address}:${server.port}/'),
        timeout: const Duration(seconds: 5),
      );

      expect(response.statusCode, 200);
      expect(response.body, '{"hello":"world"}');
    });

    test('surfaces a non-2xx status code rather than throwing', () async {
      final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((HttpRequest request) {
        request.response.statusCode = 503;
        request.response.write('unavailable');
        request.response.close();
      });

      final HttpTransportResponse response = await IoHttpTransport().get(
        Uri.parse('http://${server.address.address}:${server.port}/'),
        timeout: const Duration(seconds: 5),
      );

      expect(response.statusCode, 503);
    });

    test('a server that never responds within the timeout throws TimeoutException', () async {
      final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((HttpRequest request) {
        // Deliberately never write/close a response -- the client must
        // give up on its own after `timeout`, not hang forever.
      });

      expect(
        () => IoHttpTransport().get(
          Uri.parse('http://${server.address.address}:${server.port}/'),
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
