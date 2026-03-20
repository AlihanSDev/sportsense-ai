import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'uefa_search_indicator.dart';

/// Сообщение чата
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Color? textColor;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.textColor,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      textColor: json['textColor'] != null
          ? Color(int.parse(json['textColor'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'textColor': textColor?.value,
    };
  }
}

/// Чистый, минималистичный чат-интерфейс
class ChatInterface extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;
  final VoidCallback? onClear;
  final bool isLoading;
  final bool showSearch;
  final String? searchError;

  const ChatInterface({
    super.key,
    required this.messages,
    required this.onSendMessage,
    this.onClear,
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
  late List<String> _displayedTexts;
  late List<bool> _fadedIn;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
    _displayedTexts = widget.messages
        .map((m) => m.isUser ? m.text : m.text)
        .toList();
    _fadedIn = List<bool>.filled(widget.messages.length, true);
  }

  @override
  void didUpdateWidget(covariant ChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages.length > oldWidget.messages.length) {
      final newMsg = widget.messages.last;
      _displayedTexts.add(newMsg.text);
      _fadedIn.add(false);
      _fadeIn(_fadedIn.length - 1);
    } else if (widget.messages.length < oldWidget.messages.length) {
      _displayedTexts = widget.messages.map((m) => m.text).toList();
      _fadedIn = List<bool>.filled(widget.messages.length, true);
    } else {
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
          _buildHeader(),
          Expanded(child: _buildMessageList()),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI ASSISTANT',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                'Всегда готов помочь',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (widget.onClear != null) ...[
            _buildHeaderAction(
              icon: Icons.delete_outline,
              tooltip: 'Очистить чат',
              onPressed: widget.onClear!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount:
          widget.messages.length +
          1 +
          (widget.searchError != null ? 1 : 0) +
          (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        final base = widget.messages.length;
        if (index < base) {
          return _buildMessageBubble(widget.messages[index], index);
        }
        if (index == base) {
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
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    return AnimatedOpacity(
      opacity: _fadedIn[index] ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: message.isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.support_agent_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? const Color(0xFF2B2B2B)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: message.isUser
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayedTexts.length > index
                          ? _displayedTexts[index]
                          : message.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: message.isUser
                            ? Colors.white
                            : (message.textColor ??
                                  Colors.white.withOpacity(0.9)),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (message.isUser) ...[
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchIndicator(bool visible) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: visible
            ? Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.support_agent_outlined,
                        color: Colors.white70,
                        size: 18,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 6),
                _buildDot(1),
                const SizedBox(width: 6),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + index * 200),
      tween: Tween<double>(begin: 0.3, end: 1.0),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value * 0.5),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Написать сообщение...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white38,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 16,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.attach_file_outlined,
                      color: Colors.white38,
                    ),
                    iconSize: 20,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_outlined, color: Colors.white70),
              iconSize: 22,
              padding: const EdgeInsets.all(14),
              splashRadius: 24,
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
