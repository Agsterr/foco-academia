import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/health_sync_service.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import '../core/ui/insets.dart';
import '../core/ui/error_text.dart';
import '../core/ui/date_input.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  /// A pessoa tentou salvar com a data pela metade: mostra o aviso no campo até ela digitar de novo.
  bool _birthIncomplete = false;
  String? _sex;
  String? _activity;
  String? _goal;
  bool _loading = true;
  bool _saving = false;
  bool _healthOptIn = false;
  String? _error;

  static const _goals = {
    'EMAGRECER': 'Emagrecer',
    'GANHAR_MASSA': 'Ganhar massa',
    'CONDICIONAMENTO': 'Condicionamento',
    'CORRIDA': 'Corrida',
    'ALONGAMENTO': 'Alongamento',
    'MANUTENCAO': 'Manutenção',
  };

  static const _activities = {
    'SEDENTARIO': 'Sedentário',
    'LEVE': 'Leve',
    'MODERADO': 'Moderado',
    'INTENSO': 'Intenso',
    'MUITO_INTENSO': 'Muito intenso',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ProfileService.instance.getProfile();
      final health = await HealthSyncService.instance.load();
      if (!mounted) return;
      setState(() {
        _heightCtrl.text = p.heightCm?.toStringAsFixed(0) ?? '';
        _weightCtrl.text = p.currentWeightKg?.toStringAsFixed(1) ?? '';
        _birthCtrl.text = _formatBirthForDisplay(p.birthDate);
        _sex = p.sex;
        _activity = p.activityLevel;
        _goal = p.goal;
        _healthOptIn = health;
        _loading = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? birthIso;
      if (_birthCtrl.text.trim().isNotEmpty) {
        final check = checkBirthDate(_birthCtrl.text);
        if (!check.isValid) {
          // O motivo aparece embaixo do próprio campo (data incompleta, dia que não existe, futuro...).
          setState(() {
            _saving = false;
            _birthIncomplete = !check.complete;
          });
          return;
        }
        birthIso = _formatIso(check.date!);
      }
      await ProfileService.instance.updateProfile(
        heightCm: double.tryParse(_heightCtrl.text.replaceAll(',', '.')),
        weightKg: double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
        goal: _goal,
        sex: _sex,
        birthDate: birthIso,
        activityLevel: _activity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado')),
      );
      Navigator.of(context).pop();
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    String? error;
    var busy = false;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Excluir conta?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seus treinos, rotas de GPS, peso, perfil e assinatura neste app serão '
                'apagados para sempre. Se você assina o Foco Premium, cancele também '
                'na Google Play (Pagamentos e assinaturas).',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Digite sua senha para confirmar',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: busy
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setLocal(() => error = 'Digite sua senha');
                        return;
                      }
                      setLocal(() {
                        busy = true;
                        error = null;
                      });
                      final result = await AuthService.instance.deleteAccount(passwordCtrl.text);
                      if (result == null) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setLocal(() {
                          busy = false;
                          error = result;
                        });
                      }
                    },
              child: Text(busy ? 'Excluindo...' : 'Excluir conta'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    if (deleted == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(1900);
    var initial = _parseBirthDate(_birthCtrl.text) ?? DateTime(now.year - 25, 1, 1);
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      // Para data de nascimento é mais rápido escolher o ano primeiro e depois o dia.
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthCtrl.text = _formatBr(picked);
      _birthIncomplete = false;
    });
  }

  /// Aviso embaixo do campo de data: dia que não existe, futuro ou data pela metade ao salvar.
  String? get _birthErrorText {
    final check = checkBirthDate(_birthCtrl.text);
    if (check.error != null) return check.error;
    if (_birthIncomplete && !check.complete && _birthCtrl.text.trim().isNotEmpty) {
      return 'Complete a data: dia, mês e ano. Ex.: 15/03/1988';
    }
    return null;
  }

  static String _formatBirthForDisplay(String? raw) {
    final parsed = _parseBirthDate(raw);
    return parsed == null ? (raw ?? '') : _formatBr(parsed);
  }

  static String _formatBr(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  static String _formatIso(DateTime d) {
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  static DateTime? _parseBirthDate(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      final day = int.tryParse(digits.substring(0, 2));
      final month = int.tryParse(digits.substring(2, 4));
      final year = int.tryParse(digits.substring(4));
      if (day != null && month != null && year != null) {
        final candidate = DateTime(year, month, day);
        if (candidate.year == year && candidate.month == month && candidate.day == day) {
          return candidate;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil físico')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: scrollablePadding(context),
              children: [
                const Text(
                  'Usados na estimativa de calorias (MET). Sempre uma estimativa.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Health Connect / Apple Health'),
                  subtitle: const Text(
                    'Opt-in para espelhar treinos outdoor no app de saúde do aparelho',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _healthOptIn,
                  onChanged: (v) async {
                    await HealthSyncService.instance.setOptIn(v);
                    setState(() => _healthOptIn = v);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Altura (cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('birth-field'),
                  controller: _birthCtrl,
                  // Só números: as barras entram sozinhas (15031988 vira 15/03/1988).
                  keyboardType: TextInputType.number,
                  inputFormatters: const [BrDateInputFormatter()],
                  onChanged: (_) => setState(() => _birthIncomplete = false),
                  decoration: InputDecoration(
                    labelText: 'Data de nascimento',
                    // Rótulo sempre no alto: o formato DD/MM/AAAA fica visível dentro do campo desde o início.
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'DD/MM/AAAA',
                    helperText: 'Ex.: 15/03/1988. Digite só os números ou toque no calendário.',
                    helperMaxLines: 2,
                    errorText: _birthErrorText,
                    errorMaxLines: 2,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      key: const Key('birth-calendar'),
                      tooltip: 'Abrir calendário',
                      icon: const Icon(Icons.calendar_month_rounded),
                      onPressed: _pickBirthDate,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MASCULINO', child: Text('Masculino')),
                    DropdownMenuItem(value: 'FEMININO', child: Text('Feminino')),
                    DropdownMenuItem(value: 'NAO_INFORMADO', child: Text('Não informado')),
                  ],
                  onChanged: (v) => setState(() => _sex = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _activity,
                  decoration: const InputDecoration(
                    labelText: 'Nível de atividade',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in _activities.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _activity = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _goal,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in _goals.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _goal = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando...' : 'Salvar'),
                ),
                if (AuthService.instance.role == 'ALUNO') ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _confirmDeleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    label: const Text(
                      'Excluir minha conta',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const Text(
                    'Apaga seus treinos, rotas de GPS, peso e perfil. Não dá para desfazer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
    );
  }
}
