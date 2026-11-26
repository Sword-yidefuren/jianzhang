import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/categories.dart';
import '../../domain/quick_parser.dart';
import '../../state/ledger_controller.dart';
import '../sheets/entry_sheet.dart';
import '../theme.dart';
import 'components.dart';

class QuickEntry extends StatefulWidget {
  const QuickEntry({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.showDetailedAction = true,
    this.onSaved,
  });

  final LedgerController controller;
  final bool autofocus;
  final bool showDetailedAction;
  final VoidCallback? onSaved;

  @override
  State<QuickEntry> createState() => _QuickEntryState();
}

class _QuickEntryState extends State<QuickEntry> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechToText();
  ParsedEntry? _parsed;
  bool _voiceAvailable = false;
  bool _voiceStarting = false;
  bool _voiceListening = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startVoice({bool allowNetwork = false}) async {
    if (_voiceStarting || _voiceListening) return;
    setState(() => _voiceStarting = true);
    try {
      if (!_voiceAvailable) {
        _voiceAvailable = await _speech.initialize(
          onError: (error) {
            if (mounted) _showVoiceError(_voiceErrorMessage(error.errorMsg));
          },
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _voiceListening = false);
            }
          },
        );
      }
      if (!_voiceAvailable) {
        _showVoiceError('这台设备没有可用的语音识别，继续打字吧');
        return;
      }
      final started = await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          _textController.text = words;
          _textController.selection = TextSelection.collapsed(
            offset: words.length,
          );
          _onChanged(words);
        },
        listenOptions: SpeechListenOptions(
          onDevice: !allowNetwork,
          partialResults: true,
          localeId: 'zh_CN',
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
        ),
      );
      if (mounted) setState(() => _voiceListening = started);
      if (!started) {
        if (allowNetwork) {
          _showVoiceError('语音识别没能启动，继续打字吧');
        } else {
          _offerNetworkVoice();
        }
      }
    } catch (_) {
      _showVoiceError('语音识别不可用，继续打字吧');
    } finally {
      if (mounted) setState(() => _voiceStarting = false);
    }
  }

  void _offerNetworkVoice() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('本机没有离线中文语音，可以用系统识别（会联网）'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '用系统识别',
          onPressed: () => _startVoice(allowNetwork: true),
        ),
      ),
    );
  }

  Future<void> _stopVoice() async {
    if (!_voiceListening) return;
    try {
      await _speech.stop();
    } catch (_) {
      // 停止失败不影响已识别的文字。
    }
    if (mounted) setState(() => _voiceListening = false);
  }

  String _voiceErrorMessage(String raw) {
    if (raw.contains('permission')) return '需要麦克风权限；也可以继续打字';
    if (raw.contains('network')) return '这台设备没有离线语音包，继续打字吧';
    return '语音识别不可用，继续打字吧';
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = QuickParser.parse(value, defaultAccount: '微信');
    });
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    final parsed = _parsed;
    if (parsed == null) {
      showEntryEditor(context, widget.controller, initialText: text);
      return;
    }
    final id = widget.controller.addParsed(parsed);
    _textController.clear();
    setState(() => _parsed = null);
    _focusNode.requestFocus();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已记下 ${parsed.direction.label} ${Money.format(parsed.amountCents)} · ${parsed.category}',
        ),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => widget.controller.deleteEntry(id),
        ),
      ),
    );
    widget.onSaved?.call();
  }

  void _useExample(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _onChanged(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '一句话记账',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                _textController.text.isEmpty ? '试试直接说' : '回车保存',
                style: const TextStyle(fontSize: 10.5, color: AppColors.faint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.line,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: '例如：午饭 25 微信',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.faint,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                    onTap: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: '按住说话（仅本机）',
                  child: GestureDetector(
                    onLongPressStart: (_) => _startVoice(),
                    onLongPressEnd: (_) => _stopVoice(),
                    child: Container(
                      width: 38,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _voiceListening
                            ? AppColors.expenseSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _voiceStarting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _voiceListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              size: 19,
                              color: _voiceListening
                                  ? AppColors.expense
                                  : AppColors.muted,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    onPressed: _submit,
                    style: IconButton.styleFrom(
                      backgroundColor: _textController.text.trim().isEmpty
                          ? AppColors.paperDeep
                          : AppColors.ink,
                      foregroundColor: _textController.text.trim().isEmpty
                          ? AppColors.faint
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                    tooltip: '记下',
                  ),
                ),
              ],
            ),
          ),
          if (_voiceStarting || _voiceListening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    _voiceListening
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_none_rounded,
                    size: 13,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _voiceStarting ? '正在准备麦克风…' : '正在听…松开结束',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '长按麦克风说话，仅本机识别',
                style: TextStyle(fontSize: 10.5, color: AppColors.faint),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: parsed == null
                ? _Examples(onTap: _useExample)
                : _Preview(parsed: parsed),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: AppColors.faint,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  '只在这台设备解析，不联网',
                  style: TextStyle(fontSize: 10.5, color: AppColors.faint),
                ),
              ),
              if (widget.showDetailedAction)
                TextButton.icon(
                  onPressed: () => showEntryEditor(context, widget.controller),
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('详细记一笔'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.parsed});

  final ParsedEntry parsed;

  @override
  Widget build(BuildContext context) {
    final isExpense = parsed.direction == EntryDirection.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            SoftTag(
              label: parsed.direction.label,
              color: color,
              background: color.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '${parsed.category}  ·  ${parsed.account}  ·  ${dayLabel(parsed.occurredAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ),
            const Spacer(),
            Text(
              Money.format(parsed.amountCents),
              style: AppTheme.numeric(
                size: 17,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const examples = ['午饭 25', '打车 18.5 支付宝', '工资 12000', '昨天 超市 128 微信'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final example in examples)
            InkWell(
              onTap: () => onTap(example),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  example,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
