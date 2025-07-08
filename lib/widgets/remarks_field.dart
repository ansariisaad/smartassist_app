import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class EnhancedSpeechTextField extends StatefulWidget {
  final bool isRequired;
  final String label;
  final TextEditingController controller;
  final String hint;
  final Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? contentPadding;
  final bool showLiveTranscription;
  final Duration listenDuration;
  final Duration pauseDuration;

  const EnhancedSpeechTextField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 5,
    this.minLines = 1,
    this.primaryColor,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 14,
    this.contentPadding,
    this.showLiveTranscription = true,
    this.listenDuration = const Duration(seconds: 30),
    this.pauseDuration = const Duration(seconds: 5),
    required this.isRequired,
  }) : super(key: key);

  @override
  State<EnhancedSpeechTextField> createState() =>
      _EnhancedSpeechTextFieldState();
}

class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  stt.SpeechToText? _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentLocaleId = '';
  late AnimationController _waveController;
  Timer? _forceStopTimer;
  Timer? _stateCheckTimer;
  Timer? _engineSyncTimer;
  bool _isDisposing = false;
  bool _isProcessing = false;
  String? _lastError;

  Color get _primaryColor => widget.primaryColor ?? Colors.grey.shade800;
  Color get _errorColor => Colors.red;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _initSpeechEngine();
    _forceAnimationSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposing = true;
    _cancelAllTimers();
    _waveController.dispose();
    _killSpeechEngine();
    super.dispose();
  }

  void _cancelAllTimers() {
    _forceStopTimer?.cancel();
    _stateCheckTimer?.cancel();
    _engineSyncTimer?.cancel();
  }

  // === Always force UI to match engine ===
  void _forceAnimationSync() {
    _stateCheckTimer?.cancel();
    _stateCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _isDisposing || _speech == null) return;
      final actuallyListening = _speech!.isListening;
      if (_isListening != actuallyListening) {
        setState(() => _isListening = actuallyListening);
        if (actuallyListening) {
          _waveController.repeat();
        } else {
          _waveController.stop();
          _waveController.reset();
        }
      }
      if (!actuallyListening) {
        _waveController.stop();
        _waveController.reset();
      }
    });
  }

  Future<void> _killSpeechEngine() async {
    try {
      if (_speech != null) {
        if (_speech!.isListening) {
          await _speech!.stop();
          await Future.delayed(const Duration(milliseconds: 100));
          await _speech!.cancel();
        }
      }
    } catch (_) {}
    _speech = null;
  }

  Future<void> _initSpeechEngine() async {
    _isProcessing = true;
    await _killSpeechEngine();
    _speech = stt.SpeechToText();
    try {
      bool hasPermission = await _checkMicrophonePermission();
      if (!mounted) return;
      if (!hasPermission) {
        setState(() => _isInitialized = true);
        _isProcessing = false;
        return;
      }
      _speechAvailable = await _speech!.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );
      if (_speechAvailable) {
        final locales = await _speech!.locales();
        debugPrint('Available locales:');
        for (var locale in locales) {
          debugPrint('${locale.localeId} (${locale.name})');
        }
        // Pick your preferred locale or default to first
        List<String> englishLocaleIds = [
          'en_US',
          'en_GB',
          'en_IN',
          'en_AU',
          'en_CA',
          'en_IE',
          'en_SG',
        ];
        _currentLocaleId = locales
            .map((l) => l.localeId)
            .firstWhere(
              (id) => englishLocaleIds.contains(id),
              orElse: () => locales.first.localeId,
            );
        debugPrint('Speech will use locale: $_currentLocaleId');
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Speech init error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
      }
    }
    _isProcessing = false;
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      if (Platform.isIOS) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.microphone,
          Permission.speech,
        ].request();

        bool micGranted = statuses[Permission.microphone]?.isGranted ?? false;
        bool speechGranted = statuses[Permission.speech]?.isGranted ?? false;
        if (!micGranted || !speechGranted) {
          _showPermissionDialog();
          return false;
        }
        return true;
      } else {
        PermissionStatus micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _showPermissionDialog();
        }
        return micStatus.isGranted;
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app needs microphone and speech recognition permissions to work properly. Please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('[onStatus] $status');
    if (status == 'notListening' || status == 'done') {
      _updateListeningUI(false);
      _forceStopTimer?.cancel();
      // Aggressive cleanup to prevent system sound popup
      Future.delayed(const Duration(milliseconds: 50), () async {
        if (mounted && _speech != null) {
          try {
            await _speech!.cancel();
            // Additional delay and reinit to ensure clean state
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted && !_isListening) {
              _initSpeechEngine();
            }
          } catch (_) {}
        }
      });
    } else if (status == 'listening') {
      _updateListeningUI(true);
      _startForceStopTimer();
    }
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;
    debugPrint('[onError] $error');
    _updateListeningUI(false);
    _lastError = error.toString();
    _showFeedback(_getErrorMessage(_lastError!), isError: true);
    _forceStopTimer?.cancel();

    // Aggressive cleanup to prevent system sound popup after error
    Future.delayed(const Duration(milliseconds: 50), () async {
      if (mounted && _speech != null) {
        try {
          await _speech!.cancel();
          // Kill and reinitialize engine to prevent phantom mic sounds
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && !_isListening) {
            await _killSpeechEngine();
            await Future.delayed(const Duration(milliseconds: 200));
            _initSpeechEngine();
          }
        } catch (_) {}
      }
    });

    // For Samsung bug: show help
    if (_lastError != null &&
        (_lastError!.contains('Speech recognition not available') ||
            _lastError!.contains('ERROR_CLIENT') ||
            _lastError!.contains('not available on device'))) {
      _showSamsungSpeechErrorDialog();
    }
  }

  void _showSamsungSpeechErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speech Input Not Working'),
        content: const Text(
          'Speech-to-text is not available on your device or requires Samsung Voice Input to be enabled. '
          '\n\nPlease:\n'
          '1. Go to Settings > General Management > Keyboard list and default\n'
          '2. Enable Google Voice Typing or your preferred Speech service\n'
          '3. Set it as default\n'
          'If problem persists, try updating Google App and Samsung Keyboard via Play Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _updateListeningUI(bool listening) {
    if (!mounted) return;
    if (_isListening != listening) {
      setState(() => _isListening = listening);
    }
    if (listening) {
      _waveController.repeat();
    } else {
      _waveController.stop();
      _waveController.reset();
    }
  }

  void _startForceStopTimer() {
    _forceStopTimer?.cancel();
    _forceStopTimer = Timer(const Duration(seconds: 10), () async {
      if (mounted && _isListening) {
        debugPrint('[SAFETY TIMEOUT] No speech or engine event - force stop.');
        // Immediate UI update
        _updateListeningUI(false);

        // Aggressive cleanup sequence to prevent system sound popup
        try {
          if (_speech != null && _speech!.isListening) {
            await _speech!.stop();
            await Future.delayed(const Duration(milliseconds: 300));
            await _speech!.cancel();
            await Future.delayed(const Duration(milliseconds: 200));
            // Kill and reinitialize engine to ensure clean state
            await _killSpeechEngine();
            await Future.delayed(const Duration(milliseconds: 300));
            _initSpeechEngine();
          }
        } catch (_) {}

        _showFeedback("Mic stopped due to inactivity.", isError: true);
      }
    });
  }

  Future<void> _startListening() async {
    if (!mounted || !_isInitialized || !_speechAvailable || _isProcessing)
      return;
    if (_speech == null) return;
    // Extra permission check for Android/Samsung
    if (!await _checkMicrophonePermission()) {
      _showFeedback("Please enable microphone permissions!", isError: true);
      return;
    }

    if (_speech!.isListening) {
      await _speech!.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _updateListeningUI(true);
    try {
      await _speech!.listen(
        onResult: _onSpeechResult,
        listenFor: widget.listenDuration,
        pauseFor: widget.pauseDuration,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
      _startForceStopTimer();
    } catch (e) {
      _updateListeningUI(false);
      _showFeedback(_getErrorMessage(e.toString()), isError: true);
      _forceStopTimer?.cancel();

      // Samsung fix
      if (e.toString().contains('Speech recognition not available') ||
          e.toString().contains('ERROR_CLIENT') ||
          e.toString().contains('not available on device')) {
        _showSamsungSpeechErrorDialog();
      }
    }
  }

  Future<void> _stopListening() async {
    if (!mounted || _speech == null) return;
    _forceStopTimer?.cancel();

    // Set UI state immediately to prevent any new operations
    _updateListeningUI(false);

    try {
      if (_speech!.isListening) {
        // Stop first
        await _speech!.stop();
        // Wait longer to ensure stop is processed
        await Future.delayed(const Duration(milliseconds: 300));
        // Force cancel to ensure microphone is completely released
        await _speech!.cancel();
        // Additional delay to ensure system processes the cancel
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {}

    // Force reinitialize speech engine to clean state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isListening) {
        _initSpeechEngine();
      }
    });
  }

  String _getErrorMessage(String error) {
    if (error.contains('speech timeout') || error.contains('e_4')) {
      return 'Listening timed out. Please speak sooner.';
    } else if (error.contains('no-speech') || error.contains('e_6')) {
      return 'No speech was detected.';
    } else if (error.contains('network') || error.contains('e_7')) {
      return 'A network error occurred.';
    } else if (error.contains('audio') || error.contains('e_3')) {
      return 'Microphone access error.';
    } else if (error.contains('Speech recognition not available') ||
        error.contains('ERROR_CLIENT')) {
      return 'Speech-to-text is not available on this device. Please check your keyboard or voice input settings.';
    }
    return 'No speech was detected.';
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!mounted) return;
    if (result.finalResult) {
      _addToTextField(result.recognizedWords);
      // Stop listening immediately after getting final result
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (mounted && _isListening) {
          // Immediate UI update
          _updateListeningUI(false);

          // Aggressive cleanup to prevent system sound popup
          try {
            if (_speech != null && _speech!.isListening) {
              await _speech!.stop();
              await Future.delayed(const Duration(milliseconds: 300));
              await _speech!.cancel();
            }
          } catch (_) {}
        }
      });
    }
    if (_isListening) _startForceStopTimer();
  }

  void _addToTextField(String words) {
    if (words.trim().isEmpty) return;
    String currentText = widget.controller.text;
    String formattedWords = words.trim();
    if (formattedWords.isNotEmpty) {
      formattedWords =
          formattedWords[0].toUpperCase() + formattedWords.substring(1);
    }
    if (currentText.isEmpty || currentText.endsWith(' ')) {
      widget.controller.text += formattedWords;
    } else {
      widget.controller.text += ' $formattedWords';
    }
    if (!widget.controller.text.endsWith(' ')) {
      widget.controller.text += ' ';
    }
    widget.onChanged?.call(widget.controller.text);
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _errorColor : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state.toString() == 'AppLifecycleState.hidden') {
      _stopListening();
      _waveController.stop();
      _waveController.reset();
    }
    if (state == AppLifecycleState.resumed) {
      _forceAnimationSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildLabel(), _buildInputContainer()],
    );
  }

  Widget _buildLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          children: [
            TextSpan(text: widget.label),
            if (widget.isRequired)
              const TextSpan(
                text: " *",
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputContainer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: widget.backgroundColor ?? Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Expanded(child: _buildTextField()),
          _buildSpeechButton(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled && !_isListening,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: _isListening ? "Listening..." : widget.hint,
        hintStyle: GoogleFonts.poppins(
          color: _isListening ? _primaryColor : Colors.grey.shade600,
        ),
        contentPadding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: InputBorder.none,
      ),
      style: TextStyle(
        fontSize: widget.fontSize,
        color: widget.textColor ?? Colors.black,
      ),
    );
  }

  Widget _buildSpeechButton() {
    if (!_isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      onPressed: (_speechAvailable && !_isProcessing)
          ? () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
            }
          : null,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
          key: ValueKey(_isListening),
          color: _isListening
              ? Colors.red
              : (_speechAvailable ? _primaryColor : Colors.grey),
          size: 16,
        ),
      ),
      tooltip: _isListening ? 'Stop recording' : 'Start voice input',
      splashRadius: 24,
    );
  }
}
