import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'uefa_search_indicator.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// запускает анимацию печати для нового сообщения бота
  Future<void> _startTyping(String fullText) async {
    for (int i = 1; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() {
        _displayedTexts[_displayedTexts.length - 1] = fullText.substring(0, i);
      });
      _scrollToBottom();
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
  }

  @override
  void didUpdateWidget(covariant ChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages.length > oldWidget.messages.length) {
      // добавлено новое сообщение (скорее всего от ИИ)
      final newMsg = widget.messages.last;
      _displayedTexts.add(newMsg.text);
      _fadedIn.add(false);
      _fadeIn(_fadedIn.length - 1);
    } else if (widget.messages.length < oldWidget.messages.length) {
      // сообщения удалены? просто синхронизируем списки
      _displayedTexts = widget.messages.map((m) => m.text).toList();
      _fadedIn = List<bool>.filled(widget.messages.length, true);
    } else {
      // изменение без изменения длины, синхронизируем всё
      _displayedTexts = widget.messages.map((m) => m.text).toList();
      _fadedIn = List<bool>.filled(widget.messages.length, true);
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4A90E2),
                  Color(0xFFA7C7FF),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 24,
            ),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00D4FF),
                    Color(0xFF7C4DFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00D4FF),
                            Color(0xFF7C4DFF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00D4FF),
                  Color(0xFF7C4DFF),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 20,
            ),
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
