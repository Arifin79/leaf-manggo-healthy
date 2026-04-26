import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../../shared/theme/app_theme.dart';

class ConfidenceIndicator extends StatelessWidget {
  final int percent;
  final String category;

  const ConfidenceIndicator({
    super.key,
    required this.percent,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tingkat Keyakinan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.texdark,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 54,
                lineWidth: 8,
                percent: percent / 100,
                center: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                progressColor: AppTheme.primaryBlue,
                backgroundColor: AppTheme.backgroundgrey,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 800,
              ),
              const SizedBox(width: 16),
              const Text(
                'Kategori',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textgrey,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.texdark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
