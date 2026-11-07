// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_vertex_suppression.dart';

const _tracerName = 'dartastic_otel_libs_vertex';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class VertexResult {
  /// Creates a result.
  const VertexResult({
    this.transactionId,
    this.documentType,
    this.transactionType,
    this.lineCount,
    this.totalTaxMinor,
    this.currency,
    this.taxRegime,
    this.country,
    this.calculationOnly,
    this.requestId,
    this.statusCode,
  });

  /// `transactionId` returned for quotations/invoices.
  final String? transactionId;

  /// `INVOICE` / `QUOTATION` / `DISTRIBUTE_TAX` / `PURCHASE_ORDER`.
  /// QUOTATION is calculation-only (not retained for filing).
  final String? documentType;

  /// `SALE` / `PURCHASE` / `RENTAL` / `SERVICE` / `EXEMPT`.
  final String? transactionType;

  /// `lineItems.length`.
  final int? lineCount;

  /// Total tax in minor units.
  final int? totalTaxMinor;

  /// ISO 4217.
  final String? currency;

  /// `US_SALES_USE` / `VAT` / `GST` / `HST` / `QST` / `JCT` — Vertex's
  /// per-regime processing path.
  final String? taxRegime;

  /// ISO 3166 ship-to country.
  final String? country;

  /// `true` when this is a what-if calc (no compliance impact, no
  /// audit retention — cheaper).
  final bool? calculationOnly;

  /// `X-Trace-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class VertexCallResult<T> {
  /// Creates a call result.
  const VertexCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final VertexResult? result;
}

/// Wraps a Vertex Cloud API call in a CLIENT span. [operation] is one
/// of `calculation.quotation`, `calculation.invoice`,
/// `transactions.list`, `transactions.get`, `transactions.adjust`,
/// `certificates.list`, `certificates.create`, `exemptions.list`,
/// `taxability_categories.list`, `returns.list`, `returns.file`,
/// `nexus.list`.
Future<T> tracedVertex<T>({
  required String operation,
  required Future<VertexCallResult<T>> Function() invoke,
  String? environment,
}) async {
  if (vertexInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'vertex',
    'rpc.method': operation,
    'vertex.operation': operation,
  };
  if (environment != null) m['vertex.environment'] = environment;

  final span = _tracer().startSpan(
    'vertex $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transactionId != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.document.type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.transactionType != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.transaction.type',
          r.result!.transactionType!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTelAPI.attributeInt(
          'vertex.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'vertex.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.taxRegime != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.tax_regime',
          r.result!.taxRegime!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.country',
          r.result!.country!,
        ));
      }
      if (r.result!.calculationOnly != null) {
        extras.add(OTelAPI.attributeBool(
          'vertex.calculation_only',
          r.result!.calculationOnly!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'vertex.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Vertex HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
