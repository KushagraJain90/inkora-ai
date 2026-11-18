
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/evaluation_result.dart';

class EvaluationResultScreen extends StatelessWidget {
  final EvaluationResult result;

  const EvaluationResultScreen({
    super.key,
    required this.result,
  });

  Future<void> _openPdf(BuildContext context) async {
    try {
      await OpenFilex.open(result.pdfPath);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open PDF: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = result.percentage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluation Result'),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success indicator
              Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 12),

              Text(
                'Evaluation Completed',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                result.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),

              // Marks card
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Marks Awarded',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),

                      Text(
                        '${result.marksAwarded} / ${result.totalMarks}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 18),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Feedback summary
              _ResultSection(
                title: 'Feedback Summary',
                icon: Icons.feedback_outlined,
                content: result.feedbackSummary,
              ),
              const SizedBox(height: 16),

              // Scoring rationale
              _ResultSection(
                title: 'Scoring Rationale',
                icon: Icons.analytics_outlined,
                content: result.scoreRationale,
              ),
              const SizedBox(height: 28),

              // Open PDF
              FilledButton.icon(
                onPressed: () => _openPdf(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Open Evaluation PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
