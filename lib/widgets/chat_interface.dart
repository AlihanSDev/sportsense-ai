import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'uefa_search_indicator.dart';

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
}

class ChatInterface extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;
  final Future<void> Function()? onClear;
  final bool isLoading;
  final bool showSearch;
  final String? searchError;
  final double temperature;
  final ValueChanged<double>? onTemperatureChanged;

  const ChatInterface({
    super.key,
    required this.messages,
    required this.onSendMessage,
    this.onClear,
    this.isLoading = false,
    this.showSearch = false,
    this.searchError,
    this.temperature = 0.7,
    this.onTemperatureChanged,
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
  void initState() {
    super.initState();
    _displayedTexts = widget.messages.map((message) => message.text).toList();
    _fadedIn = List<bool>.filled(widget.messages.length, true);
  }

  @override
  void didUpdateWidget(covariant ChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages.length > oldWidget.messages.length) {
      final newMessage = widget.messages.last;
      _displayedTexts.add(newMessage.text);
      _fadedIn.add(false);
      _fadeIn(_fadedIn.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }

    _displayedTexts = widget.messages.map((message) => message.text).toList();
    _fadedIn = List<bool>.filled(widget.messages.length, true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fadeIn(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fadedIn[index] = true;
      });
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessageList()),
          if (widget.onTemperatureChanged != null) _buildTemperatureControl(),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.3),
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
                  color: Colors.white,
                ),
              ),
              Text(
                'Always here to help',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (widget.onClear != null)
            IconButton(
              tooltip: 'Очистить чат',
              onPressed: () async {
                await widget.onClear!.call();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildTemperatureControl() {
    final clampedTemperature = widget.temperature.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Температура',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: clampedTemperature,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: widget.temperature.toStringAsFixed(1),
              onChanged: (value) {
                widget.onTemperatureChanged?.call(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.temperature.toStringAsFixed(1),
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
        ],
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
        final messageCount = widget.messages.length;
        if (index < messageCount) {
          return _buildMessageBubble(widget.messages[index], index);
        }

        if (index == messageCount) {
          return _buildSearchIndicator(widget.showSearch);
        }

        var offset = 1;
        if (widget.searchError != null) {
          if (index == messageCount + offset) {
            return _buildSearchError(widget.searchError!);
          }
          offset++;
        }

        if (widget.isLoading && index == messageCount + offset) {
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
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: message.isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? const Color(0xFF7C4DFF).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: message.isUser
                        ? const Color(0xFF7C4DFF).withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
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
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: message.isUser
                            ? Colors.white
                            : (message.textColor ?? Colors.grey[200]),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
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
                    colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
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
                          colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
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
                    const Expanded(
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
                colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
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
    return TweenAnimationBuilder<double>(
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
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
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
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message AI Assistant...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey[500],
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
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
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
                colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
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
    if (text.isEmpty) return;

    widget.onSendMessage(text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
