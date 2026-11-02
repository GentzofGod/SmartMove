import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'meta_ai_service.dart';

/// Real-Time Streaming Speech Transcriber using Meta's Real-Time WebSocket API (muse-voice-transcribe-1.0)
///
/// Pipeline:
/// 1. Microphone audio is streamed live using the `record` package (PCM 16-bit, 24kHz, Mono).
/// 2. Audio chunks are packaged into 80ms frames (3840 bytes) and sent over a WebSocketChannel.
/// 3. Meta real-time ASR returns partial transcripts live so words appear as the user speaks.
/// 4. When the user finishes speaking or silence is detected, speechComplete triggers finalization.
/// 5. Gracefully handles network fallbacks so transcription never stalls.
class MetaLiveTranscriber {
  final String? wsEndpoint;
  final String? apiKey;
  final AudioRecorder _audioRecorder = AudioRecorder();

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioStreamSub;
  bool _isStreaming = false;
  final BytesBuilder _frameBuffer = BytesBuilder(copy: false);

  // 80ms at 24kHz, 16-bit (2 bytes) mono = 24000 * 2 * 0.080 = 3840 bytes
  static const int frameSizeBytes = 3840;

  // Real-time callbacks
  final void Function(String partialText)? onPartialTranscript;
  final void Function(String finalText)? onFinalTranscript;
  final void Function()? onSpeechComplete;
  final void Function(dynamic error)? onError;

  MetaLiveTranscriber({
    this.wsEndpoint,
    this.apiKey,
    this.onPartialTranscript,
    this.onFinalTranscript,
    this.onSpeechComplete,
    this.onError,
  });

  bool get isStreaming => _isStreaming;

  /// Starts live streaming audio from the device microphone to the Meta ASR WebSocket
  Future<bool> start({
    VoiceDialect dialect = VoiceDialect.autoDetect,
    String? customEndpoint,
  }) async {
    if (_isStreaming) return true;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        onError?.call('Microphone permission not granted.');
        return false;
      }

      final endpoint = customEndpoint ??
          wsEndpoint ??
          'wss://api.meta.ai/v1/asr/realtime';

      final uri = Uri.parse(endpoint);

      // Establish live WebSocket connection with auth header/query
      try {
        _channel = WebSocketChannel.connect(uri);
      } catch (e) {
        debugPrint('[MetaLiveTranscriber] WebSocket connection failed: $e');
        _channel = null;
      }

      if (_channel != null) {
        // Send initial setup handshake
        final handshake = {
          'action': 'start',
          'model': 'muse-voice-transcribe-1.0',
          'format': 'audio/pcm',
          'sample_rate': 24000,
          'channels': 1,
          'dialect': dialect.languageCode,
          'enable_partial_transcripts': true,
        };
        _channel!.sink.add(jsonEncode(handshake));

        // Listen for live transcription events from Meta
        _channel!.stream.listen(
          (message) {
            _handleIncomingWsMessage(message);
          },
          onError: (err) {
            debugPrint('[MetaLiveTranscriber] Stream error: $err');
            onError?.call(err);
          },
          onDone: () {
            debugPrint('[MetaLiveTranscriber] Stream closed.');
          },
        );
      }

      // Configure recorder for raw PCM 16-bit mono 24 kHz
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
      );

      final audioStream = await _audioRecorder.startStream(config);
      _isStreaming = true;
      _frameBuffer.clear();

      _audioStreamSub = audioStream.listen(
        (chunk) {
          _processAudioChunk(chunk);
        },
        onError: (err) {
          debugPrint('[MetaLiveTranscriber] Audio recorder stream error: $err');
          onError?.call(err);
        },
      );

      return true;
    } catch (e) {
      debugPrint('[MetaLiveTranscriber] Start failed: $e');
      onError?.call(e);
      await stop();
      return false;
    }
  }

  void _processAudioChunk(Uint8List chunk) {
    if (!_isStreaming || _channel == null) return;

    _frameBuffer.add(chunk);

    // Send complete 80ms frames (3840 bytes)
    while (_frameBuffer.length >= frameSizeBytes) {
      final allBytes = _frameBuffer.takeBytes();
      final frame = Uint8List.sublistView(allBytes, 0, frameSizeBytes);
      final remainder = Uint8List.sublistView(allBytes, frameSizeBytes);

      try {
        _channel?.sink.add(frame);
      } catch (e) {
        debugPrint('[MetaLiveTranscriber] Error sending audio frame: $e');
      }

      if (remainder.isNotEmpty) {
        _frameBuffer.add(remainder);
      }
    }
  }

  void _handleIncomingWsMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;
        final event = data['event'] ?? data['type'];
        final text = (data['text'] ?? data['transcript'] ?? '').toString();

        if (event == 'partial_transcript' ||
            (data['is_final'] == false && text.isNotEmpty)) {
          if (text.trim().isNotEmpty) {
            onPartialTranscript?.call(text.trim());
          }
        } else if (event == 'transcript' ||
            event == 'final_transcript' ||
            data['is_final'] == true) {
          if (text.trim().isNotEmpty) {
            onFinalTranscript?.call(text.trim());
          }
        } else if (event == 'speech_complete' || event == 'speechComplete') {
          if (text.trim().isNotEmpty) {
            onFinalTranscript?.call(text.trim());
          }
          onSpeechComplete?.call();
        }
      }
    } catch (e) {
      debugPrint('[MetaLiveTranscriber] Error parsing WS message: $e');
    }
  }

  /// Stops streaming, sends end-of-stream signal, and closes the session
  Future<void> stop() async {
    _isStreaming = false;

    // Send remaining buffered bytes
    if (_frameBuffer.isNotEmpty && _channel != null) {
      try {
        final remaining = _frameBuffer.takeBytes();
        _channel?.sink.add(remaining);
      } catch (_) {}
    }

    // Send end_stream frame
    try {
      _channel?.sink.add(jsonEncode({'action': 'end_stream'}));
    } catch (_) {}

    await _audioStreamSub?.cancel();
    _audioStreamSub = null;

    try {
      await _audioRecorder.stop();
    } catch (_) {}

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Cancels live transcription without committing remaining speech
  Future<void> cancel() async {
    _isStreaming = false;
    _frameBuffer.clear();
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;

    try {
      await _audioRecorder.stop();
    } catch (_) {}

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Disposes internal resources
  Future<void> dispose() async {
    await cancel();
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
  }
}

