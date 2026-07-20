import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import 'tv_dpad_focus.dart';

/// Ayarlar alt sayfalarında üst geri düğmesi yalnızca mobil/tablet'te gösterilir.
bool tvSettingsLayoutIsTv() =>
    Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

/// Alt ayar başlığı — TV modunda geri düğmesi yok (kumanda Geri / ◀ yeterli).
Widget tvSettingsSubpageHeader(
  BuildContext context,
  String title, {
  VoidCallback? onBack,
}) {
  final tv = tvSettingsLayoutIsTv();
  return Padding(
    padding: EdgeInsets.fromLTRB(tv ? 14 : 12, 10, 12, 8),
    child: Row(
      children: [
        if (!tv)
          tvSettingsBackButton(
            context,
            autofocus: true,
            onPressed: onBack,
          ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

/// TV ayar alt sayfası listeleri için dikey D-pad koordinasyonu.
class TvSettingsDpadCoordinator {
  final Set<int> _active = {};
  final Map<int, FocusNode> _nodes = {};

  void beginBuild() {
    _active.clear();
  }

  void markActive(int index) {
    _active.add(index);
    nodeFor(index);
  }

  FocusNode nodeFor(int index) => _nodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: 'tvSettingsDpad_$index'),
      );

  int? firstActive() {
    if (_active.isEmpty) return null;
    final sorted = _active.toList()..sort();
    return sorted.first;
  }

  int? prev(int from) {
    for (var i = from - 1; i >= 0; i--) {
      if (_active.contains(i)) return i;
    }
    return null;
  }

  int? next(int from) {
    for (var i = from + 1; i < 128; i++) {
      if (_active.contains(i)) return i;
    }
    return null;
  }

  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
    _active.clear();
  }
}

class TvSettingsDpadScope extends StatefulWidget {
  const TvSettingsDpadScope({
    super.key,
    required this.enabled,
    required this.child,
    this.onBack,
  });

  final bool enabled;
  final Widget child;
  final VoidCallback? onBack;

  static TvSettingsDpadScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TvSettingsDpadScopeData>()
        ?.scope;
  }

  @override
  State<TvSettingsDpadScope> createState() => _TvSettingsDpadScopeState();
}

class _TvSettingsDpadScopeState extends State<TvSettingsDpadScope> {
  final _coordinator = TvSettingsDpadCoordinator();
  bool _scheduledFirstFocus = false;

  TvSettingsDpadCoordinator get coordinator => _coordinator;

  int _lastBackHandledMs = 0;

  void _popSubpage() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 400) return;
    _lastBackHandledMs = now;

    if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
      Get.back<void>();
      return;
    }
    (widget.onBack ?? () => Get.back<void>())();
  }

  void _scheduleFirstFocus() {
    if (!widget.enabled || _scheduledFirstFocus) return;
    _scheduledFirstFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = _coordinator.firstActive();
      if (first == null) return;
      scheduleTvFocusRestore(_coordinator.nodeFor(first), maxAttempts: 16);
    });
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    _coordinator.beginBuild();
    _scheduleFirstFocus();
    return _TvSettingsDpadScopeData(
      scope: widget,
      coordinator: _coordinator,
      onBack: _popSubpage,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (tvKeyIsBack(event.logicalKey)) {
            _popSubpage();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}

class _TvSettingsDpadScopeData extends InheritedWidget {
  const _TvSettingsDpadScopeData({
    required this.scope,
    required this.coordinator,
    required this.onBack,
    required super.child,
  });

  final TvSettingsDpadScope scope;
  final TvSettingsDpadCoordinator coordinator;
  final VoidCallback onBack;

  @override
  bool updateShouldNotify(covariant _TvSettingsDpadScopeData oldWidget) =>
      scope != oldWidget.scope ||
      coordinator != oldWidget.coordinator ||
      onBack != oldWidget.onBack;
}

/// TV ayar alt sayfası satırı — dikey D-pad zinciri + Geri/◀ ile üst sayfaya dönüş.
Widget tvSettingsDpadWrap(
  BuildContext context, {
  required int index,
  required VoidCallback onActivate,
  required Widget child,
  double borderRadius = 12,
  double scaleOnFocus = 1.0,
  bool autofocus = false,
  FocusNode? focusNode,
  bool ensureVisibleOnFocus = true,
}) {
  final scopeData =
      context.dependOnInheritedWidgetOfExactType<_TvSettingsDpadScopeData>();
  if (scopeData == null || !scopeData.scope.enabled) {
    return tvDpadActivateWrap(
      context,
      onActivate: onActivate,
      borderRadius: borderRadius,
      scaleOnFocus: scaleOnFocus,
      autofocus: autofocus,
      focusNode: focusNode,
      ensureVisibleOnFocus: ensureVisibleOnFocus,
      useRemoteNav: tvSettingsLayoutIsTv(),
      child: child,
    );
  }

  final coord = scopeData.coordinator;
  coord.markActive(index);
  final node = focusNode ?? coord.nodeFor(index);

  return TvDpadFocus(
    focusNode: node,
    onActivate: onActivate,
    ensureVisibleOnFocus: ensureVisibleOnFocus,
    borderRadius: borderRadius,
    scaleOnFocus: scaleOnFocus,
    autofocus: autofocus,
    enableFocusScale: false,
    blockLeft: true,
    blockRight: true,
    onKeyEvent: (event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (tvKeyIsBack(event.logicalKey)) {
        scopeData.onBack();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        scopeData.onBack();
        return KeyEventResult.handled;
      }
      final up = coord.prev(index);
      final down = coord.next(index);
      return tvHandleDpadKeys(
        event,
        onActivate: onActivate,
        arrowUp: up != null ? coord.nodeFor(up) : null,
        arrowDown: down != null ? coord.nodeFor(down) : null,
        blockUp: up == null,
        blockDown: down == null,
        blockLeft: true,
        blockRight: true,
      );
    },
    child: child,
  );
}
