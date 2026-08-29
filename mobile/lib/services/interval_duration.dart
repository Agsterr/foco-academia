/// Duração de fase do intervalado (caminhada/corrida) em segundos.
class IntervalDuration {
  IntervalDuration._();

  static const stepSec = 30;
  static const minSec = 30;
  static const maxSec = 30 * 60;

  /// Converte texto digitado em segundos.
  ///
  /// Aceita:
  /// - `2.5` / `2,5` → 2 min 30 s
  /// - `1:30` / `1.30` → 1 min 30 s (dois dígitos após ponto = segundos)
  /// - `90` → 90 s (só segundos se < 60) ou minutos inteiros se >= 60? No — número
  ///   sem separador = minutos inteiros (`2` → 2 min).
  static int? parseInput(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final normalized = text.replaceAll(',', '.');
    final colon = RegExp(r'^(\d+)\s*:\s*(\d{1,2})$').firstMatch(normalized);
    if (colon != null) {
      return _fromParts(
        int.parse(colon.group(1)!),
        int.parse(colon.group(2)!),
      );
    }

    final dotted = RegExp(r'^(\d+)\.(\d+)$').firstMatch(normalized);
    if (dotted != null) {
      final mins = int.parse(dotted.group(1)!);
      final frac = dotted.group(2)!;
      if (frac.length == 1) {
        final decimal = double.parse('$mins.$frac');
        return _clamp((decimal * 60).round());
      }
      if (frac.length == 2) {
        return _fromParts(mins, int.parse(frac));
      }
      return null;
    }

    final asDouble = double.tryParse(normalized);
    if (asDouble != null && asDouble > 0) {
      if (asDouble < 60 && !normalized.contains('.')) {
        // Número pequeno sem separador: minutos inteiros (ex.: 2 → 2 min).
        return _clamp((asDouble * 60).round());
      }
      return _clamp((asDouble * 60).round());
    }

    final digitsOnly = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digitsOnly != null && digitsOnly > 0) {
      return _clamp(digitsOnly * 60);
    }
    return null;
  }

  static int? _fromParts(int minutes, int seconds) {
    if (seconds >= 60) return null;
    return _clamp(minutes * 60 + seconds);
  }

  static int _clamp(int sec) => sec.clamp(minSec, maxSec);

  static int step(int sec, {required int direction}) {
    final next = sec + direction * stepSec;
    return next.clamp(minSec, maxSec);
  }

  /// Ex.: 150 → "2:30", 90 → "1:30", 120 → "2:00".
  static String format(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String formatWithUnit(int sec) => '${format(sec)} min';
}
