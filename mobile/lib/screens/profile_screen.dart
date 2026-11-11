import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/health_sync_service.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import '../core/ui/insets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
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
        _birthCtrl.text = p.birthDate ?? '';
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
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService.instance.updateProfile(
        heightCm: double.tryParse(_heightCtrl.text.replaceAll(',', '.')),
        weightKg: double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
        goal: _goal,
        sex: _sex,
        birthDate: _birthCtrl.text.trim().isEmpty ? null : _birthCtrl.text.trim(),
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
      setState(() => _error = e.toString());
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
                  controller: _birthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento (AAAA-MM-DD)',
                    border: OutlineInputBorder(),
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
