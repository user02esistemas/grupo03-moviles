// UBICACIÓN: lib/core/utils/formatters.dart
/// Utilidades de formato (montos y fechas) sin dependencias externas.
class Formatters {
  const Formatters._();

  /// "S/ 180.00"
  static String soles(num monto) => 'S/ ${monto.toStringAsFixed(2)}';

  /// Fecha para la API (FastAPI espera ISO date): "2026-07-15"
  static String fechaApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Fecha para mostrar: "15/07/2026"
  static String fechaVisible(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  /// Cantidad de noches entre dos fechas.
  static int noches(DateTime inicio, DateTime fin) =>
      fin.difference(inicio).inDays;

  /// Parseo robusto de NUMERIC: FastAPI puede mandarlo como número o string.
  static double toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}