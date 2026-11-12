import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show SystemNavigator;

import '../audio_handler.dart';
import '../services.dart';
import '../widgets.dart';
import 'explore.dart';
import 'home.dart';
import 'library.dart';
import 'radio.dart';
import 'settings.dart';

const _destinations = [
  (Icons.home_rounded, 'Inicio'),
  (Icons.grid_view_rounded, 'Explorar'),
  (Icons.sensors_rounded, 'Radio'),
  (Icons.library_music_rounded, 'Biblioteca'),
  (Icons.settings_rounded, 'Ajustes'),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  bool _compact = false;
  DateTime? _lastBackPress;
  Timer? _exitHintTimer;

  @override
  void dispose() {
    _exitHintTimer?.cancel();
    super.dispose();
  }

  void _handleBack(bool didPop) {
    if (didPop) return;
    if (_i != 0) {
      setState(() {
        _i = 0;
        _compact = false;
      });
      _lastBackPress = null;
      _exitHintTimer?.cancel();
      return;
    }

    final now = DateTime.now();
    final lastBack = _lastBackPress;
    if (lastBack != null &&
        now.difference(lastBack) <= const Duration(seconds: 2)) {
      _exitHintTimer?.cancel();
      _lastBackPress = null;
      unawaited(_exitApp());
      return;
    }

    _lastBackPress = now;
    _exitHintTimer?.cancel();
    _exitHintTimer = Timer(const Duration(seconds: 2), () {
      _lastBackPress = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Pulsa atrás otra vez para salir'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _exitApp() async {
    try {
      await audioHandler.stop();
      await SystemNavigator.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo detener el reproductor: $error')),
      );
    }
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final compact = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _compact,
    };
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 720;
        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
          child: Scaffold(
            extendBody: !wideLayout,
            body: wideLayout
                ? Row(
                    children: [
                      SafeArea(
                        child: NavigationRail(
                          selectedIndex: _i,
                          onDestinationSelected: (i) => setState(() => _i = i),
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final destination in _destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.$1),
                                label: Text(destination.$2),
                              ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1200),
                                  child: _screens,
                                ),
                              ),
                            ),
                            ListenableBuilder(
                              listenable: player,
                              builder: (context, _) => player.current == null
                                  ? const SizedBox.shrink()
                                  : const Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(12, 0, 12, 8),
                                      child: MiniPlayer(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : NotificationListener<UserScrollNotification>(
                    onNotification: _onUserScroll,
                    child: _screens,
                  ),
            bottomNavigationBar: wideLayout
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ListenableBuilder(
                        listenable: player,
                        builder: (context, _) => AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          alignment: Alignment.bottomCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.14),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: _compact
                                ? SizedBox(
                                    key: const ValueKey('compact-navigation'),
                                    height: 62,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final playerWidth =
                                            (constraints.maxWidth - 120)
                                                .clamp(0.0, 280.0)
                                                .toDouble();
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: LiquidGlass(
                                                subtle: true,
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: SizedBox.square(
                                                  dimension: 48,
                                                  child: IconButton(
                                                    tooltip: 'Inicio',
                                                    onPressed: () =>
                                                        setState(() {
                                                      _i = 0;
                                                      _compact = false;
                                                    }),
                                                    icon: const Icon(
                                                        Icons.home_rounded),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: LiquidGlass(
                                                subtle: true,
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: SizedBox.square(
                                                  dimension: 48,
                                                  child: IconButton(
                                                    tooltip: 'Ajustes',
                                                    onPressed: () =>
                                                        setState(() {
                                                      _i = 4;
                                                      _compact = false;
                                                    }),
                                                    icon: const Icon(
                                                        Icons.settings_rounded),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (player.current != null)
                                              Align(
                                                alignment: Alignment.center,
                                                child: SizedBox(
                                                  width: playerWidth,
                                                  child: const MiniPlayer(
                                                      compact: true),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  )
                                : Column(
                                    key: const ValueKey('full-navigation'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      LiquidGlass(
                                        subtle: true,
                                        borderRadius: BorderRadius.circular(28),
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (player.current != null) ...[
                                                const MiniPlayer(
                                                    embedded: true),
                                                const SizedBox(height: 2),
                                              ],
                                              _LiquidNavigationBar(
                                                embedded: true,
                                                selectedIndex: _i,
                                                onSelected: (i) => setState(() {
                                                  _i = i;
                                                  _compact = false;
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget get _screens => IndexedStack(
        index: _i,
        children: [
          const HomeScreen(),
          const ExploreScreen(),
          const RadioScreen(),
          const LibraryScreen(),
          SettingsScreen(key: const ValueKey('settings')),
        ],
      );
}

class _LiquidNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool embedded;

  const _LiquidNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    this.embedded = false,
  });

  @override
  State<_LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

class _LiquidNavigationBarState extends State<_LiquidNavigationBar> {
  double? _dragPosition;
  bool _dragging = false;

  double get _position => _dragPosition ?? widget.selectedIndex.toDouble();

  void _updateFromPointer(double x, double width) {
    if (width <= 0) return;
    final segmentWidth = width / _destinations.length;
    final position =
        (x / segmentWidth - 0.5).clamp(0.0, _destinations.length - 1.0);
    final selected = (position + 0.5).floor();
    setState(() => _dragPosition = position);
    if (selected != widget.selectedIndex) widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final indicatorAlignment = _destinations.length == 1
              ? 0.0
              : -1 + (_position * 2 / (_destinations.length - 1));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              setState(() => _dragging = true);
              _updateFromPointer(
                  details.localPosition.dx, constraints.maxWidth);
            },
            onHorizontalDragUpdate: (details) {
              _updateFromPointer(
                  details.localPosition.dx, constraints.maxWidth);
            },
            onHorizontalDragEnd: (_) => setState(() {
              _dragging = false;
              _dragPosition = null;
            }),
            onHorizontalDragCancel: () => setState(() {
              _dragging = false;
              _dragPosition = null;
            }),
            child: Builder(
              builder: (context) {
                final bar = SizedBox(
                  height: 68,
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(indicatorAlignment, 0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / _destinations.length,
                          heightFactor: 1,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.fromRGBO(255, 255, 255, 0.24),
                                  Color.fromRGBO(255, 255, 255, 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 255, 255, 0.2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(255, 255, 255, 0.08),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _destinations.length; i++)
                            Expanded(
                              child: _NavigationItem(
                                icon: _destinations[i].$1,
                                label: _destinations[i].$2,
                                selected: widget.selectedIndex == i,
                                onTap: () {
                                  setState(() => _dragPosition = i.toDouble());
                                  widget.onSelected(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
                return widget.embedded
                    ? bar
                    : LiquidGlass(
                        subtle: true,
                        borderRadius: BorderRadius.circular(30),
                        child: bar,
                      );
              },
            ),
          );
        },
      );
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? Colors.white : Colors.white70,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
