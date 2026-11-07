// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_vertex/otel_vertex.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_vertex-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('calculation.invoice records regime + document + lines', () async {
    await tracedVertex<String>(
      operation: 'calculation.invoice',
      environment: 'production',
      invoke: () async => const VertexCallResult(
        value: 'ok',
        result: VertexResult(
          transactionId: 'txn-1',
          documentType: 'INVOICE',
          transactionType: 'SALE',
          lineCount: 12,
          totalTaxMinor: 5230,
          currency: 'EUR',
          taxRegime: 'VAT',
          country: 'DE',
          calculationOnly: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('vertex calculation.invoice')!);
    expect(a['vertex.document.type'], 'INVOICE');
    expect(a['vertex.transaction.type'], 'SALE');
    expect(a['vertex.tax_regime'], 'VAT');
    expect(a['vertex.country'], 'DE');
    expect(a['vertex.calculation_only'], false);
  });

  test('quotation marked calculation_only', () async {
    await tracedVertex<String>(
      operation: 'calculation.quotation',
      invoke: () async => const VertexCallResult(
        value: 'ok',
        result: VertexResult(
          documentType: 'QUOTATION',
          calculationOnly: true,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('vertex calculation.quotation')!);
    expect(a['vertex.calculation_only'], true);
  });

  test('suppression skips spans', () async {
    await runWithoutVertexInstrumentationAsync(() async {
      await tracedVertex<String>(
        operation: 'certificates.list',
        invoke: () async => const VertexCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('vertex '), isEmpty);
  });
}
