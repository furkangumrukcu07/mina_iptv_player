import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/services/speed_test_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../ui/widgets/speed_test_gauge.dart';
import '../../ui/widgets/speed_test_result_dialog.dart';

/// Hiz testi ekran
class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  late final SpeedTestService _speedTestService;
  late final FocusNode _startTestFocusNode;
  late final FocusNode _retryFocusNode;
  late final bool _isTvMode;

  @override
  void initState() {
    super.initState();
    _speedTestService = Get.find<SpeedTestService>();
    _startTestFocusNode = FocusNode();
    _retryFocusNode = FocusNode();
    _isTvMode = Get.find<AppSettingsService>().layoutMode.value.usesRemoteNavigationStyle;
    
    // TV modunda otomatik olarak test butonuna odaklan
    if (_isTvMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTestFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _startTestFocusNode.dispose();
    _retryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('settings.speed_test.title'.tr),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: CallbackShortcuts(
        bindings: {
          if (_isTvMode) const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(Get.context!).pop();
          },
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (_isTvMode && event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Obx(() {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Hiz gostergesi - TV modunda daha büyük
                  Container(
                    padding: EdgeInsets.all(_isTvMode ? 40 : 20),
                    child: SpeedTestGauge(
                      currentSpeed: _speedTestService.currentSpeed,
                      isTesting: _speedTestService.isTesting,
                      centerWidget: _buildCenterWidget(),
                      strokeWidth: _isTvMode ? 16.0 : 12.0,
                      isTvMode: _isTvMode,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Test butonu - TV odakli
                  Focus(
                    focusNode: _startTestFocusNode,
                    onKeyEvent: (node, event) {
                      if (_isTvMode && event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          if (!_speedTestService.isTesting) {
                            _startSpeedTest();
                          }
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(_startTestFocusNode.hasFocus ? 1.05 : 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _startTestFocusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: _isTvMode ? 72 : 56,
                        child: FilledButton(
                          onPressed: _speedTestService.isTesting ? null : _startSpeedTest,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: _startTestFocusNode.hasFocus
                                  ? BorderSide(color: colorScheme.primary, width: 2)
                                  : BorderSide.none,
                            ),
                          ),
                          child: _speedTestService.isTesting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: _isTvMode ? 28 : 20,
                                      height: _isTvMode ? 28 : 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: _isTvMode ? 3 : 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'settings.speed_test.testing'.tr,
                                      style: TextStyle(
                                        fontSize: _isTvMode ? 18 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'settings.speed_test.start'.tr,
                                  style: TextStyle(
                                    fontSize: _isTvMode ? 18 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Hata mesaji - TV modunda daha büyük
                  if (_speedTestService.errorMessage.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(_isTvMode ? 24 : 16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: colorScheme.error,
                            size: _isTvMode ? 32 : 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _speedTestService.errorMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontSize: _isTvMode ? 18 : 14,
                                fontWeight: _isTvMode ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Bilgi kartlari
                  _buildInfoCards(theme, colorScheme),
                  
                  const SizedBox(height: 32),
                  
                  // Son test sonucu
                  if (_speedTestService.lastResult != null)
                    _buildLastResultCard(theme, colorScheme),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Merkez widget (logo veya hiz degeri)
  Widget _buildCenterWidget() {
    if (_speedTestService.isTesting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mina Player logosu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/new_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.speed,
                    size: 24,
                    color: Colors.grey[600],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            'settings.speed_test.testing'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }
    
    return Container(); // Varsayilan merkez widget'i kullan
  }

  /// Bilgi kartlari - TV modunda daha büyük
  Widget _buildInfoCards(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Hiz sinirlari hakkinda bilgi
        Container(
          padding: EdgeInsets.all(_isTvMode ? 24 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.speed_test.info.title'.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: _isTvMode ? 20 : 16,
                ),
              ),
              SizedBox(height: _isTvMode ? 20 : 12),
              
              // Cok yavas
              _buildSpeedThresholdItem(
                icon: Icons.warning_rounded,
                iconColor: const Color(0xFFFF5252),
                title: '< 5 Mbps',
                description: 'settings.speed_test.threshold.very_slow'.tr,
              ),
              
              SizedBox(height: _isTvMode ? 20 : 12),
              
              // Sinirda
              _buildSpeedThresholdItem(
                icon: Icons.info_rounded,
                iconColor: const Color(0xFFFFC107),
                title: '5 - 12 Mbps',
                description: 'settings.speed_test.threshold.borderline'.tr,
              ),
              
              SizedBox(height: _isTvMode ? 20 : 12),
              
              // Harika
              _buildSpeedThresholdItem(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: '> 12 Mbps',
                description: 'settings.speed_test.threshold.excellent'.tr,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Hiz siniri ogesi - TV modunda daha büyük
  Widget _buildSpeedThresholdItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _isTvMode ? 8 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: _isTvMode ? 28 : 20,
          ),
          SizedBox(width: _isTvMode ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: _isTvMode ? 18 : 14,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: _isTvMode ? 6 : 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontSize: _isTvMode ? 16 : 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Son test sonucu karti
  Widget _buildLastResultCard(ThemeData theme, ColorScheme colorScheme) {
    final result = _speedTestService.lastResult!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'settings.speed_test.last_result'.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Sonuc detaylari
          Row(
            children: [
              Icon(
                _getAnalysisIcon(result.analysis),
                color: _getAnalysisColor(result.analysis),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.downloadSpeed.toStringAsFixed(1)} Mbps',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                result.analysisMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getAnalysisColor(result.analysis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hiz testini baslat
  Future<void> _startSpeedTest() async {
    final result = await _speedTestService.startSpeedTest();
    
    if (result != null) {
      // Sonucu goster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SpeedTestResultDialog(result: result),
      );
    } else if (_speedTestService.errorMessage.isNotEmpty) {
      // Hata goster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SpeedTestErrorDialog(
          errorMessage: _speedTestService.errorMessage,
        ),
      );
    }
  }

  /// Analiz ikonunu getir
  IconData _getAnalysisIcon(SpeedTestAnalysis analysis) {
    switch (analysis) {
      case SpeedTestAnalysis.verySlow:
        return Icons.warning_rounded;
      case SpeedTestAnalysis.borderline:
        return Icons.info_rounded;
      case SpeedTestAnalysis.excellent:
        return Icons.check_circle_rounded;
    }
  }

  /// Analiz rengini getir
  Color _getAnalysisColor(SpeedTestAnalysis analysis) {
    switch (analysis) {
      case SpeedTestAnalysis.verySlow:
        return const Color(0xFFFF5252); // Kirmizi
      case SpeedTestAnalysis.borderline:
        return const Color(0xFFFFC107); // Sari
      case SpeedTestAnalysis.excellent:
        return const Color(0xFF4CAF50); // Yesil
    }
  }
}
