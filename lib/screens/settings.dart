import 'package:flutter/material.dart';

import '../cloud.dart';
import '../downloads.dart';
import '../settings.dart' as preferences;
import '../theme.dart';
import 'account.dart';
import 'equalizer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: preferences.appSettings.displayName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el ajuste: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences.appSettings,
      builder: (context, _) => SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text('Ajustes', style: kTitle),
            const SizedBox(height: 18),
            _sectionTitle('Personalización'),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: '¿Cómo quieres que te saludemos?',
                prefixIcon: Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _run(
                () => preferences.appSettings.setDisplayName(value),
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Cuenta'),
            ListenableBuilder(
              listenable: cloud,
              builder: (context, _) => _SettingsTile(
                icon: Icons.account_circle_rounded,
                title: 'Cuenta',
                subtitle: cloud.loggedIn
                    ? cloud.email ?? 'Conectada'
                    : 'Iniciar sesión',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Descargas'),
            ListenableBuilder(
              listenable: preferences.appSettings,
              builder: (context, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.wifi_rounded, color: kAccent),
                title: const Text('Descargar solo con Wi‑Fi'),
                subtitle: Text(preferences.appSettings.wifiOnly
                    ? 'Las descargas esperan al Wi‑Fi y se reanudan al volver.'
                    : 'Se permite descargar con Wi‑Fi o datos móviles.'),
                value: preferences.appSettings.wifiOnly,
                onChanged: (value) => _run(
                  () => preferences.appSettings.setWifiOnly(value),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: downloads,
              builder: (context, _) => downloads.errors['network'] == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        downloads.errors['network']!,
                        style: const TextStyle(color: kAccent),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Sonido'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary:
                  const Icon(Icons.multitrack_audio_rounded, color: kAccent),
              title: const Text('Mezcla DJ entre canciones'),
              subtitle: const Text(
                  'Mezcla los últimos 5 segundos y acelera el ritmo al cambiar.'),
              value: preferences.appSettings.crossfadeEnabled,
              onChanged: (value) => _run(
                () => preferences.appSettings.setCrossfadeEnabled(value),
              ),
            ),
            ListenableBuilder(
              listenable: preferences.appSettings,
              builder: (context, _) => _SettingsTile(
                icon: Icons.equalizer_rounded,
                title: 'Ecualizador y amplificador',
                subtitle: '${preferences.appSettings.equalizerPreset} · '
                    '${preferences.appSettings.amplifierGainDb.toStringAsFixed(0)} dB',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EqualizerScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title, style: kH2),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: kAccent),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
        onTap: onTap,
      );
}
