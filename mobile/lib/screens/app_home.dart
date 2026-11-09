import 'package:flutter/widgets.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'staff/staff_home_screen.dart';

/// Tela inicial conforme o perfil: aluno vê os treinos; instrutor e gestor, o painel da equipe.
Widget appHome() => AuthService.instance.isStaff ? const StaffHomeScreen() : const HomeScreen();
