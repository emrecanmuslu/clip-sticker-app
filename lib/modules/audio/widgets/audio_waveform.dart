import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class CustomWaveform extends StatefulWidget {
  final String audioPath;
  final double startTime;
  final double endTime;
  final double duration;
  final double maxDuration;
  final Function(double start, double end) onSeek;
  final PlayerController playerController;

  const CustomWaveform({
    Key? key,
    required this.audioPath,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.maxDuration,
    required this.onSeek,
    required this.playerController,
  }) : super(key: key);

  @override
  State<CustomWaveform> createState() => _CustomWaveformState();
}

class _CustomWaveformState extends State<CustomWaveform> {
  static const double minDuration = 5.0;
  static const double handleWidth = 24.0;
  static const double horizontalPadding = 16.0;
  static const double waveformHeight = 100.0;
  static const double handleHeight = 100.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 800.0;
  static const double defaultZoom = 280.0;

  late double _startPosition;
  late double _endPosition;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _scaleFactor = defaultZoom;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _positionSubscription;
  double _currentPosition = 0;

  @override
  void initState() {
    super.initState();
    _initializePositions();
    _setupPositionListener();
  }

  void _setupPositionListener() {
    _positionSubscription?.cancel();
    _positionSubscription =
        widget.playerController.onCurrentDurationChanged.listen((duration) {
      setState(() {
        _currentPosition = duration / 1000; // ms to seconds
      });
    });
  }

  @override
  void dispose() {
    if (_isPlaying) {
      widget.playerController.pausePlayer();
    }
    _positionSubscription?.cancel();
    _scrollController.dispose();
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
    setState(() => _isInitialized = true);
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

  StreamSubscription? _playbackSubscription;

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        _playbackSubscription?.cancel();
        await widget.playerController.pausePlayer();
        setState(() => _isPlaying = false);
        return;
      }

      setState(() => _isPlaying = true);
      await widget.playerController.seekTo((_startPosition * 1000).toInt());
      await widget.playerController.startPlayer();

      _playbackSubscription?.cancel();
      _playbackSubscription =
          widget.playerController.onCurrentDurationChanged.listen((duration) {
        final position = duration / 1000;
        setState(() => _currentPosition = position);

        final positionFixed = double.parse(position.toStringAsFixed(1));
        final endPositionFixed = double.parse(_endPosition.toStringAsFixed(1));

        if (positionFixed >= endPositionFixed - 0.5) {
          _playbackSubscription?.cancel();
          widget.playerController.pausePlayer();
          widget.playerController.seekTo((_startPosition * 1000).toInt());
          setState(() {
            _isPlaying = false;
            _currentPosition = _startPosition;
          });
        }
      });
    } catch (e) {
      print('Oynatma hatası: $e');
      setState(() => _isPlaying = false);
    }
  }

  void _handleZoomIn() {
    setState(() {
      _scaleFactor = (_scaleFactor * 1.1).clamp(minZoom, maxZoom);
    });
  }

  void _handleZoomOut() {
    setState(() {
      _scaleFactor = (_scaleFactor / 1.1).clamp(minZoom, maxZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final pixelsPerSecond = availableWidth / widget.duration;
        final zoomScale = _scaleFactor / defaultZoom;
        final scaledWidth = constraints.maxWidth * zoomScale;
        final fixZoomScale = zoomScale.toStringAsFixed(1);

        return Column(
          children: [
            // 1. Zaman Göstergesi
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_startPosition),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (_isPlaying)
                    Text(
                      _formatDuration(_currentPosition),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  Text(
                    _formatDuration(_endPosition),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 2. Dalga Formu ve Oynatma Kontrolü
            Container(
              height: waveformHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: !_isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is ScrollUpdateNotification) {
                          final delta = notification.scrollDelta ?? 0;
                          final scrollDeltaInSeconds =
                              delta / (pixelsPerSecond * zoomScale);

                          final newStart =
                              _startPosition + scrollDeltaInSeconds;
                          final newEnd = _endPosition + scrollDeltaInSeconds;

                          if (newStart >= 0 && newEnd <= widget.duration) {
                            setState(() {
                              _startPosition = newStart;
                              _endPosition = newEnd;
                            });
                          }
                        }
                        return true;
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: scaledWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: horizontalPadding),
                                  child: AudioFileWaveforms(
                                    size: Size(scaledWidth, waveformHeight),
                                    playerController: widget.playerController,
                                    enableSeekGesture: false,
                                    waveformType: WaveformType.fitWidth,
                                    playerWaveStyle: PlayerWaveStyle(
                                      fixedWaveColor: Colors.grey.shade300,
                                      liveWaveColor: Colors.grey.shade300,
                                      spacing: 4,
                                      backgroundColor: Colors.white,
                                      showTop: true,
                                      showBottom: true,
                                      showSeekLine: true,
                                      seekLineColor: Colors.red,
                                      seekLineThickness: 2,
                                      scaleFactor: _scaleFactor,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isPlaying)
                                Positioned(
                                  left: horizontalPadding +
                                      (_currentPosition *
                                          pixelsPerSecond *
                                          zoomScale),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 2,
                                    color: Colors.red,
                                  ),
                                ),
                              Positioned(
                                left: horizontalPadding +
                                    (_startPosition *
                                        pixelsPerSecond *
                                        zoomScale),
                                width: (_endPosition - _startPosition) *
                                    pixelsPerSecond *
                                    zoomScale,
                                top: 0,
                                height: handleHeight,
                                child: GestureDetector(
                                  onHorizontalDragUpdate: !_isPlaying
                                      ? (details) {
                                          final delta = details.delta.dx /
                                              (pixelsPerSecond * zoomScale);
                                          final newStart =
                                              _startPosition + delta;
                                          final newEnd = _endPosition + delta;

                                          if (newStart >= 0 &&
                                              newEnd <= widget.duration) {
                                            _updatePositions(newStart, newEnd);
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(_isPlaying ? 0.1 : 0.3),
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isPlaying)
                                _buildPositionHandle(
                                  context: context,
                                  position: _startPosition,
                                  pixelsPerSecond: pixelsPerSecond,
                                  zoomScale: zoomScale,
                                  isStart: true,
                                  onDragStart: () => _isDraggingStart = true,
                                  onDragUpdate: (details, isStart) {
                                    final RenderBox box =
                                        context.findRenderObject() as RenderBox;
                                    final localPosition = box
                                        .globalToLocal(details.globalPosition);
                                    final newStart =
                                        (localPosition.dx - horizontalPadding) /
                                            (pixelsPerSecond * zoomScale);

                                    if (newStart >= 0 &&
                                        newStart < _endPosition) {
                                      _updatePositions(newStart, _endPosition);
                                    }
                                  },
                                  onDragEnd: () => _isDraggingStart = false,
                                ),
                              if (!_isPlaying)
                                _buildPositionHandle(
                                  context: context,
                                  position: _endPosition,
                                  pixelsPerSecond: pixelsPerSecond,
                                  zoomScale: zoomScale,
                                  isStart: false,
                                  onDragStart: () => _isDraggingEnd = true,
                                  onDragUpdate: (details, isStart) {
                                    final RenderBox box =
                                        context.findRenderObject() as RenderBox;
                                    final localPosition = box
                                        .globalToLocal(details.globalPosition);
                                    final newEnd =
                                        (localPosition.dx - horizontalPadding) /
                                            (pixelsPerSecond * zoomScale);

                                    if (newEnd <= widget.duration &&
                                        newEnd > _startPosition) {
                                      _updatePositions(_startPosition, newEnd);
                                    }
                                  },
                                  onDragEnd: () => _isDraggingEnd = false,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Kontrol Paneli
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause Butonu
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 32,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                ),

                const SizedBox(width: 16),

                // Zoom Kontrolleri
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_out),
                        onPressed:
                            fixZoomScale != '1.0' ? _handleZoomOut : null,
                        tooltip: 'Uzaklaş',
                        color: _scaleFactor > minZoom ? null : Colors.grey,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Zoom: ${fixZoomScale}x',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in),
                        onPressed: fixZoomScale != '2.9' ? _handleZoomIn : null,
                        tooltip: 'Yakınlaş',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionHandle({
    required BuildContext context,
    required double position,
    required double pixelsPerSecond,
    required double zoomScale,
    required bool isStart,
    required VoidCallback onDragStart,
    required Function(DragUpdateDetails, bool isStart) onDragUpdate,
    required VoidCallback onDragEnd,
  }) {
    return Positioned(
      left: horizontalPadding +
          (position * pixelsPerSecond * zoomScale) -
          (handleWidth / 2),
      top: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (details) => onDragUpdate(details, isStart),
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
