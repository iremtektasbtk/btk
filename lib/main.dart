import 'package:flutter/material.dart';

import 'chat_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF202923);
    const accent = Color(0xFF4C8065);
    return MaterialApp(
      title: 'Mola',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          surface: const Color(0xFFF5F5EF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5EF),
          foregroundColor: ink,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.isUser, this.content = ''});

  final bool isUser;
  String content;
  String thinking = '';
  String? error;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = OllamaChatService();
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String _model = 'llama3.2';
  bool _isGenerating = false;

  @override
  void dispose() {
    _service.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? suggestedPrompt]) async {
    final text = (suggestedPrompt ?? _inputController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    _inputController.clear();
    final userMessage = _ChatMessage(isUser: true, content: text);
    final answer = _ChatMessage(isUser: false);
    setState(() {
      _messages
        ..add(userMessage)
        ..add(answer);
      _isGenerating = true;
    });
    _scrollToBottom();

    final history = _messages
        .where((message) => message.content.isNotEmpty)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          },
        )
        .toList();
    try {
      await for (final delta in _service.chat(
        model: _model,
        messages: history,
      )) {
        if (!mounted) return;
        setState(() {
          answer
            ..thinking += delta.thinking
            ..content += delta.content;
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        answer.error =
            'Ollama bağlantısı kurulamadı. Sunucuyu ve modeli kontrol edin.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yanıt alınamadı: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _editModel() async {
    final controller = TextEditingController(text: _model);
    final model = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model seç'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Ollama model adı',
            hintText: 'ör. llama3.2',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (model != null && model.isNotEmpty && mounted) {
      setState(() => _model = model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE9DE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.forum_rounded, color: Color(0xFF426B52)),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mola',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Yerel asistan',
                  style: TextStyle(fontSize: 12, color: Color(0xFF747B74)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _editModel,
              icon: const Icon(Icons.memory_rounded, size: 17),
              label: Text(_model),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF426B52),
                backgroundColor: const Color(0xFFE6EDE5),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildConversation(),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    const prompts = [
      'Bana kısa bir hikaye yaz',
      'Bir konuyu sade anlat',
      'Bugün ne öğrenebilirim?',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 28),
      children: [
        const Icon(
          Icons.wb_twilight_rounded,
          size: 34,
          color: Color(0xFF739078),
        ),
        const SizedBox(height: 18),
        const Text(
          'Merhaba.\nAklında ne var?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF26352B),
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sohbetin yerel modelinde kalır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF747B74), fontSize: 14),
        ),
        const SizedBox(height: 32),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Align(
              child: ActionChip(
                label: Text(prompt),
                onPressed: () => _sendMessage(prompt),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE4E6DE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(
        message: _messages[index],
        isGenerating: _isGenerating && index == _messages.length - 1,
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE3E5DE)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C26352B),
                blurRadius: 18,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Mesajını yaz...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(18, 15, 8, 15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(7),
                child: IconButton.filled(
                  tooltip: 'Mesajı gönder',
                  onPressed: _isGenerating ? null : _sendMessage,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF426B52),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB9C5BA),
                    fixedSize: const Size(44, 44),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isGenerating});

  final _ChatMessage message;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF365D48) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
          border: isUser ? null : Border.all(color: const Color(0xFFE7E8E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.thinking.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  initiallyExpanded: isGenerating,
                  dense: true,
                  leading: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF739078),
                  ),
                  title: const Text(
                    'Düşünme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF506454),
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.thinking,
                        style: const TextStyle(
                          color: Color(0xFF777F77),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (message.content.isNotEmpty)
              SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF26332A),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            if (message.error != null)
              Text(
                message.error!,
                style: const TextStyle(color: Color(0xFF9D4D3D), height: 1.4),
              ),
            if (isGenerating &&
                message.content.isEmpty &&
                message.thinking.isEmpty)
              const _ThinkingIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          'Düşünüyor...',
          style: TextStyle(color: Color(0xFF747B74), fontSize: 14),
        ),
      ],
    );
  }
}
