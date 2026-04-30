import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'dart:io';

class AudioPlayerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AudioPlayerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with WidgetsBindingObserver {
  late ja.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _isLooping = false;
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      _audioPlayer = ja.AudioPlayer();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await _audioPlayer.setFilePath(widget.filePath);

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _isLoading = state.processingState == ja.ProcessingState.loading;
          });
        }
      });

      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _audioPlayer.playbackEventStream.listen((event) {
        if (event.processingState == ja.ProcessingState.completed) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _play() async => await _audioPlayer.play();
  Future<void> _pause() async => await _audioPlayer.pause();

  Future<void> _stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    setState(() => _position = Duration.zero);
  }

  Future<void> _seek(Duration position) async => await _audioPlayer.seek(position);

  Future<void> _changeSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
    setState(() => _currentSpeed = speed);
  }

  Future<void> _toggleLoop() async {
    await _audioPlayer.setLoopMode(_isLooping ? ja.LoopMode.off : ja.LoopMode.one);
    setState(() => _isLooping = !_isLooping);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A3E),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Audio Player',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat, color: Colors.white),
            onPressed: _toggleLoop,
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.speed, color: Colors.white),
            onSelected: _changeSpeed,
            itemBuilder: (context) => _speedOptions.map((speed) {
              return PopupMenuItem<double>(
                value: speed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${speed}x'),
                    if (speed == _currentSpeed)
                      const Icon(Icons.check, size: 16, color: Colors.green),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A1F), Color(0xFF141432), Color(0xFF1A1A3E)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4788FF)),
            SizedBox(height: 16),
            Text('Loading audio...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Error loading audio file', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _initAudioPlayer();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4788FF)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        Container(
          width: 200,
          height: 200,
          margin: const EdgeInsets.only(bottom: 30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)]),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4788FF).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _isPlaying ? Icons.music_note : Icons.music_off,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.fileName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),

        const SizedBox(height: 8),
        Text('Speed: ${_currentSpeed}x', style: const TextStyle(color: Color(0xFF4788FF))),
        const SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF4788FF),
                  inactiveTrackColor: Colors.grey.withOpacity(0.3),
                  thumbColor: const Color(0xFF4788FF),
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  value: _position.inSeconds.toDouble(),
                  onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: const TextStyle(color: Colors.grey)),
                    Text(_formatDuration(_duration), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.replay_10, color: Colors.white, size: 30),
              ),
              onPressed: () {
                final newPos = _position - const Duration(seconds: 10);
                _seek(newPos < Duration.zero ? Duration.zero : newPos);
              },
            ),
            const SizedBox(width: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4788FF).withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30),
                onPressed: () => _isPlaying ? _pause() : _play(),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.forward_10, color: Colors.white, size: 30),
              ),
              onPressed: () {
                final newPos = _position + const Duration(seconds: 10);
                _seek(newPos > _duration ? _duration : newPos);
              },
            ),
          ],
        ),

        const SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _volume,
                  activeColor: const Color(0xFF4788FF),
                  onChanged: (value) {
                    setState(() => _volume = value);
                    _audioPlayer.setVolume(value);
                  },
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.grey),
            ],
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop, color: Colors.red),
          label: const Text('Stop', style: TextStyle(color: Colors.red)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            side: BorderSide(color: Colors.red.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }
}
