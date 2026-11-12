import 'package:flutter/material.dart';

import '../cloud.dart';
import '../theme.dart';
import '../widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _mail = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _hide = true;

  @override
  void dispose() {
    _mail.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go(bool create) async {
    FocusScope.of(context).unfocus();
    final m = _mail.text.trim();
    if (!m.contains('@') || _pass.text.length < 6) {
      setState(() => _error =
          'Escribe un correo válido y una contraseña de al menos 6 caracteres.');
      return;
    }
    setState(() => _error = null);
    final err = create
        ? await cloud.signUp(m, _pass.text)
        : await cloud.signIn(m, _pass.text);
    if (!mounted) return;
    setState(() => _error = err);
    if (err == null) _pass.clear();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
            'Tus datos se quedan guardados en la cuenta y en este móvil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await cloud.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListenableBuilder(
        listenable: cloud,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: cloud.loggedIn ? _in() : _out(),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _in() {
    final err = cloud.status.startsWith('Error') ||
        cloud.status.startsWith('Cambios pendientes');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_circle_rounded, size: 64, color: kAccent),
        const SizedBox(height: 12),
        Text(cloud.email ?? '', style: kTitle.copyWith(fontSize: 20)),
        const SizedBox(height: 8),
        Text(
          cloud.status.isEmpty ? 'Conectada' : cloud.status,
          style: TextStyle(color: err ? kAccent : kMuted, fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Text(
          'Se guardan en tu cuenta los favoritos, los artistas que sigues y los recientes. Las descargas se quedan en este móvil.',
          style: TextStyle(color: kMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: cloud.busy ? null : () => cloud.syncNow(),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sincronizar ahora'),
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }

  Widget _out() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inicia sesión para guardar tus favoritos, los artistas que sigues y tus recientes en la nube.',
          style: TextStyle(color: kMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Correo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: _hide,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_hide
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: const TextStyle(color: kAccent, fontSize: 13)),
          ),
        const SizedBox(height: 20),
        if (cloud.busy)
          const Center(child: CircularProgressIndicator())
        else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _go(false),
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Iniciar sesión'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _go(true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Crear cuenta'),
            ),
          ),
        ],
      ],
    );
  }
}
