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
  static const double minDuration = 5.0;
  static const double handleWidth = 24.0;
  static const double horizontalPadding = 16.0;
  static const double waveformHeight = 100.0;
  static const double handleHeight = 100.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 800.0;
  static const double defaultZoom = 280.0;

  late PlayerController _playerController;
  late double _startPosition;
  late double _endPosition;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _isInitialized = false;
  double _scaleFactor = defaultZoom;
  final ScrollController _scrollController = ScrollController();

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
        noOfSamples: 300,
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Ses yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
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
            // Zoom kontrolleri
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    onPressed: fixZoomScale != '1.0' ? _handleZoomOut : null,
                    tooltip: 'Uzaklaş',
                    color: _scaleFactor > minZoom ? null : Colors.grey,
                  ),
                  Text(
                    'Zoom: ${fixZoomScale}x',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    onPressed: fixZoomScale != '2.9' ? _handleZoomIn : null,
                    tooltip: 'Yakınlaş',
                  ),
                ],
              ),
            ),
            // Süre göstergeleri (zoom durumundan bağımsız)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
            const SizedBox(height: 8), // Küçük bir boşluk
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

                          // Scroll delta'sını zoom oranına göre normalize et
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
                              // Dalga formu
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: horizontalPadding),
                                  child: AudioFileWaveforms(
                                    size: Size(scaledWidth, waveformHeight),
                                    playerController: _playerController,
                                    enableSeekGesture: false,
                                    waveformType: WaveformType.fitWidth,
                                    playerWaveStyle: PlayerWaveStyle(
                                      fixedWaveColor: Colors.grey.shade300,
                                      liveWaveColor:
                                          Theme.of(context).primaryColor,
                                      spacing: 4,
                                      backgroundColor: Colors.white,
                                      showTop: true,
                                      showBottom: true,
                                      showSeekLine: false,
                                      scaleFactor: _scaleFactor,
                                    ),
                                  ),
                                ),
                              ),
                              // Seçili alan
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
                                  onHorizontalDragUpdate: (details) {
                                    final delta = details.delta.dx /
                                        (pixelsPerSecond * zoomScale);
                                    final newStart = _startPosition + delta;
                                    final newEnd = _endPosition + delta;

                                    if (newStart >= 0 &&
                                        newEnd <= widget.duration) {
                                      _updatePositions(newStart, newEnd);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1),
                                    ),
                                  ),
                                ),
                              ),
                              // Sol tutamaç
                              _buildPositionHandle(
                                context: context,
                                position: _startPosition,
                                pixelsPerSecond: pixelsPerSecond,
                                zoomScale: zoomScale,
                                isStart: true,
                                onDragStart: () => _isDraggingStart = true,
                                onDragUpdate: (details) {
                                  final RenderBox box =
                                      context.findRenderObject() as RenderBox;
                                  final localPosition =
                                      box.globalToLocal(details.globalPosition);
                                  final newStart =
                                      (localPosition.dx - horizontalPadding) /
                                          (pixelsPerSecond * zoomScale);
                                  _updatePositions(newStart, _endPosition);
                                },
                                onDragEnd: () => _isDraggingStart = false,
                              ),
                              // Sağ tutamaç
                              _buildPositionHandle(
                                context: context,
                                position: _endPosition,
                                pixelsPerSecond: pixelsPerSecond,
                                zoomScale: zoomScale,
                                isStart: false,
                                onDragStart: () => _isDraggingEnd = true,
                                onDragUpdate: (details) {
                                  final RenderBox box =
                                      context.findRenderObject() as RenderBox;
                                  final localPosition =
                                      box.globalToLocal(details.globalPosition);
                                  final newEnd =
                                      (localPosition.dx - horizontalPadding) /
                                          (pixelsPerSecond * zoomScale);
                                  _updatePositions(_startPosition, newEnd);
                                },
                                onDragEnd: () => _isDraggingEnd = false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
    required Function(DragUpdateDetails) onDragUpdate,
    required VoidCallback onDragEnd,
  }) {
    return Positioned(
      left: horizontalPadding +
          (position * pixelsPerSecond * zoomScale) -
          (handleWidth / 2),
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
