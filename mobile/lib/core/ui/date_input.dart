import 'package:flutter/services.dart';

/// Máscara de data brasileira (DD/MM/AAAA) para campos de texto.
///
/// - aceita só números: as barras entram sozinhas;
/// - corrige o óbvio na hora: "5" no dia vira "05/", "2" no mês vira "02/";
/// - não deixa passar de 31 no dia nem de 12 no mês;
/// - apagar funciona normalmente (a barra não "gruda" e impede de apagar).
class BrDateInputFormatter extends TextInputFormatter {
  const BrDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final typedDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final deleting = newValue.text.length < oldValue.text.length;
    final digits = _sanitize(typedDigits);
    final text = _format(digits, appendSlash: !deleting);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Mantém só dígitos que formam uma data possível, no máximo 8 (DDMMAAAA).
  static String _sanitize(String raw) {
    final out = StringBuffer();
    for (final ch in raw.split('')) {
      if (out.length >= 8) break;
      final pos = out.length;
      final soFar = out.toString();
      if (pos == 0) {
        // Dia: primeiro dígito 0–9; de 4 a 9 vira "0d" (ex.: 5 -> 05).
        if (ch.compareTo('3') > 0) {
          out.write('0');
        }
        out.write(ch);
        continue;
      }
      if (pos == 1) {
        final day = int.parse('${soFar[0]}$ch');
        if (day < 1 || day > 31) continue; // 00 e 32+ não existem
        out.write(ch);
        continue;
      }
      if (pos == 2) {
        // Mês: 2 a 9 vira "0m"; 0 e 1 esperam o segundo dígito.
        if (ch.compareTo('1') > 0) {
          out.write('0');
        }
        out.write(ch);
        continue;
      }
      if (pos == 3) {
        final month = int.parse('${soFar[2]}$ch');
        if (month < 1 || month > 12) continue; // 00 e 13+ não existem
        out.write(ch);
        continue;
      }
      out.write(ch); // ano: 4 dígitos
    }
    return out.toString();
  }

  static String _format(String digits, {required bool appendSlash}) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(digits[i]);
    }
    // Depois do dia e do mês completos, já deixa a barra pronta (só ao digitar, nunca ao apagar).
    if (appendSlash && (digits.length == 2 || digits.length == 4)) b.write('/');
    return b.toString();
  }
}

/// Resultado da checagem de uma data de nascimento digitada.
class BirthDateCheck {
  const BirthDateCheck.empty()
      : date = null,
        error = null,
        complete = false;
  const BirthDateCheck.partial()
      : date = null,
        error = null,
        complete = false;
  const BirthDateCheck.invalid(this.error)
      : date = null,
        complete = true;
  const BirthDateCheck.ok(DateTime this.date)
      : error = null,
        complete = true;

  final DateTime? date;
  final String? error;

  /// A pessoa já digitou as 8 posições (DD/MM/AAAA).
  final bool complete;

  bool get isValid => date != null;
}

/// Valida o texto do campo (com ou sem barras). Datas futuras e anteriores a 1900 são recusadas.
BirthDateCheck checkBirthDate(String text, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return const BirthDateCheck.empty();
  if (digits.length < 8) return const BirthDateCheck.partial();
  final day = int.parse(digits.substring(0, 2));
  final month = int.parse(digits.substring(2, 4));
  final year = int.parse(digits.substring(4, 8));
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return const BirthDateCheck.invalid('Esse dia não existe nesse mês. Confira a data.');
  }
  if (year < 1900) return const BirthDateCheck.invalid('Ano inválido. Use a partir de 1900.');
  final onlyDay = DateTime(today.year, today.month, today.day);
  if (date.isAfter(onlyDay)) return const BirthDateCheck.invalid('A data não pode ser no futuro.');
  return BirthDateCheck.ok(date);
}
