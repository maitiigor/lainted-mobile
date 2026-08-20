/// Laravel's `decimal:N` Eloquent cast serializes to JSON as a STRING
/// (e.g. `"30000.00"`), not a number, to preserve precision that a float
/// would lose - a plain `json['price'] as num` cast throws at runtime the
/// moment a real decimal-cast value comes back, even though it looks fine
/// against hand-written test fixtures. Every model reading a decimal-cast
/// backend field should parse through here instead of casting directly.
double parseDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
