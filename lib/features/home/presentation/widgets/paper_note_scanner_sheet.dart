import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/meta_ai_service.dart';

/// Modal bottom sheet for scanning and parsing handwritten paper shopping lists
/// and receipts using Meta Muse Spark Vision (`muse-spark-1.3`).
///
/// Features:
/// - Real Camera photo capture and Gallery image picker via `image_picker`
/// - Built-in authentic Nigerian market handwritten paper note presets
/// - Realistic lined notebook paper visualization
/// - Extraction of commodities, quantities, units, and budget
/// - Immediate manual text editing fallback for OCR corrections
/// - Transparent model indicators & error handling
class PaperNoteScannerSheet extends StatefulWidget {
  final Function(String transcribedText) onTranscriptConfirmed;

  const PaperNoteScannerSheet({
    super.key,
    required this.onTranscriptConfirmed,
  });

  @override
  State<PaperNoteScannerSheet> createState() => _PaperNoteScannerSheetState();
}

class _PaperNoteScannerSheetState extends State<PaperNoteScannerSheet> {
  final ImagePicker _picker = ImagePicker();
  final MetaAiService _aiService = const MetaAiService();

  bool _isAnalyzing = false;
  bool _isFallback = false;
  String? _statusMessage;
  Uint8List? _capturedImageBytes;
  String? _capturedImageName;

  SamplePaperNote _selectedSample = SamplePaperNote.defaultSamples.first;
  PaperNoteScanResult? _scanResult;
  late TextEditingController _transcriptController;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    // Pre-populate with initial sample note for immediate testability
    _loadSampleNote(_selectedSample, autoAnalyze: false);
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  void _loadSampleNote(SamplePaperNote sample, {bool autoAnalyze = true}) {
    setState(() {
      _selectedSample = sample;
      _capturedImageBytes = null;
      _capturedImageName = null;
      _transcriptController.text = sample.transcribedPrompt;
      _statusMessage = null;
      _scanResult = null;
    });

    if (autoAnalyze) {
      _analyzeCurrentNote();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _capturedImageName = picked.name;
          _statusMessage = 'Photo selected: ${picked.name}. Ready for Meta AI analysis.';
        });
        await _analyzeCurrentNote();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera/gallery: $e'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  Future<void> _analyzeCurrentNote() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage =
          'Analyzing handwritten note with Meta Muse Spark Vision (muse-spark-1.3)...';
    });

    // Simulate realistic low-latency multimodal reasoning
    await Future.delayed(const Duration(milliseconds: 600));

    final result = await _aiService.parsePaperNoteImage(
      imageBytes: _capturedImageBytes,
      simulatedNoteId: _capturedImageBytes == null ? _selectedSample.id : null,
      customNoteText: _capturedImageBytes == null ? _selectedSample.transcribedPrompt : null,
    );

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _scanResult = result;
        _transcriptController.text = result.rawTranscribedText;
        _isFallback = result.isFallback;
        _statusMessage = result.isFallback
            ? 'Meta AI Fallback Active: Local Multimodal Engine'
            : 'Meta AI Live Cloud: Muse Spark Vision (Success)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Scan Paper Shopping List',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Meta Muse Spark Multimodal Vision Model',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Camera & Gallery Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_take_camera_photo'),
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text(
                      'Take Photo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_choose_gallery_photo'),
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primary),
                    label: const Text(
                      'From Gallery',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Preset Sample Notes Bar
            Row(
              children: const [
                Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'Or Try a Handwritten Market Note Preset:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: SamplePaperNote.defaultSamples.map((sample) {
                  final isSelected =
                      _capturedImageBytes == null && _selectedSample.id == sample.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('chip_sample_${sample.id}'),
                      label: Text(
                        sample.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          _loadSampleNote(sample);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Visual Note Preview Card (Lined paper simulation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7), // Light notebook paper yellow
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFEE58), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paper Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              size: 18, color: Color(0xFFF57F17)),
                          const SizedBox(width: 6),
                          Text(
                            _capturedImageName != null
                                ? 'Photographed Note (${_capturedImageName!})'
                                : _selectedSample.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD54F)),
                        ),
                        child: Text(
                          _capturedImageBytes != null ? 'Camera Scan' : 'Paper Scrap',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFFFE082), thickness: 1, height: 16),

                  // Handwritten text presentation
                  Text(
                    _capturedImageBytes != null
                        ? 'Handwritten paper list captured from camera. Meta Muse Spark Vision has extracted the commodities below.'
                        : _selectedSample.handwrittenContent,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action to Trigger Analysis
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_analyze_paper_note'),
                      onPressed: _isAnalyzing ? null : _analyzeCurrentNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF57F17),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.psychology_rounded, size: 14),
                      label: Text(
                        _isAnalyzing ? 'Extracting with AI...' : 'Parse with Meta AI',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Status message
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _isFallback
                      ? const Color(0xFFFFF8E1)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isFallback
                        ? const Color(0xFFFFE082)
                        : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFallback
                          ? Icons.offline_bolt_rounded
                          : Icons.cloud_done_rounded,
                      size: 14,
                      color: _isFallback
                          ? const Color(0xFFE65100)
                          : const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _isFallback
                              ? const Color(0xFFBF360C)
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Extracted Items Matrix
            if (_scanResult != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 5),
                            Text(
                              'Recognized Commodities (${_scanResult!.proposal.shoppingItems.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Budget: ₦${_scanResult!.proposal.budget.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _scanResult!.proposal.shoppingItems.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Editable Transcribed Prompt Area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Text(
                    'Transcribed Request (Editable):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'OCR Cleaned',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _transcriptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Or edit the transcribed shopping list commodities and budget...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Generate Plan Proposal Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_generate_plan_from_paper'),
                onPressed: () {
                  final text = _transcriptController.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(context);
                    widget.onTranscriptConfirmed(text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text(
                  'Generate Plan Proposal from Note',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
