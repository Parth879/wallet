import 'package:flutter/material.dart';

class ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const ToastWidget({
    super.key,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slide = Tween<Offset>(
        begin: const Offset(0.2, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              left: BorderSide(
                color: widget.isError
                    ? Colors.redAccent
                    : const Color(0xFF009688),
                width: 4,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: widget.isError
                    ? Colors.redAccent
                    : const Color(0xFF009688),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}