import 'package:flutter/material.dart';
import 'widgets/interactive_scale.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import 'widgets/math_markdown.dart';
import 'widgets/chat_history_drawer.dart';

class ChatPage extends StatefulWidget {
  final String? fileId;
  final String? fileName;

  const ChatPage({Key? key, this.fileId, this.fileName}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();

  // ✅ جعلنا النوع مرن ليتوافق مع استقبال وإرسال الـ JSON بشكل آمن تماماً بدون كراش
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  bool _isLoading = false;
  bool _hasText = false;

  String? _currentConversationId;
  String? _currentFileId;

  late AnimationController _typingController;

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
  bool get isDocumentChat =>
      _currentFileId != null && _currentFileId!.isNotEmpty;

  // ✅ 1. جعل اللون الأساسي هادي ومتناسق مع الـ Dark والـ Light تلقائياً
  Color get accentColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDocumentChat) {
      // وضع المستند: أزرق هادي في الدارك، وأزرق ملكي في اللايت
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    } else {
      // الشات العام: بنفسجي فاتح في الدارك، وبنفسجي عميق في اللايت
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    }
  }

  // ✅ 2. تدرج ذكي لفقاعة رسالة المستخدم (User Bubble) وزرار الإرسال
  LinearGradient get userBubbleGradient {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDocumentChat) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF1E40AF),
                const Color(0xFF1D4ED8),
              ] // دارك: أزرق داكن مريح
            : [
                const Color(0xFF3B82F6),
                const Color(0xFF2563EB),
              ], // لايت: أزرق حيوي
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF5B21B6),
                const Color(0xFF6D28D9),
              ] // دارك: بنفسجي داكن
            : [
                const Color(0xFF6366F1),
                const Color(0xFF7C3AED),
              ], // لايت: بنفسجي حيوي
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _currentFileId = widget.fileId;

    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _startNewChat() {
    setState(() {
      _currentConversationId = null;
      _currentFileId = widget.fileId;
      _messages.clear();
    });
  }

  Future<void> _loadExistingConversation(
    Map<String, dynamic> conversation,
  ) async {
    setState(() {
      _currentConversationId = conversation['id'].toString();
      _currentFileId = conversation['file_id']?.toString();
      _messages.clear();
      _isLoading = true;
    });
    _typingController.repeat();

    try {
      final response = await _apiService.dio.get(
        '/conversations/$_currentConversationId',
      );
      if (response.data['success'] == true) {
        final chatData = response.data['data'];
        final fetchedMessages = chatData['messages'] as List<dynamic>;

        setState(() {
          // ✅ التعديل الجوهري: أجبرنا الـ map ترجع لستة من نوع <Map<String, dynamic>> صريحة
          // ده بيمنع الـ Compiler إنه يحولها خفية لـ Map<String, String> وبالتالي يمنع الكراش عند الـ _sendMessage
          _messages = fetchedMessages
              .map<Map<String, dynamic>>(
                (m) => <String, dynamic>{
                  'role': m['role'].toString(),
                  'content': m['content'].toString(),
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading conversation messages: $e');
    } finally {
      setState(() => _isLoading = false);
      _typingController.stop();
      _scrollToBottom();
    }
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
    _typingController.repeat();

    try {
      if (_currentConversationId == null) {
        final convResponse = await _apiService.dio.post(
          '/conversations',
          data: {
            'title': text.length > 30 ? '${text.substring(0, 30)}...' : text,
            'type': isDocumentChat ? 'document' : 'general',
            'file_id': _currentFileId,
          },
        );

        if (convResponse.data['success'] == true) {
          _currentConversationId = convResponse.data['data']['id'].toString();
        } else {
          throw Exception('Failed to initialize conversation');
        }
      }

      final response = await _apiService.dio.post(
        '/conversations/$_currentConversationId/chat',
        data: {'message': text},
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
              ? 'حصل خطأ، حاول ثاني'
              : 'An error occurred, please try again.',
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _typingController.stop();
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic ? 'تم نسخ النص إلى الحافظة' : 'Copied to clipboard',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: accentColor,
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
      h1:
          theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentColor,
            letterSpacing: -0.5,
            height: 1.4,
          ) ??
          const TextStyle(),
      h2:
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentColor.withOpacity(0.85),
            letterSpacing: -0.3,
            height: 1.4,
          ) ??
          const TextStyle(),
      h3:
          theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: accentColor.withOpacity(0.75),
            height: 1.4,
          ) ??
          const TextStyle(),
      p:
          theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            letterSpacing: 0.1,
          ) ??
          const TextStyle(),
      listBullet:
          theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            color: accentColor,
          ) ??
          const TextStyle(),
      strong:
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ) ??
          const TextStyle(),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: accentColor.withOpacity(0.08),
        color: accentColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote:
          theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ) ??
          const TextStyle(),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accentColor.withOpacity(0.5), width: 4),
        ),
        color: accentColor.withOpacity(0.04),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      tableBorder: TableBorder.all(
        color: accentColor.withOpacity(0.2),
        width: 1,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      tableHead:
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ) ??
          const TextStyle(),
      tableBody:
          theme.textTheme.bodySmall?.copyWith(height: 1.5) ?? const TextStyle(),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      pPadding: const EdgeInsets.symmetric(vertical: 2),
      listIndent: 16,
    );
  }

  @override
  // ── تعديل تابع الـ build الرئيسي ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          drawer: ChatHistoryDrawer(
            currentConversationId: _currentConversationId,
            onConversationSelected: _loadExistingConversation,
            onNewChatPressed: _startNewChat,
          ),
          appBar: _buildAppBar(theme, isDark),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.maxWidth(context),
              ),
              child: Column(
                children: [
                  // ❌ قم بحذف أو مسح هذا السطر تماماً لتختفي الـ Bar:
                  // if (isDocumentChat && widget.fileName != null) _buildFileBar(theme, isDark),
                  Expanded(
                    child: _messages.isEmpty
                        ? _buildEmptyState(theme, isDark)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return _buildTypingIndicator(theme, isDark);
                              }
                              return _buildMessage(
                                theme,
                                isDark,
                                _messages[index],
                                index,
                              );
                            },
                          ),
                  ),
                  _buildInput(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ── App Bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDark) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.cardColor,
      leadingWidth: 100,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 6),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 2),
          Builder(
            builder: (context) => IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: Icon(
                Icons.menu_rounded,
                size: 24,
                color: theme.textTheme.bodyLarge?.color,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isDocumentChat
                  ? const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDocumentChat
                  ? Icons.description_rounded
                  : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // أضفنا Expanded لحماية النصوص من التداخل
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isDocumentChat
                      ? (isArabic ? 'شات المستند' : 'Document Chat')
                      : (isArabic ? 'الشات الذكي' : 'Smart Chat'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14, // صغرنا الحجم درجة واحدة لتوفير مساحة للملف
                  ),
                ),
                const SizedBox(height: 2),
                // هنا السحر: إذا كان هناك ملف، يظهر كـ Tag أنيق جداً وبحجم صغير
                if (isDocumentChat && widget.fileName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF3B82F6,
                      ).withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFF3B82F6),
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.fileName!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    isArabic ? 'مدعوم بالذكاء الاصطناعي' : 'AI Powered',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
    );
  }
  // ── شريط الملف ───────────────────────────────────────────────────────────

  Widget _buildFileBar(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.08),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF3B82F6),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.fileName ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isArabic ? 'وضع المستند' : 'Doc Mode',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    final suggestions = isDocumentChat
        ? (isArabic
              ? ['لخّص لي المستند', 'إيه أهم نقطة؟', 'اشرح لي الفكرة الرئيسية']
              : [
                  'Summarize this document',
                  'What\'s the main idea?',
                  'Key points?',
                ])
        : (isArabic
              ? ['اشرح لي الـ Flutter', 'إيه هو الـ AI؟', 'ساعدني في الكود']
              : ['Explain Flutter to me', 'What is AI?', 'Help me with code']);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: isDocumentChat
                    ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isDocumentChat
                    ? Icons.chat_bubble_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'مرحباً! كيف أقدر أساعدك؟' : 'Hi! How can I help?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isDocumentChat
                  ? (isArabic
                        ? 'اسألني أي سؤال عن المستند'
                        : 'Ask me anything about the document')
                  : (isArabic
                        ? 'اسألني عن أي موضوع يخطر على بالك'
                        : 'Ask me about anything on your mind'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map((s) => _buildSuggestionChip(s, theme, isDark))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        setState(() => _hasText = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── رسالة ─────────────────────────────────────────────────────────────────

  Widget _buildMessage(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> msg,
    int index,
  ) {
    final isUser = msg['role'] == 'user';
    final content = msg['content'] ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  gradient: isDocumentChat
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? (isDocumentChat
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF2563EB),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF7C3AED),
                                    ],
                                  ))
                          : null,
                      color: isUser ? null : theme.cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? accentColor.withOpacity(0.25)
                              : Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: isUser
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.05),
                            ),
                    ),
                    child: isUser
                        ? Text(
                            content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          )
                        : MathMarkdown(
                            data: content,
                            styleSheet: _buildMarkdownStyle(theme),
                          ),
                  ),
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: InkWell(
                        onTap: () => _copyToClipboard(content),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'نسخ' : 'Copy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              gradient: isDocumentChat
                  ? const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _typingController,
                  builder: (context, _) {
                    final delay = i * 0.2;
                    final raw = (_typingController.value - delay) % 1.0;
                    final t = raw < 0 ? raw + 1.0 : raw;
                    final scale =
                        0.6 + 0.4 * (1 - (2 * t - 1).abs().clamp(0.0, 1.0));
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.6 + 0.4 * scale),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInput(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.07),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasText
                      ? accentColor.withOpacity(0.4)
                      : isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                  width: _hasText ? 1.5 : 1,
                ),
              ),
              // 🛠️ الحل: تغليف الـ TextField بـ KeyboardListener للتحكم الكامل في الأزرار
              child: KeyboardListener(
                focusNode: FocusNode(), // نود مؤقتة للقراءة
                onKeyEvent: (KeyEvent event) {
                  // نتحقق إن الزرار المضغوط هو Enter وإنه في وضعية الضغط (KeyDown) وليس الرفع
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    // إذا كان المستخدم ضاغط Shift مع Enter -> خليه ينزل سطر عادي ومتعملش إرسال
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      return;
                    }

                    // إذا كان Enter لوحده -> ابعت الرسالة فوراً ومنع الزرار إنه ينزل سطر جديد
                    if (_hasText && !_isLoading) {
                      _sendMessage();
                    }
                  }
                },
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  // تحويل زرار الكيبورد في الموبايل لـ "إرسال" بدلاً من سطر جديد
                  textInputAction: TextInputAction.send,
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  // عند الضغط على زر الإرسال من كيبورد الموبايل (التاتش)
                  onSubmitted: (_) {
                    if (_hasText && !_isLoading) {
                      _sendMessage();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: isDocumentChat
                        ? (isArabic
                              ? 'اسأل عن المستند...'
                              : 'Ask about the document...')
                        : (isArabic ? 'اكتب رسالتك...' : 'Type a message...'),
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _isLoading || !_hasText
                  ? LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.4),
                        Colors.grey.withOpacity(0.3),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDocumentChat
                          ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                          : [const Color(0xFF6366F1), const Color(0xFF7C3AED)],
                    ),
              shape: BoxShape.circle,
              boxShadow: _hasText && !_isLoading
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_hasText && !_isLoading) ? _sendMessage : null,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
