import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/interval_duration.dart';

/// Campo de duração de fase (caminhada/corrida) com setas de ±30 s.
class IntervalPhaseDurationField extends StatefulWidget {
  const IntervalPhaseDurationField({
    super.key,
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  State<IntervalPhaseDurationField> createState() =>
      _IntervalPhaseDurationFieldState();
}

class _IntervalPhaseDurationFieldState extends State<IntervalPhaseDurationField> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: IntervalDuration.format(widget.seconds));
  }

  @override
  void didUpdateWidget(covariant IntervalPhaseDurationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.seconds != widget.seconds) {
      _ctrl.text = IntervalDuration.format(widget.seconds);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applySeconds(int sec) {
    widget.onChanged(sec);
    if (!_editing) {
      _ctrl.text = IntervalDuration.format(sec);
    }
  }

  void _step(int direction) {
    _applySeconds(IntervalDuration.step(widget.seconds, direction: direction));
  }

  void _commitText() {
    _editing = false;
    final parsed = IntervalDuration.parseInput(_ctrl.text);
    if (parsed != null) {
      _applySeconds(parsed);
      return;
    }
    _ctrl.text = IntervalDuration.format(widget.seconds);
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '${widget.label} (min)',
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        // Setas estreitas: o padrão do Material reserva 48 px e espremia o número.
        suffixIconConstraints: const BoxConstraints(minWidth: 32, maxWidth: 32),
        suffixIcon: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepIcon(
              icon: Icons.keyboard_arrow_up,
              tooltip: '+30 s',
              onPressed: () => _step(1),
            ),
            _StepIcon(
              icon: Icons.keyboard_arrow_down,
              tooltip: '-30 s',
              onPressed: () => _step(-1),
            ),
          ],
        ),
      ),
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9:.,]')),
        ],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        // O tema dá borda, fundo e 16 px de margem a todo campo: aqui
        // dentro isso desenhava uma caixa dentro da outra e cortava
        // "19:00" para "1". O campo interno fica sem moldura.
        decoration: const InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: '2:30',
        ),
        onTap: () => _editing = true,
        onChanged: (_) => _editing = true,
        onEditingComplete: _commitText,
        onSubmitted: (_) => _commitText(),
        onTapOutside: (_) => _commitText(),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
