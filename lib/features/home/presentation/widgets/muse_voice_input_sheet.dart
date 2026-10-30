import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/meta_ai_service.dart';

/// Bottom sheet for Muse Voice Transcribe (Push-to-talk multi-dialect speech-to-text)
///
/// Features:
/// - Real-time push-to-talk audio recording animation
/// - Multi-dialect recognition: Nigerian Pidgin, Yorùbá, Hausa, Asụsụ Igbo, Nigerian English & Auto-Detect
/// - Dialect language badges & English normalization translation
/// - Low-latency transcription via Meta Muse Voice Transcribe 1.0 (`muse-voice-transcribe-1.0`)
/// - Immediate manual text editing fallback
/// - Transparent model indicators & error handling
class MuseVoiceInputSheet extends StatefulWidget {
  final Function(String transcribedText) onTranscriptConfirmed;

  const MuseVoiceInputSheet({
    super.key,
    required this.onTranscriptConfirmed,
  });

  @override
  State<MuseVoiceInputSheet> createState() => _MuseVoiceInputSheetState();
}

class _MuseVoiceInputSheetState extends State<MuseVoiceInputSheet>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isFallback = false;
  String? _transcriptionStatus;
  VoiceDialect _selectedDialect = VoiceDialect.autoDetect;
  VoiceTranscriptionResult? _transcriptionResult;

  late TextEditingController _transcriptController;
  late AnimationController _pulseController;
  Timer? _recordingTimer;
  int _secondsRecorded = 0;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _startRecording() {
    _pulseController.repeat(reverse: true);
    setState(() {
      _isRecording = true;
      _secondsRecorded = 0;
      _transcriptController.text =
          'Listening to your request in ${_selectedDialect.label}...';
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRecorded++;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
      _transcriptController.text =
          'Transcribing with Meta Muse Voice Transcribe 1.0 (${_selectedDialect.languageCode})...';
    });

    const aiService = MetaAiService();
    // Simulate low-latency chunked recognition from Muse Voice Transcribe
    await Future.delayed(const Duration(milliseconds: 650));

    final result = await aiService.transcribeAudio(
      simulatedVoiceSample: _selectedDialect.samplePrompt,
      dialect: _selectedDialect,
    );

    if (mounted) {
      setState(() {
        _isTranscribing = false;
        _transcriptionResult = result;
        _transcriptController.text = result.text;
        _isFallback = result.isFallback;
        _transcriptionStatus = result.isFallback
            ? 'Meta AI Fallback Engine Active: Offline Dialect Engine (${result.detectedDialect.label})'
            : 'Meta AI Live Cloud: Muse Voice Transcribe (${result.detectedDialect.label})';
      });
    }
  }

  void _simulateDialectSpeech(VoiceDialect dialect) async {
    setState(() {
      _selectedDialect = dialect;
      _isTranscribing = true;
      _transcriptController.text =
          'Transcribing sample audio in ${dialect.label}...';
    });

    const aiService = MetaAiService();
    await Future.delayed(const Duration(milliseconds: 400));

    final result = await aiService.transcribeAudio(
      simulatedVoiceSample: dialect.samplePrompt,
      dialect: dialect,
    );

    if (mounted) {
      setState(() {
        _isTranscribing = false;
        _transcriptionResult = result;
        _transcriptController.text = result.text;
        _isFallback = result.isFallback;
        _transcriptionStatus =
            'Meta Muse Voice Transcribe: Transcribed ${result.detectedDialect.label}';
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
            // Drag handle
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
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Muse Voice Transcribe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Multi-Dialect West African Speech-to-Text Model',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dialect Selector
            Row(
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Select Spoken Dialect / Vernacular:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedDialect.languageCode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dialect Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: VoiceDialect.values.map((dialect) {
                  final isSelected = _selectedDialect == dialect;
                  final chipLabel = dialect == VoiceDialect.autoDetect
                      ? '🌐 Auto-Detect'
                      : dialect == VoiceDialect.nigerianPidgin
                          ? '🇳🇬 Naija Pidgin'
                          : dialect.nativeLabel;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('chip_dialect_${dialect.languageCode}'),
                      label: Text(
                        chipLabel,
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
                          setState(() {
                            _selectedDialect = dialect;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Recording Pulse / Button Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              decoration: BoxDecoration(
                color: _isRecording ? const Color(0xFFFBE9E7) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRecording
                      ? const Color(0xFFFFAB91)
                      : AppColors.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    key: const ValueKey('voice_record_button'),
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = _isRecording
                            ? 1.0 + (_pulseController.value * 0.15)
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _isRecording
                                 ? const Color(0xFFD32F2F)
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? const Color(0xFFD32F2F)
                                          : AppColors.primary)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  spreadRadius: _isRecording ? 4 : 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? 'Listening in ${_selectedDialect.label}... 00:${_secondsRecorded.toString().padLeft(2, '0')} (Tap to finish)'
                        : _isTranscribing
                            ? 'Transcribing audio...'
                            : 'Tap to speak your commodity request',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isRecording
                          ? const Color(0xFFD32F2F)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Prompt hint for selected dialect
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.record_voice_over_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '"${_selectedDialect.samplePrompt}"',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          key: const ValueKey('btn_simulate_dialect_voice'),
                          onTap: () => _simulateDialectSpeech(_selectedDialect),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Test Sample',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Transcribed Text Area (Editable)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Transcribed Request:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_transcriptionResult != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD1C4E9)),
                            ),
                            child: Text(
                              _transcriptionResult!.detectedDialect.label,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF512DA8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Text Fallback Ready',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Status Badge
            if (_transcriptionStatus != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
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
                        _transcriptionStatus!,
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

            // English Translation Card (if dialect is non-English)
            if (_transcriptionResult != null &&
                _transcriptionResult!.isDialectTranslated &&
                _transcriptionResult!.englishTranslation != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D7FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.g_translate_rounded,
                                size: 14,
                                color: Color(0xFF3538CD),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'English Translation (${_transcriptionResult!.detectedDialect.label}):',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3538CD),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          key: const ValueKey('btn_use_translation'),
                          onTap: () {
                            setState(() {
                              _transcriptController.text =
                                  _transcriptionResult!.englishTranslation!;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3538CD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Use Translation',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _transcriptionResult!.englishTranslation!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF1D2939),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input field
            TextField(
              controller: _transcriptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Or type your commodity request in any dialect or English...',
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

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_generate_plan_proposal'),
                onPressed: () {
                  final text = _transcriptController.text.trim();
                  if (text.isNotEmpty &&
                      !text.startsWith('Listening') &&
                      !text.startsWith('Transcribing')) {
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
                  'Generate Plan Proposal',
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
