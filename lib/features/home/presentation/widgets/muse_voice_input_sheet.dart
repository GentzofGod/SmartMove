import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/meta_ai_service.dart';

/// Bottom sheet for Muse Voice Transcribe (Push-to-talk speech-to-text)
///
/// Features:
/// - Real-time push-to-talk audio recording animation
/// - Low-latency transcription via Meta Muse Voice Transcribe 1.0
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
  late TextEditingController _transcriptController;
  late AnimationController _pulseController;
  Timer? _recordingTimer;
  int _secondsRecorded = 0;

  static const String demoSpokenPrompt =
      'I have ₦15,000. I need rice, eggs, tomatoes, and cooking oil. I also need to collect a package before 2 PM. Help me plan everything.';

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _secondsRecorded = 0;
      _transcriptController.text = 'Listening to your request...';
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
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
      _transcriptController.text = 'Transcribing with Meta Muse Voice Transcribe 1.0...';
    });

    const aiService = MetaAiService();
    // Simulate low-latency chunked recognition from Muse Voice Transcribe
    await Future.delayed(const Duration(milliseconds: 700));

    final result = await aiService.transcribeAudio(
      simulatedVoiceSample: demoSpokenPrompt,
    );

    if (mounted) {
      setState(() {
        _isTranscribing = false;
        _transcriptController.text = result.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
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
                      Icons.mic_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Muse Voice Transcribe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Meta Multimodal Speech-to-Text Model',
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
          const SizedBox(height: 16),

          // Recording Pulse / Button Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
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
                          width: 76,
                          height: 76,
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
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isRecording
                      ? 'Listening... 00:${_secondsRecorded.toString().padLeft(2, '0')} (Tap to finish)'
                      : _isTranscribing
                          ? 'Transcribing audio...'
                          : 'Tap to speak your errand / shopping request',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isRecording
                        ? const Color(0xFFD32F2F)
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'e.g. "I have ₦15,000 for rice, eggs, oil and package pickup before 2 PM"',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transcribed Text Area (Editable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Transcribed Request (Editable):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
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
          TextField(
            controller: _transcriptController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Or type your request here if voice is not available...',
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
    );
  }
}

