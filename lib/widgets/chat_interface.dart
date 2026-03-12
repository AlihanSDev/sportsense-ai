import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'uefa_search_indicator.dart';

/// Анимированный сгусток с эффектом лавовой лампы
class AnimatedLavaLamp extends StatefulWidget {
  final bool isTyping;
  final double size;

  const AnimatedLavaLamp({
    super.key,
    required this.isTyping,
    this.size = 40.0,
  });

  @override
  State<AnimatedLavaLamp> createState() => _AnimatedLavaLampState();
}

class _AnimatedLavaLampState extends State<AnimatedLavaLamp> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _morphController;
  late AnimationController _lightningController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _morphController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _lightningController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _morphAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedLavaLamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если состояние печати изменилось, перезапускаем анимацию молнии
    if (widget.isTyping != oldWidget.isTyping) {
      if (widget.isTyping) {
        // Запускаем анимацию молнии
        _lightningController.forward(from: 0.0);
      } else {
        // Останавливаем анимацию молнии
        _lightningController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _morphController.dispose();
    _lightningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _morphController, _lightningController]),
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: LavaLampPainter(
            pulseValue: _pulseAnimation.value,
            morphValue: _morphAnimation.value,
            isTyping: widget.isTyping,
            lightningValue: _lightningController.value,
          ),
        );
      },
    );
  }
}

class LavaLampPainter extends CustomPainter {
  final double pulseValue;
  final double morphValue;
  final bool isTyping;
  final double lightningValue;

  LavaLampPainter({
    required this.pulseValue,
    required this.morphValue,
    required this.isTyping,
    required this.lightningValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Основной градиент сгустка
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        const Color(0xFF7C4DFF).withOpacity(0.8), // Фиолетовый
        const Color(0xFF00D4FF).withOpacity(0.6), // Голубой
        const Color(0xFF4A90E2).withOpacity(0.4), // Синий
        Colors.white.withOpacity(0.2),            // Белый
      ],
    );

    // Эффект пульсации
    final pulseRadius = radius * pulseValue;

    // Эффект морфинга (лавовой лампы)
    final path = Path();
    final points = 8;
    final baseRadius = pulseRadius;
    
    for (int i = 0; i < points; i++) {
      final angle = (i / points) * 2 * math.pi;
      // Случайные волны для эффекта лавовой лампы
      final wave = math.sin(morphValue * 4 + angle * 3) * 10;
      final noise = math.sin(morphValue * 6 + angle * 5) * 5;
      final r = baseRadius + wave + noise;
      
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Рисуем основной сгусток
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: pulseRadius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Добавляем внутреннее свечение
    final innerPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, pulseRadius * 0.6, innerPaint);

    // Анимация молнии при печати
    if (isTyping && lightningValue > 0) {
      final lightningPath = Path();
      final lightningStart = Offset(center.dx - 10, center.dy - 15);
      final lightningEnd = Offset(center.dx + 10, center.dy + 15);
      
      // Основная линия молнии
      lightningPath.moveTo(lightningStart.dx, lightningStart.dy);
      lightningPath.lineTo(center.dx, center.dy - 5);
      lightningPath.lineTo(center.dx + 5, center.dy + 5);
      lightningPath.lineTo(lightningEnd.dx, lightningEnd.dy);
      
      // Ветвь молнии
      lightningPath.moveTo(center.dx, center.dy - 5);
      lightningPath.lineTo(center.dx - 8, center.dy + 2);

      final lightningPaint = Paint()
        ..color = Colors.white.withOpacity(lightningValue)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(lightningPath, lightningPaint);

      // Эффект вспышки
      final flashPaint = Paint()
        ..color = Colors.white.withOpacity(lightningValue * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(center, pulseRadius * 0.8, flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LavaLampPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
           oldDelegate.morphValue != morphValue ||
           oldDelegate.isTyping != isTyping ||
           oldDelegate.lightningValue != lightningValue;
  }
}

/// Сообщение чата
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Color? textColor; // Цвет текста для бота (зелёный/оранжевый для rankings)

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.textColor, // По умолчанию null (используется стандартный цвет)
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Виджет чата в стиле ChatGPT/Qwen/DeepSeek
class ChatInterface extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;
  final bool isLoading;
  final bool showSearch;
  final String? searchError;

  const ChatInterface({
    super.key,
    required this.messages,
    required this.onSendMessage,
    this.isLoading = false,
    this.showSearch = false,
    this.searchError,
  });

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// содержимое, отображаемое в пузырьках; для бот-сообщений может
  /// заполняться постепенно, создавая эффект «набирается текст»
  late List<String> _displayedTexts;

  /// флаги для постепенного появления сообщения (для анимации opacity)
  late List<bool> _fadedIn;

  /// флаги для анимации молнии при печати
  late List<bool> _isTyping;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// запускает анимацию печати для нового сообщения бота
  Future<void> _startTyping(String fullText) async {
    // Включаем анимацию молнии для последнего сообщения
    if (_isTyping.isNotEmpty) {
      _isTyping[_isTyping.length - 1] = true;
    }
    
    // Запускаем анимацию молнии
    _triggerLightningAnimation();
    
    for (int i = 1; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() {
        _displayedTexts[_displayedTexts.length - 1] = fullText.substring(0, i);
      });
      _scrollToBottom();
    }
    
    // Выключаем анимацию молнии после завершения печати
    if (_isTyping.isNotEmpty) {
      _isTyping[_isTyping.length - 1] = false;
    }
  }

  /// запускает анимацию молнии
  void _triggerLightningAnimation() {
    if (_isTyping.isNotEmpty) {
      // Запускаем анимацию молнии для всех сгустков
      for (int i = 0; i < _isTyping.length; i++) {
        if (_isTyping[i]) {
          // Перезапускаем анимацию молнии
          // Это будет вызвано автоматически при изменении isTyping
        }
      }
    }
  }

  /// плавное появление пузырька после добавления в список
  void _fadeIn(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _fadedIn[index] = true;
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // при старте все сообщения уже должны показываться полностью
    _displayedTexts = widget.messages.map((m) => m.isUser ? m.text : m.text).toList();
    _fadedIn = List<bool>.filled(widget.messages.length, true);
    _isTyping = List<bool>.filled(widget.messages.length, false);
  }

  @override
  void didUpdateWidget(covariant ChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages.length > oldWidget.messages.length) {
      // добавлено новое сообщение (скорее всего от ИИ)
      final newMsg = widget.messages.last;
      _displayedTexts.add(newMsg.text);
      _fadedIn.add(false);
      _isTyping.add(false);
      _fadeIn(_fadedIn.length - 1);
      
      // Если это сообщение бота, запускаем анимацию печати
      if (!newMsg.isUser) {
        _startTyping(newMsg.text);
      }
    } else if (widget.messages.length < oldWidget.messages.length) {
      // сообщения удалены? просто синхронизируем списки
      _displayedTexts = widget.messages.map((m) => m.text).toList();
      _fadedIn = List<bool>.filled(widget.messages.length, true);
      _isTyping = List<bool>.filled(widget.messages.length, false);
    } else {
      // изменение без изменения длины, синхронизируем всё
      _displayedTexts = widget.messages.map((m) => m.text).toList();
      _fadedIn = List<bool>.filled(widget.messages.length, true);
      _isTyping = List<bool>.filled(widget.messages.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Заголовок
          _buildHeader(),

          // Список сообщений
          Expanded(
            child: _buildMessageList(),
          ),

          // Поле ввода
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE8F0FF),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedLavaLamp(
            isTyping: false,
            size: 48.0,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Assistant',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              Text(
                'Always here to help',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      // always reserve a slot for the search indicator to avoid list reflows
      itemCount: widget.messages.length
          + 1
          + (widget.searchError != null ? 1 : 0)
          + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        final base = widget.messages.length;
        if (index < base) {
          return _buildMessageBubble(widget.messages[index], index);
        }
        if (index == base) {
          // indicator slot
          return _buildSearchIndicator(widget.showSearch);
        }
        int offset = 1;
        if (widget.searchError != null) {
          if (index == base + offset) {
            return _buildSearchError(widget.searchError!);
          }
          offset++;
        }
        if (widget.isLoading && index == base + offset) {
          return _buildLoadingIndicator();
        }
        // should not reach here normally
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    return AnimatedOpacity(
      opacity: _fadedIn[index] ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            AnimatedLavaLamp(
              isTyping: index < _isTyping.length ? _isTyping[index] : false,
              size: 40.0,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF4A90E2).withOpacity(0.2)
                    : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: message.isUser
                      ? const Color(0xFF4A90E2).withOpacity(0.3)
                      : const Color(0xFFE8F0FF),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // отображаем часть текста, если идет печать
                    _displayedTexts.length > index ? _displayedTexts[index] : message.text,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: message.isUser
                          ? const Color(0xFF333333)
                          : (message.textColor ?? const Color(0xFF333333)),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE040FB),
                    Color(0xFF7C4DFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildSearchIndicator(bool visible) {
    // keep the slot always there; animate size & opacity when shown/hidden
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: visible
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AnimatedLavaLamp(
                      isTyping: false,
                      size: 40.0,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: UefaSearchIndicator(
                        message: 'Поиск информации...',
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSearchError(String message) {
    // error shown inline after the search indicator
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: UefaErrorIndicator(message: message),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AnimatedLavaLamp(
            isTyping: false,
            size: 40.0,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + index * 200),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withOpacity(0.5 + value * 0.5),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        // Restart animation handled by parent rebuild
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.1),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE8F0FF),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF333333),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message AI Assistant...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF999999),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Add attachment functionality
                    },
                    icon: const Icon(
                      Icons.attach_file,
                      color: Color(0xFF666666),
                    ),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4A90E2),
                  Color(0xFFA7C7FF),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
              iconSize: 24,
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
