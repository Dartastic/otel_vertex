// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_vertex/otel_vertex.dart';

/// Traces Vertex Cloud calls with OpenTelemetry.
///
/// `otel_vertex` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Vertex Cloud call in
/// [tracedVertex]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'vertex-example');

  // Wraps a Vertex Cloud API call in a CLIENT span.
  final vertexId = await tracedVertex<String>(
    operation: 'certificates.create',
    environment: 'example',
    invoke: () async {
      // Make the Vertex Cloud call here, then report what it returned.
      const id = 'vertex_8f3a2c';
      return const VertexCallResult(
          value: id,
          result: VertexResult(
              transactionId: 'transaction_8f3a2c',
              documentType: 'INVOICE',
              transactionType: 'SALE',
              lineCount: 3,
              totalTaxMinor: 1,
              currency: 'usd',
              taxRegime: 'US_SALES_USE',
              country: 'example',
              calculationOnly: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedVertex certificates.create returned $vertexId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutVertexInstrumentationAsync.
  await runWithoutVertexInstrumentationAsync(
    () => tracedVertex<String>(
      operation: 'certificates.create',
      environment: 'example',
      invoke: () async {
        const id = 'vertex_8f3a2c';
        return const VertexCallResult(
            value: id,
            result: VertexResult(
                transactionId: 'transaction_8f3a2c',
                documentType: 'INVOICE',
                transactionType: 'SALE',
                lineCount: 3,
                totalTaxMinor: 1,
                currency: 'usd',
                taxRegime: 'US_SALES_USE',
                country: 'example',
                calculationOnly: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
