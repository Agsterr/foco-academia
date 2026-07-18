import 'package:flutter/material.dart';

import '../services/cardio_service.dart';

/// Lista treinos anteriores do coach para o aluno escolher.
class CoachWorkoutPicker extends StatelessWidget {
  const CoachWorkoutPicker({
    super.key,
    required this.workouts,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CardioWorkout> workouts;
  final String? selectedId;
  final ValueChanged<CardioWorkout> onSelected;

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const Text(
        'Nenhum treino do coach salvo ainda. Com internet, puxe para atualizar.',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Treinos do coach',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        ...workouts.take(8).map((w) {
          final selected = w.id == selectedId;
          return Card(
            color: selected ? const Color(0xFF334155) : const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(w.title),
              subtitle: Text(
                '${w.intervalsSummary.isNotEmpty ? w.intervalsSummary : w.type}'
                '${w.active ? ' · ativo' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                  : null,
              onTap: () => onSelected(w),
            ),
          );
        }),
      ],
    );
  }
}
