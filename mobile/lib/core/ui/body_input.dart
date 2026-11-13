// Leitura de altura e peso digitados no perfil: aceita vírgula ou ponto, entende altura em metros
// (1,60 vira 160 cm) e confere a faixa antes de enviar, com mensagem clara.

class BodyValue {
  const BodyValue.empty()
      : value = null,
        error = null,
        convertedFromMeters = false;
  const BodyValue.ok(double this.value, {this.convertedFromMeters = false}) : error = null;
  const BodyValue.invalid(String this.error)
      : value = null,
        convertedFromMeters = false;

  final double? value;
  final String? error;

  /// A altura foi digitada em metros e convertida para centímetros.
  final bool convertedFromMeters;

  bool get isValid => error == null;
}

/// "1,60", "1.60" e "160" viram número; letras e texto vazio viram null.
double? parseDecimal(String text) {
  final cleaned = text.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

const double minHeightCm = 50;
const double maxHeightCm = 250;
const double minWeightKg = 20;
const double maxWeightKg = 500;

/// Altura em centímetros. Valores de 0,5 a 3 são entendidos como metros (1,60 -> 160).
BodyValue checkHeightCm(String text) {
  if (text.trim().isEmpty) return const BodyValue.empty();
  final raw = parseDecimal(text);
  if (raw == null) return const BodyValue.invalid('Digite só números. Ex.: 170');
  var cm = raw;
  var meters = false;
  if (raw >= 0.5 && raw < 3) {
    cm = (raw * 1000).round() / 10; // 1,60 -> 160 e 1,755 -> 175,5
    meters = true;
  }
  if (cm < minHeightCm || cm > maxHeightCm) {
    return const BodyValue.invalid('Altura deve estar entre 50 e 250 cm. Ex.: 170');
  }
  return BodyValue.ok(cm, convertedFromMeters: meters);
}

/// Peso em quilos (20 a 500).
BodyValue checkWeightKg(String text) {
  if (text.trim().isEmpty) return const BodyValue.empty();
  final kg = parseDecimal(text);
  if (kg == null) return const BodyValue.invalid('Digite só números. Ex.: 78,5');
  if (kg < minWeightKg || kg > maxWeightKg) {
    return const BodyValue.invalid('Peso deve estar entre 20 e 500 kg. Ex.: 78,5');
  }
  return BodyValue.ok(kg);
}

/// 160 -> "160"; 175,5 -> "175,5" (formato brasileiro).
String formatCm(double cm) {
  final text = cm == cm.roundToDouble() ? cm.toStringAsFixed(0) : cm.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}
