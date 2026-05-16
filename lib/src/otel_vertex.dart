// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_vertex_suppression.dart';

const _tracerName = 'dartastic_otel_libs_vertex';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class VertexResult {
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

class VertexCallResult<T> {
  const VertexCallResult({required this.value, this.result});
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
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transactionId != null) {
        extras.add(OTel.attributeString(
          'vertex.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTel.attributeString(
          'vertex.document.type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.transactionType != null) {
        extras.add(OTel.attributeString(
          'vertex.transaction.type',
          r.result!.transactionType!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTel.attributeInt(
          'vertex.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTel.attributeInt(
          'vertex.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTel.attributeString(
          'vertex.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.taxRegime != null) {
        extras.add(OTel.attributeString(
          'vertex.tax_regime',
          r.result!.taxRegime!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTel.attributeString(
          'vertex.country',
          r.result!.country!,
        ));
      }
      if (r.result!.calculationOnly != null) {
        extras.add(OTel.attributeBool(
          'vertex.calculation_only',
          r.result!.calculationOnly!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'vertex.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
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
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
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
