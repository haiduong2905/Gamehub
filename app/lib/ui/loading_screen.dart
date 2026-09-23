import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'home_screen.dart';

const _cyan = Color(0xFF46D7FF);

/// Màn hình mở app: logo khối lập phương trong vòng chấm đang chạy.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.duration = const Duration(seconds: 2)});

  final Duration duration;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _timer = Timer(widget.duration, _showHome);
  }

  void _showHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, animation, secondaryAnimation) => const HomeScreen(),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 450),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF06091F),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.25, -.15),
              radius: 1.05,
              colors: [
                Color(0xFF123B5C),
                Color(0xFF0B1231),
                Color(0xFF090720),
              ],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _SplashBackdrop()),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Game Hub',
                      style: TextStyle(
                        color: const Color(0xFFAEB6CC),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: _cyan.withValues(alpha: .35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) => CustomPaint(
                          painter: _ProgressRing(_controller.value),
                          child: Center(child: child),
                        ),
                        // Quầng sáng tản dần, không phải khung bo góc: ở đây
                        // logo nổi thẳng trên nền tối chứ không phải là icon
                        // nằm trong ô như trên màn hình điện thoại.
                        //
                        // Dùng RadialGradient chứ không dùng BoxShadow: bóng
                        // đổ của một hình tròn vẫn là một đĩa đặc có mép, nhìn
                        // ra ngay là một vòng tròn xanh chứ không phải ánh
                        // sáng.
                        child: Container(
                          width: 196,
                          height: 196,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0x3346D7FF), Color(0x0046D7FF)],
                              stops: [.28, 1],
                            ),
                          ),
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child:
                                SvgPicture.asset('assets/images/app_mark.svg'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Đang tải...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Vòng 24 chấm chạy quanh logo.
class _ProgressRing extends CustomPainter {
  const _ProgressRing(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final faded = Paint()..color = const Color(0xFF20375B);
    final bright = Paint()..color = const Color(0xFF66DFFF);

    for (var i = 0; i < 24; i++) {
      final angle = (i / 24) * math.pi * 2 - math.pi / 2;
      final lit = i / 24 <= progress;
      canvas.drawCircle(
        center + Offset.fromDirection(angle, radius),
        lit ? 3.5 : 2.6,
        lit ? bright : faded,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRing oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Lưới đường mảnh ở góc trên và khối lập phương khung dây mờ ở góc dưới.
///
/// Chỉ là trang trí nền, vẽ rất nhạt để không tranh chấp với logo ở giữa.
class _SplashBackdrop extends CustomPainter {
  const _SplashBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final web = Paint()
      ..color = _cyan.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(
      Path()
        ..moveTo(size.width * .52, 0)
        ..lineTo(size.width, size.height * .17)
        ..lineTo(size.width * .70, size.height * .27)
        ..lineTo(size.width, size.height * .38)
        ..moveTo(size.width * .70, size.height * .27)
        ..lineTo(size.width * .62, size.height * .05),
      web,
    );

    _wireCube(
      canvas,
      Offset(size.width * .80, size.height * .86),
      size.shortestSide * .15,
      web,
    );
  }

  void _wireCube(Canvas canvas, Offset center, double radius, Paint paint) {
    // Lập phương chiếu đẳng cự: nửa rộng 0.86r, nửa cao 0.5r ở mặt trên.
    final w = radius * .86;
    final h = radius * .5;

    final top = center + Offset(0, -radius);
    final right = center + Offset(w, -h);
    final left = center + Offset(-w, -h);
    final bottom = center + Offset(0, radius);
    final rightLow = center + Offset(w, h);
    final leftLow = center + Offset(-w, h);

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(rightLow.dx, rightLow.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(leftLow.dx, leftLow.dy)
        ..lineTo(left.dx, left.dy)
        ..close()
        ..moveTo(top.dx, top.dy)
        ..lineTo(center.dx, center.dy)
        ..moveTo(left.dx, left.dy)
        ..lineTo(center.dx, center.dy)
        ..moveTo(right.dx, right.dy)
        ..lineTo(center.dx, center.dy)
        ..moveTo(center.dx, center.dy)
        ..lineTo(bottom.dx, bottom.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SplashBackdrop oldDelegate) => false;
}
