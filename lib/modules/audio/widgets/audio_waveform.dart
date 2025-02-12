import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

enum _DragMode { none, startThumb, endThumb, range }

class CustomWaveform extends StatefulWidget {
  final String audioPath;
  final double startTime;
  final double endTime;
  final double duration;
  final Color waveColor;
  final Color selectedColor;
  final Color backgroundColor;
  final double height;
  final PlayerController playerController;
  final Function(double, double) onSeek;
  final double maxDuration;
  final PlayerWaveStyle? customWaveStyle;

  const CustomWaveform({
    super.key,
    required this.audioPath,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.playerController,
    required this.onSeek,
    required this.maxDuration,
    this.waveColor = Colors.grey,
    this.selectedColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.height = 100,
    this.customWaveStyle,
  });

  @override
  State<CustomWaveform> createState() => _CustomWaveformState();
}

class _CustomWaveformState extends State<CustomWaveform> {
  late PlayerWaveStyle _waveStyle;
  _DragMode _currentDragMode = _DragMode.none;
  Offset? _dragStartPosition;
  double? _initialStartTime;
  double? _initialEndTime;

  @override
  void initState() {
    super.initState();
    _initializeWaveStyle();
  }

  void _initializeWaveStyle() {
    _waveStyle = widget.customWaveStyle ??
        PlayerWaveStyle(
          fixedWaveColor: widget.waveColor,
          liveWaveColor: widget.selectedColor,
          spacing: 4,
          waveThickness: 2,
          scaleFactor: 80,
          waveCap: StrokeCap.round,
        );
  }

  // Pozisyonu süreye çevirme
  double _convertPositionToDuration(double position, Size size) {
    return (position / size.width) * widget.duration;
  }

  // Sürekliliği kontrol etme
  bool _isValidTimeRange(double start, double end) {
    return start >= 0 &&
        end <= widget.duration &&
        end - start <= widget.maxDuration &&
        end - start >= 1; // Minimum 1 saniye
  }

  // Sürüklenme modunu belirleme
  _DragMode _determineDragMode(Offset localPosition, Size size) {
    final startThumbPosition = widget.startTime / widget.duration * size.width;
    final endThumbPosition = widget.endTime / widget.duration * size.width;

    const thumbTouchWidth = 30.0; // Daha geniş dokunma alanı
    final selectionAreaWidth = endThumbPosition - startThumbPosition;

    // Start thumbun dokunma alanı
    if ((localPosition.dx - startThumbPosition).abs() < thumbTouchWidth) {
      return _DragMode.startThumb;
    }

    // End thumbun dokunma alanı
    if ((localPosition.dx - endThumbPosition).abs() < thumbTouchWidth) {
      return _DragMode.endThumb;
    }

    // Seçili alan içindeki alan
    if (localPosition.dx >= startThumbPosition &&
        localPosition.dx <= endThumbPosition) {
      return _DragMode.range;
    }

    return _DragMode.none;
  }

  void _handleDragStart(DragStartDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    _dragStartPosition = localPosition;
    _initialStartTime = widget.startTime;
    _initialEndTime = widget.endTime;
    _currentDragMode = _determineDragMode(localPosition, renderBox.size);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final dragDelta = _convertPositionToDuration(
        details.localPosition.dx - _dragStartPosition!.dx, renderBox.size);

    switch (_currentDragMode) {
      case _DragMode.startThumb:
        final newStartTime = (_initialStartTime ?? 0) + dragDelta;
        final newEndTime = _initialEndTime ?? widget.duration;

        if (_isValidTimeRange(newStartTime, newEndTime)) {
          widget.onSeek(newStartTime, newEndTime);
        }
        break;

      case _DragMode.endThumb:
        final newStartTime = _initialStartTime ?? 0;
        final newEndTime = (_initialEndTime ?? 0) + dragDelta;

        if (_isValidTimeRange(newStartTime, newEndTime)) {
          widget.onSeek(newStartTime, newEndTime);
        }
        break;

      case _DragMode.range:
        final newStartTime = (_initialStartTime ?? 0) + dragDelta;
        final newEndTime = (_initialEndTime ?? 0) + dragDelta;

        if (_isValidTimeRange(newStartTime, newEndTime)) {
          widget.onSeek(newStartTime, newEndTime);
        }
        break;

      case _DragMode.none:
        break;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _currentDragMode = _DragMode.none;
    _dragStartPosition = null;
    _initialStartTime = null;
    _initialEndTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Dalga formu
            AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width, widget.height),
              playerController: widget.playerController,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: _waveStyle,
              backgroundColor: widget.backgroundColor,
              enableSeekGesture: false,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),

            // Seçim göstergeleri
            IgnorePointer(
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width, widget.height),
                painter: RangeIndicatorPainter(
                  startPosition: widget.startTime / widget.duration,
                  endPosition: widget.endTime / widget.duration,
                  color: widget.selectedColor,
                ),
              ),
            ),

            // Thumb'lar
            Positioned(
              left: (widget.startTime / widget.duration) *
                      MediaQuery.of(context).size.width -
                  10,
              top: 0,
              bottom: 0,
              child: _buildThumb(),
            ),
            Positioned(
              left: (widget.endTime / widget.duration) *
                      MediaQuery.of(context).size.width -
                  10,
              top: 0,
              bottom: 0,
              child: _buildThumb(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    return Container(
      width: 20,
      decoration: BoxDecoration(
        color: widget.selectedColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class RangeIndicatorPainter extends CustomPainter {
  final double startPosition;
  final double endPosition;
  final Color color;

  const RangeIndicatorPainter({
    required this.startPosition,
    required this.endPosition,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final startX = size.width * startPosition;
    final endX = size.width * endPosition;

    // Start çizgisi
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      paint,
    );

    // End çizgisi
    canvas.drawLine(
      Offset(endX, 0),
      Offset(endX, size.height),
      paint,
    );

    // Seçili alan
    final selectedAreaPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(startX, 0, endX, size.height),
      selectedAreaPaint,
    );
  }

  @override
  bool shouldRepaint(RangeIndicatorPainter oldDelegate) {
    return startPosition != oldDelegate.startPosition ||
        endPosition != oldDelegate.endPosition ||
        color != oldDelegate.color;
  }
}
