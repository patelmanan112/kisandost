import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/app_drawer.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/kit.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../data/diagnosis_models.dart';
import '../data/diagnosis_repository.dart';
import 'diagnosis_controller.dart';
import 'model_details_panel.dart';

class DiagnoseScreen extends ConsumerWidget {
  const DiagnoseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diagnosisControllerProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: switch (state) {
        DiagnosisIdle() => const _CaptureView(),
        DiagnosisRunning(:final photo, :final stage) => _RunningView(
          photo: photo,
          stage: stage,
        ),
        DiagnosisSuccess(:final photo, :final diagnosis) => _ResultView(
          photo: photo,
          diagnosis: diagnosis,
        ),
        DiagnosisFailure(:final error) => _FailureView(error: error),
      },
    );
  }
}

// ---------------------------------------------------------------- capture

class _CaptureView extends ConsumerWidget {
  const _CaptureView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final controller = ref.read(diagnosisControllerProvider.notifier);

    return Container(
      color: const Color(0xFF14140F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: back button + title + subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B3A32)),
                        color: const Color(0xFF1F1E18),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navDiagnose,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.diagnoseGuide,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA8A399),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Viewfinder Camera Frame
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF23231C),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    // Watermark illustration
                    const Center(
                      child: Icon(
                        Icons.eco_outlined,
                        size: 140,
                        color: Color(0xFF4A4A3E),
                      ),
                    ),

                    // Viewfinder 4 Corner Brackets
                    const _CornerBracket(alignment: Alignment.topLeft),
                    const _CornerBracket(alignment: Alignment.topRight),
                    const _CornerBracket(alignment: Alignment.bottomLeft),
                    const _CornerBracket(alignment: Alignment.bottomRight),

                    // Top floating pill: "Fill the frame with one affected leaf"
                    Positioned(
                      top: 18,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.diagnoseGuide,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF14140F),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom floating helpful tips
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TipCard(
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF86EFAC),
                            text: l10n.diagnoseGoodLightTip,
                          ),
                          const SizedBox(height: 8),
                          _TipCard(
                            icon: Icons.wb_sunny_outlined,
                            iconColor: const Color(0xFFFBBF24),
                            text: l10n.diagnoseShadowTip,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls: Gallery, Shutter button, Camera option
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery
                  InkWell(
                    onTap: () =>
                        controller.pickAndDiagnose(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B3A32)),
                        color: const Color(0xFF1F1E18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.diagnoseGallery,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Big Center Shutter Button
                  GestureDetector(
                    onTap: () => controller.pickAndDiagnose(ImageSource.camera),
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF14140F),
                          width: 5,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFFBBF24), spreadRadius: 3),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: Color(0xFF14532D),
                        ),
                      ),
                    ),
                  ),

                  // Retake / Direct Camera Trigger
                  InkWell(
                    onTap: () => controller.pickAndDiagnose(ImageSource.camera),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B3A32)),
                        color: const Color(0xFF1F1E18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.diagnoseTakePhoto,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footnote about free tier cold starts
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                l10n.diagnoseSlowNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFA8A399),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFBBF24);
    const size = 32.0;
    const border = BorderSide(color: amber, width: 3);

    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Positioned(
      top: isTop ? 72 : null,
      bottom: isTop ? null : 124,
      left: isLeft ? 36 : null,
      right: isLeft ? null : 36,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? border : BorderSide.none,
            bottom: isTop ? BorderSide.none : border,
            left: isLeft ? border : BorderSide.none,
            right: isLeft ? BorderSide.none : border,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(6) : Radius.zero,
            topRight: isTop && !isLeft ? const Radius.circular(6) : Radius.zero,
            bottomLeft: !isTop && isLeft
                ? const Radius.circular(6)
                : Radius.zero,
            bottomRight: !isTop && !isLeft
                ? const Radius.circular(6)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC14140F),
        border: Border.all(color: const Color(0xFF3B3A32)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE7E5DE)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- running

class _RunningView extends StatelessWidget {
  const _RunningView({required this.photo, required this.stage});

  final File photo;
  final DiagnosisStage stage;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    final steps = <(DiagnosisStage, String)>[
      (DiagnosisStage.compressing, l10n.diagnoseCompressing),
      (DiagnosisStage.uploading, l10n.diagnoseUploading),
      (DiagnosisStage.analysing, l10n.diagnoseAnalysing),
      (DiagnosisStage.matching, l10n.diagnoseMatching),
    ];
    final currentIndex = steps.indexWhere((s) => s.$1 == stage);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          KdCard(
            clip: true,
            padding: EdgeInsets.zero,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 24),
          KdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: i < currentIndex
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.forest,
                                  size: 22,
                                )
                              : i == currentIndex
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  size: 20,
                                  color: scheme.outline,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            steps[i].$2,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: i == currentIndex
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: i <= currentIndex
                                  ? scheme.onSurface
                                  : AppColors.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (stage == DiagnosisStage.analysing) ...[
            const SizedBox(height: 16),
            Text(
              l10n.diagnoseSlowNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- failure

class _FailureView extends ConsumerWidget {
  const _FailureView({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    final message = switch (error.kind) {
      ApiErrorKind.offline => l10n.appOffline,
      ApiErrorKind.timeout => l10n.appSlow,
      ApiErrorKind.badRequest when error.serverMessage == 'too_large' =>
        l10n.diagnoseTooLarge,
      _ => l10n.appError,
    };

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.dangerTint,
                  border: Border.all(color: AppColors.dangerLine),
                ),
                child: const Icon(
                  Icons.wifi_off,
                  size: 34,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.diagnoseKeepPhoto,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.ink3),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(diagnosisControllerProvider.notifier).retry(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.appRetry),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(diagnosisControllerProvider.notifier).reset(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  child: Text(l10n.diagnoseRetake),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- result

class _ResultView extends ConsumerWidget {
  const _ResultView({required this.photo, required this.diagnosis});

  final File photo;
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (diagnosis.isInconclusive) {
      return _InconclusiveView(photo: photo, diagnosis: diagnosis);
    }

    final healthy = diagnosis.isHealthy;
    final cardBg = healthy ? AppColors.forestTint : AppColors.amberTint;
    final cardBorder = healthy ? AppColors.forestLine : AppColors.amberLine;
    final severityColor = healthy ? AppColors.forest : AppColors.amberText;

    final dateStr = DateFormat('d MMM, h:mm a').format(DateTime.now());
    final cropLabel = diagnosis.cropName.isNotEmpty
        ? '${diagnosis.cropName} leaf'
        : 'Crop leaf';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Top Header Row
          Row(
            children: [
              InkWell(
                onTap: () =>
                    ref.read(diagnosisControllerProvider.notifier).reset(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outline),
                    color: scheme.surface,
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.navDiagnose,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$cropLabel · $dateStr',
                      style: TextStyle(fontSize: 12, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Verdict Card (ScanResult artboard)
          KdCard(
            background: cardBg,
            outline: cardBorder,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leaf Thumbnail (74x74dp)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          border: Border.all(color: cardBorder),
                        ),
                        child: Image.file(photo, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Disease Diagnosis Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (diagnosis.cropName.isNotEmpty
                                    ? diagnosis.cropName
                                    : 'DIAGNOSIS')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.08,
                              color: severityColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            diagnosis.diseaseName,
                            style: const TextStyle(
                              fontFamily: AppTheme.displayFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                healthy
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                                size: 16,
                                color: severityColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  healthy
                                      ? l10n.diagnoseHealthy
                                      : l10n.diagnoseInfected,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: severityColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Lower section: Model confidence bar & Provenance
                if (diagnosis.confidence > 0) ...[
                  const SizedBox(height: 14),
                  Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.diagnoseModelConfidence,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.ink3,
                            ),
                          ),
                          Text(
                            '${diagnosis.confidence}%',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (diagnosis.confidence / 100.0).clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight: 7,
                            backgroundColor: cardBorder.withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              healthy ? AppColors.forest : AppColors.amber,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ProvenanceChip.always(
                        Provenance.live,
                        label: l10n.diagnoseFromModel,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Expert verification warning if flagged by engine
          if (diagnosis.requiresExpertVerification) ...[
            const SizedBox(height: 12),
            KdCard(
              background: AppColors.amberTint,
              outline: AppColors.amberLine,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.diagnoseExpertNote,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.amberText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Model technical details if available
          if (diagnosis.diagnostics != null) ...[
            const SizedBox(height: 14),
            ModelDetailsPanel(diagnostics: diagnosis.diagnostics!),
          ],

          // Description if present
          if (diagnosis.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            KdCard(
              child: Text(
                diagnosis.description,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],

          // Chemical Recommendations: "SPRAY THIS"
          if (diagnosis.pesticides.isNotEmpty) ...[
            SectionHeader(l10n.diagnoseSprayThis),
            KdCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis.pesticides.first.name,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (diagnosis.pesticides.first.brand != null &&
                      diagnosis.pesticides.first.brand!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      diagnosis.pesticides.first.brand!,
                      style: TextStyle(fontSize: 13, color: AppColors.ink3),
                    ),
                  ],
                  if (diagnosis.causes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      diagnosis.causes.first,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Cultural Practices: "AND DO THIS, NO COST"
          if (diagnosis.precautions.isNotEmpty) ...[
            SectionHeader(l10n.diagnoseCulturalPractices),
            KdCard(
              background: AppColors.forestTint,
              outline: AppColors.forestLine,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final item in diagnosis.precautions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Symptoms: "WHAT TO LOOK FOR"
          if (diagnosis.symptoms.isNotEmpty) ...[
            SectionHeader(l10n.diagnoseSymptoms),
            KdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final symptom in diagnosis.symptoms)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              symptom,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Products & QR verify: "WHERE TO GET IT"
          SectionHeader(l10n.diagnoseWhereToGet),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (diagnosis.hasProducts)
                Expanded(
                  child: KdCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      final product = [
                        ...diagnosis.pesticides,
                        ...diagnosis.fertilizers,
                      ].first;
                      if (product.productId != null &&
                          product.productId!.isNotEmpty) {
                        context.push('/products/${product.productId}');
                      } else {
                        context.push('/products');
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.sunk,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.science_outlined,
                              color: AppColors.forest,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            ...diagnosis.pesticides,
                            ...diagnosis.fertilizers,
                          ].first.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ([
                              ...diagnosis.pesticides,
                              ...diagnosis.fertilizers,
                            ].first.price !=
                            null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '₹${[...diagnosis.pesticides, ...diagnosis.fertilizers].first.price}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (diagnosis.hasProducts) const SizedBox(width: 10),
              Expanded(
                child: KdCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push('/scan'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.forest,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.diagnoseCheckGenuine,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Action Buttons
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/community'),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text(l10n.diagnoseAskCommunity),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.forest, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(diagnosisControllerProvider.notifier).reset(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  child: Text(l10n.diagnoseRetake),
                ),
              ),
            ],
          ),

          // Footnote
          const SizedBox(height: 16),
          Text(
            l10n.diagnoseFootnote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- inconclusive

class _InconclusiveView extends ConsumerWidget {
  const _InconclusiveView({required this.photo, required this.diagnosis});

  final File photo;
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    final guidance = diagnosis.precautions.isNotEmpty
        ? diagnosis.precautions
        : diagnosis.symptoms;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KdCard(
            clip: true,
            padding: EdgeInsets.zero,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          KdCard(
            background: AppColors.amberTint,
            outline: AppColors.amberLine,
            child: Row(
              children: [
                const Icon(
                  Icons.filter_center_focus,
                  color: AppColors.amber,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.diagnoseUnclear,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amberText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.diagnoseHowToFix),
          KdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in guidance)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (diagnosis.diagnostics != null) ...[
            const SizedBox(height: 16),
            ModelDetailsPanel(diagnostics: diagnosis.diagnostics!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  ref.read(diagnosisControllerProvider.notifier).reset(),
              icon: const Icon(Icons.camera_alt),
              label: Text(l10n.diagnoseTakePhoto),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
