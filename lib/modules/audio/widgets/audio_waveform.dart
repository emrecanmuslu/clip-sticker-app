import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class CustomWaveform extends StatefulWidget {
  final String audioPath;
  final double startTime;
  final double endTime;
  final double duration;
  final double maxDuration;
  final Function(double start, double end) onSeek;

  const CustomWaveform({
    Key? key,
    required this.audioPath,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.maxDuration,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<CustomWaveform> createState() => _CustomWaveformState();
}

class _CustomWaveformState extends State<CustomWaveform> {
  static const double minDuration = 1.0;
  static const double handleWidth = 24.0; // Genişliği artırdık
  static const double horizontalPadding = 24.0; // Padding'i azalttık
  static const double waveformHeight = 100.0;
  static const double handleHeight = 100.0;

  late PlayerController _playerController;
  late double _startPosition;
  late double _endPosition;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializePositions();
  }

  Future<void> _initializePlayer() async {
    _playerController = PlayerController();
    try {
      await _playerController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
        noOfSamples: 150, // Örnek sayısını artırdık
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Ses yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.endTime != widget.endTime) {
      _initializePositions();
    }
  }

  void _initializePositions() {
    _startPosition = widget.startTime;
    _endPosition = widget.endTime;
  }

  double _normalizePosition(double position) {
    return position.clamp(0.0, widget.duration);
  }

  void _updatePositions(double start, double end) {
    if (end - start < minDuration) {
      if (_isDraggingStart) {
        start = end - minDuration;
      } else if (_isDraggingEnd) {
        end = start + minDuration;
      }
    }

    if (end - start > widget.maxDuration) {
      if (_isDraggingStart) {
        start = end - widget.maxDuration;
      } else if (_isDraggingEnd) {
        end = start + widget.maxDuration;
      }
    }

    start = _normalizePosition(start);
    end = _normalizePosition(end);

    setState(() {
      _startPosition = start;
      _endPosition = end;
    });

    widget.onSeek(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final pixelsPerSecond = availableWidth / widget.duration;

        return Container(
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Dalga formu
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: horizontalPadding),
                        child: AudioFileWaveforms(
                          size: Size(availableWidth, waveformHeight),
                          playerController: _playerController,
                          enableSeekGesture: false,
                          waveformType: WaveformType.fitWidth,
                          playerWaveStyle: PlayerWaveStyle(
                            fixedWaveColor: Colors.grey.shade300,
                            liveWaveColor: Theme.of(context).primaryColor,
                            spacing: 4,
                            backgroundColor: Colors.white,
                            showTop: true,
                            showBottom: true,
                            showSeekLine: false,
                            scaleFactor: 280.0,
                          ),
                        ),
                      ),
                    ),
                    // Seçili alan overlay
                    Positioned(
                      left: horizontalPadding +
                          (_startPosition * pixelsPerSecond),
                      width: (_endPosition - _startPosition) * pixelsPerSecond,
                      top: 0,
                      height: handleHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Sol tutamaç
                    _buildPositionHandle(
                      context: context,
                      position: _startPosition,
                      pixelsPerSecond: pixelsPerSecond,
                      isStart: true,
                      onDragStart: () => _isDraggingStart = true,
                      onDragUpdate: (details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final localPosition =
                            box.globalToLocal(details.globalPosition);
                        final newStart =
                            (localPosition.dx - horizontalPadding) /
                                pixelsPerSecond;
                        _updatePositions(newStart, _endPosition);
                      },
                      onDragEnd: () => _isDraggingStart = false,
                    ),
                    // Sağ tutamaç
                    _buildPositionHandle(
                      context: context,
                      position: _endPosition,
                      pixelsPerSecond: pixelsPerSecond,
                      isStart: false,
                      onDragStart: () => _isDraggingEnd = true,
                      onDragUpdate: (details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final localPosition =
                            box.globalToLocal(details.globalPosition);
                        final newEnd = (localPosition.dx - horizontalPadding) /
                            pixelsPerSecond;
                        _updatePositions(_startPosition, newEnd);
                      },
                      onDragEnd: () => _isDraggingEnd = false,
                    ),
                    // Süre göstergeleri
                    Positioned(
                      top: -20,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_startPosition),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            _formatDuration(_endPosition),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPositionHandle({
    required BuildContext context,
    required double position,
    required double pixelsPerSecond,
    required bool isStart,
    required VoidCallback onDragStart,
    required Function(DragUpdateDetails) onDragUpdate,
    required VoidCallback onDragEnd,
  }) {
    return Positioned(
      left:
          horizontalPadding + (position * pixelsPerSecond) - (handleWidth / 2),
      top: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: SizedBox(
          width: handleWidth,
          height: handleHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 2,
                height: handleHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    Duration duration = Duration(milliseconds: (seconds * 1000).round());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
