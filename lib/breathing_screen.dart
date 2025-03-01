import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'services/breathing_service.dart';
import 'package:flutter/widgets.dart';

class BreathingScreen extends StatefulWidget {
  final BreathingExercise exercise;

  const BreathingScreen({super.key, required this.exercise});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late AudioPlayer _audioPlayer;
  String _currentPhase = 'Get Ready';
  bool _isPlaying = false;
  String _motivationalMessage = '';

  final List<String> _motivationalMessages = [
    "You're doing great, keep breathing",
    "Let go of your worries with each breath",
    "Feel your anxiety melting away",
    "You are stronger than your anxiety",
    "Stay present in this moment",
    "You're taking control of your peace",
    "Each breath brings more calmness",
    "Trust in your inner strength",
    "You're safe and in control",
    "This feeling will pass",
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudio();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _getTotalCycleDuration()),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reset();
        _animationController.forward();
        _updateMotivationalMessage();
      }
    });

    // Show headphone recommendation popup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHeadphoneRecommendation();
    });
  }

  Future<void> _setupAudio() async {
    if (widget.exercise.soundUrl != null) {
      await _audioPlayer.setAsset(widget.exercise.soundUrl!);
      await _audioPlayer.setLoopMode(LoopMode.one);
    }
  }

  int _getTotalCycleDuration() {
    return widget.exercise.inhaleTime +
        widget.exercise.holdTime +
        widget.exercise.exhaleTime +
        widget.exercise.holdOutTime;
  }

  void _showHeadphoneRecommendation() {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(), // Dismiss on tap
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(), // Dismiss on tap
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones,
                      size: 50,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Best Experience with Headphones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For optimal relaxation, we recommend using headphones\n\nTap anywhere to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateMotivationalMessage() {
    if (_isPlaying) {
      setState(() {
        _motivationalMessage = _motivationalMessages[
            DateTime.now().millisecondsSinceEpoch %
                _motivationalMessages.length];
      });
    }
  }

  void _startExercise() {
    setState(() {
      _isPlaying = true;
      _updateMotivationalMessage();
    });
    _animationController.forward();
    if (widget.exercise.soundUrl != null) {
      _audioPlayer.play();
    }
  }

  void _stopExercise() {
    setState(() {
      _isPlaying = false;
      _currentPhase = 'Complete';
    });
    _animationController.reset();
    _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade200,
              Colors.green.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.exercise.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Exercise Info Card
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.exercise.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              widget.exercise.technique,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Breathing Animation
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          double value = _animationController.value;
                          double totalDuration =
                              _getTotalCycleDuration().toDouble();
                          double inhaleDuration =
                              widget.exercise.inhaleTime / totalDuration;
                          double holdDuration = (widget.exercise.inhaleTime +
                                  widget.exercise.holdTime) /
                              totalDuration;
                          double exhaleDuration = (widget.exercise.inhaleTime +
                                  widget.exercise.holdTime +
                                  widget.exercise.exhaleTime) /
                              totalDuration;

                          double size;
                          if (value < inhaleDuration) {
                            _currentPhase = 'Inhale';
                            size = 150 + (value / inhaleDuration) * 100;
                          } else if (value < holdDuration) {
                            _currentPhase = 'Hold';
                            size = 250;
                          } else if (value < exhaleDuration) {
                            _currentPhase = 'Exhale';
                            double exhaleProgress = (value - holdDuration) /
                                (exhaleDuration - holdDuration);
                            size = 250 - (exhaleProgress * 100);
                          } else {
                            _currentPhase = 'Hold';
                            size = 150;
                          }

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: size + 40,
                                height: size + 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.green.shade300,
                                      Colors.green.shade500,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentPhase,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (_isPlaying)
                                        Text(
                                          '${(value * _getTotalCycleDuration()).toInt()} s',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.white70,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Motivational Message
                      if (_isPlaying)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _motivationalMessage,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const Spacer(),

                      // Control Button
                      Container(
                        margin: const EdgeInsets.only(bottom: 32),
                        child: ElevatedButton(
                          onPressed:
                              _isPlaying ? _stopExercise : _startExercise,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPlaying
                                ? Colors.red.shade400
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 48, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                                  size: 28),
                              const SizedBox(width: 8),
                              Text(
                                _isPlaying ? 'Stop Exercise' : 'Start Exercise',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
