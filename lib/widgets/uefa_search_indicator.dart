import 'package:flutter/material.dart';

/// Виджет отображения состояния "Поиск информации..."
/// с мягкой анимацией загрузки.
class UefaSearchIndicator extends StatefulWidget {
  final String message;

  const UefaSearchIndicator({super.key, this.message = 'Поиск информации...'});

  @override
  State<UefaSearchIndicator> createState() => _UefaSearchIndicatorState();
}

class _UefaSearchIndicatorState extends State<UefaSearchIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Иконка поиска с анимацией
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2 * _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.search,
                  color: const Color(0xFF374151).withOpacity(0.8),
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Индикатор загрузки (три мягкие точки)
          SizedBox(
            width: 40,
            height: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildDot(0), _buildDot(1), _buildDot(2)],
            ),
          ),

          const SizedBox(width: 12),

          // Текст с плавной пульсацией
          Expanded(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF374151).withOpacity(_pulseAnimation.value),
                    letterSpacing: 0.2,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + index * 200),
      tween: Tween<double>(begin: 0.4, end: 1.0),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withOpacity(value * 0.4),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {},
    );
  }
}

/// Виджет ошибки при отсутствии доступа
class UefaErrorIndicator extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const UefaErrorIndicator({
    super.key,
    this.message = 'Не удалось загрузить данные',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD1D5DB).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFF6B7280),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: const Color(0xFF374151).withOpacity(0.7),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Повторить',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF374151).withOpacity(0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
