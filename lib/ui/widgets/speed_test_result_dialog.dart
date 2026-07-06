import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/speed_test_service.dart';

/// Hiz testi sonucu dialog'u
class SpeedTestResultDialog extends StatelessWidget {
  final SpeedTestResult result;

  const SpeedTestResultDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Baslik ve logo
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/new_logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.speed,
                            size: 28,
                            color: colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'settings.speed_test.title'.tr,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'settings.speed_test.completed'.tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Hiz gostergesi
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Download hizi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'settings.speed_test.download'.tr,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${result.downloadSpeed.toStringAsFixed(1)} Mbps',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Hiz bar'i
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (result.downloadSpeed / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getSpeedColor(result.downloadSpeed),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Analiz karti
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getAnalysisColor(result.analysis).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getAnalysisColor(result.analysis).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getAnalysisIcon(result.analysis),
                      color: _getAnalysisColor(result.analysis),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getAnalysisTitle(result.analysis),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getAnalysisColor(result.analysis),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.analysisMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Tekrar test et
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Tekrar test baslat
                      Get.find<SpeedTestService>().startSpeedTest();
                    },
                    child: Text('settings.speed_test.retry'.tr),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Kapat
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiz rengini getir
  Color _getSpeedColor(double speed) {
    if (speed < 5.0) {
      return const Color(0xFFFF5252); // Kirmizi
    } else if (speed < 12.0) {
      return const Color(0xFFFFC107); // Sari
    } else {
      return const Color(0xFF4CAF50); // Yesil
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

  /// Analiz basligini getir
  String _getAnalysisTitle(SpeedTestAnalysis analysis) {
    switch (analysis) {
      case SpeedTestAnalysis.verySlow:
        return 'settings.speed_test.analysis.very_slow'.tr;
      case SpeedTestAnalysis.borderline:
        return 'settings.speed_test.analysis.borderline'.tr;
      case SpeedTestAnalysis.excellent:
        return 'settings.speed_test.analysis.excellent'.tr;
    }
  }
}

/// Hiz testi hata dialog'u
class SpeedTestErrorDialog extends StatelessWidget {
  final String errorMessage;

  const SpeedTestErrorDialog({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hata ikonu ve baslik
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: colorScheme.error,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'settings.speed_test.error.title'.tr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Tekrar dene
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Tekrar test baslat
                      Get.find<SpeedTestService>().startSpeedTest();
                    },
                    child: Text('settings.speed_test.retry'.tr),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Kapat
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
