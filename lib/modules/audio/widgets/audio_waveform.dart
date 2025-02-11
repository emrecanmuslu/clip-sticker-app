import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class CustomWaveform extends StatefulWidget {
  final String audioPath;
  final double startTime;
  final double endTime;
  final double duration;
  final Color waveColor;
  final Color backgroundColor;
  final Color selectedColor;
  final double height;
  final PlayerController playerController;
  final Function(double, double) onSeek;
  final double maxDuration;

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
    this.backgroundColor = Colors.transparent,
    this.selectedColor = Colors.blue,
    this.height = 100,
  });

  @override
  State<CustomWaveform> createState() => _CustomWaveformState();
}

class _CustomWaveformState extends State<CustomWaveform> {
  late PlayerWaveStyle _waveStyle;

  @override
  void initState() {
    super.initState();
    _initializeWaveStyle();
  }

  void _initializeWaveStyle() {
    _waveStyle = PlayerWaveStyle(
      fixedWaveColor: widget.waveColor,
      liveWaveColor: widget.selectedColor,
      spacing: 4,
      waveThickness: 2,
      scaleFactor: 80,
      waveCap: StrokeCap.round,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Waveform
          AudioFileWaveforms(
            size: Size(MediaQuery.of(context).size.width, widget.height),
            playerController: widget.playerController,
            waveformType: WaveformType.fitWidth,
            playerWaveStyle: _waveStyle,
            backgroundColor: widget.backgroundColor,
            enableSeekGesture: false, // Range Slider kullanacağımız için false
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // Range Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: widget.selectedColor,
              overlayColor: widget.selectedColor.withOpacity(0.3),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: RangeSlider(
              values: RangeValues(widget.startTime, widget.endTime),
              min: 0,
              max: widget.duration > widget.maxDuration 
                  ? widget.maxDuration 
                  : widget.duration,
              onChanged: (values) {
                widget.onSeek(values.start, values.end);
              },
            ),
          ),
          // Başlangıç ve bitiş çizgileri
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
        ],
      ),
    );
  }
}

// Başlangıç ve bitiş çizgilerini çizmek için CustomPainter
class RangeIndicatorPainter extends CustomPainter {
  final double startPosition;
  final double endPosition;
  final Color color;

  RangeIndicatorPainter({
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

    // Başlangıç çizgisi
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      paint,
    );

    // Bitiş çizgisi
    canvas.drawLine(
      Offset(endX, 0),
      Offset(endX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(RangeIndicatorPainter oldDelegate) {
    return startPosition != oldDelegate.startPosition ||
        endPosition != oldDelegate.endPosition ||
        color != oldDelegate.color;
  }
}