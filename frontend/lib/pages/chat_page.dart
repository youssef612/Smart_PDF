import 'package:flutter/material.dart';
import 'widgets/interactive_scale.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import 'widgets/math_markdown.dart';

class ChatPage extends StatefulWidget {
  final String? fileId;
  final String? fileName;

  const ChatPage({
    Key? key,
    this.fileId,
    this.fileName,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // ✅ لو fileId فارغ → شات عام، غير كده → شات خاص بالملف
      final String endpoint = (widget.fileId == null || widget.fileId!.isEmpty)
          ? '/chat'
          : '/files/${widget.fileId}/chat';

      final response = await _apiService.dio.post(
        endpoint,
        data: {
          'message': text,
          'history': _messages
              .where((m) => m['role'] != 'user' || m != _messages.last)
              .toList(),
        },
      );

      if (response.data['success'] == true) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response.data['data']['reply'] ?? '',
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': isArabic
              ? 'حصل خطأ، حاول تاني'
              : 'An error occurred, please try again.',
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    const baseColor = Color(0xFF6366F1);
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor,
            letterSpacing: -0.5,
            height: 1.4,
          ) ??
          const TextStyle(),
      h2: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor.withOpacity(0.85),
            letterSpacing: -0.3,
            height: 1.4,
          ) ??
          const TextStyle(),
      h3: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: baseColor.withOpacity(0.75),
            height: 1.4,
          ) ??
          const TextStyle(),
      p: theme.textTheme.bodyMedium
              ?.copyWith(height: 1.7, letterSpacing: 0.1) ??
          const TextStyle(),
      listBullet: theme.textTheme.bodyMedium
              ?.copyWith(height: 1.7, color: baseColor) ??
          const TextStyle(),
      strong: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold, color: baseColor) ??
          const TextStyle(),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: baseColor.withOpacity(0.08),
        color: baseColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: baseColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.15)),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic, color: Colors.grey[600]) ??
          const TextStyle(),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: baseColor.withOpacity(0.5), width: 4)),
        color: baseColor.withOpacity(0.04),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tableBorder: TableBorder.all(
        color: const Color(0x336366F1),
        width: 1,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableHead: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold, color: baseColor) ??
          const TextStyle(),
      tableBody: theme.textTheme.bodySmall?.copyWith(height: 1.5) ??
          const TextStyle(),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      pPadding: const EdgeInsets.symmetric(vertical: 2),
      listIndent: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.fileId != null && widget.fileId!.isNotEmpty
              ? (isArabic ? 'شات المستند' : 'Document Chat')
              : (isArabic ? 'الشات الذكي' : 'Smart Chat'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: theme.cardColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildTypingIndicator(theme);
                          }
                          final msg = _messages[index];
                          return _buildMessage(theme, msg);
                        },
                      ),
              ),
              _buildInput(theme),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_rounded,
              size: 48,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'اسألني عن أي حاجة' : 'Ask me anything',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'يمكنك سؤالي عن أي موضوع'
                : 'You can ask me about any topic',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ThemeData theme, Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final content = msg['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF6366F1) : theme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : MathMarkdown(
                      data: content,
                      styleSheet: _buildMarkdownStyle(theme),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const SizedBox(
              width: 40,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText:
                    isArabic ? 'اكتب سؤالك...' : 'Type your question...',
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          InteractiveScale(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? LinearGradient(colors: [
                        Colors.grey.shade400,
                        Colors.grey.shade500
                      ])
                    : const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
