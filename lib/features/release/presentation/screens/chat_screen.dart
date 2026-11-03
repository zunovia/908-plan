import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/content_models.dart';
import '../../domain/dialogue_engine.dart';
import '../../domain/models.dart';
import '../../domain/release_tools.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/crisis_banner.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';

/// 対話の 1 行（表示順: 反映 → 再生リマインド → 肯定/FAQ → カード）。
sealed class _ChatMessage {
  const _ChatMessage();
}

class _UserMsg extends _ChatMessage {
  const _UserMsg(this.text);
  final String text;
}

class _ReplyMsg extends _ChatMessage {
  const _ReplyMsg(this.text);
  final String text;
}

class _ReplayMsg extends _ChatMessage {
  const _ReplayMsg(this.text);
  final String text;
}

class _CardMsg extends _ChatMessage {
  const _CardMsg(this.card);
  final CardItem card;
}

/// 対話（Luckarise の Chat を移植。端末内の決まった応答のみ。AI・外部送信・報告ボタン・経路表示はなし）。
/// 危機と判定したら本文は保存されず、相談窓口へ移る。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  bool _softBanner = false;
  bool _replayShown = false;
  EmotionTag? _lastEmotion;
  TriggerKind? _lastTrigger;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send({required String text, EmotionTag? emotion, String? displayText}) async {
    if (_sending) return;
    final trimmed = text.length > 300 ? text.substring(0, 300) : text;
    final shown = displayText ?? trimmed;
    setState(() {
      _sending = true;
      if (shown.trim().isNotEmpty) _messages.add(_UserMsg(shown));
    });
    _scrollToEnd();
    try {
      final result = await ref.read(dialogueRepositoryProvider).respond(
            text: trimmed,
            emotionHint: emotion,
            lang: ref.read(releaseContentLangProvider),
            replayShownInSession: _replayShown,
          );
      if (!mounted) return;
      final outcome = result.outcome;
      switch (outcome) {
        case DialogueCrisis(:final abuse):
          setState(() => _sending = false);
          context.go(ReleasePaths.crisisWith(abuse: abuse));
          return;
        case DialogueReply(:final turn):
          setState(() {
            final reflection = turn.reflection;
            if (reflection != null) _messages.add(_ReplyMsg(reflection));
            final replay = turn.replay;
            if (replay != null) {
              _messages.add(_ReplayMsg(replay.text));
              _replayShown = true;
            }
            final secondary = turn.faqText ?? turn.affirmation;
            if (secondary != null) _messages.add(_ReplyMsg(secondary));
            final card = turn.card;
            if (card != null) _messages.add(_CardMsg(card));
            _softBanner = _softBanner || turn.softCrisis;
            _lastEmotion = turn.emotion;
            _lastTrigger = turn.trigger;
            _sending = false;
          });
          _scrollToEnd();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).rel_vx_chat_error)),
      );
    }
  }

  Future<void> _another(String previousCardId) async {
    final card = await ref.read(dialogueRepositoryProvider).anotherCard(
          previousCardId: previousCardId,
          emotion: _lastEmotion,
          trigger: _lastTrigger,
          lang: ref.read(releaseContentLangProvider),
        );
    if (!mounted) return;
    setState(() {
      final index = _messages.lastIndexWhere((m) => m is _CardMsg && m.card.id == previousCardId);
      if (index < 0) return;
      if (card != null) {
        _messages[index] = _CardMsg(card);
      } else {
        _messages.removeAt(index);
      }
    });
  }

  Future<void> _startCard(CardItem card) async {
    switch (card.kind) {
      case CardKind.BREATH:
        context.push(ReleasePaths.breathWith(cardId: card.id));
      case CardKind.WATER:
        // 水を飲むカードは、カードだけで終わる実践として記録する（Luckarise と同じ）。
        final repo = ref.read(releaseRepositoryProvider);
        final id = await repo.startSession(kind: SessionKind.WATER, emotion: _lastEmotion, cardId: card.id);
        await repo.finishSession(id, 1);
        if (mounted) context.go(ReleasePaths.doneFor(id));
      default:
        context.push(
          ReleasePaths.scene,
          extra: ReleaseSceneArgs(mode: ReleaseMode.fromName(card.kind.name), cardId: card.id, emotion: _lastEmotion),
        );
    }
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _send(text: text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final freeTextAllowed = ref.watch(releaseFreeTextAllowedProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: RelAppBar(title: l10n.rel_chat_title),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(l10n.rel_vx_intro_on_device, style: RelStyles.caption.copyWith(color: p.subText, fontSize: 12)),
            ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  for (final (tag, label) in relEmotionChips(l10n))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(label),
                        onPressed: _sending ? null : () => _send(text: '', emotion: tag, displayText: label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return switch (m) {
                    _UserMsg(:final text) => UserBubble(text: text),
                    _ReplyMsg(:final text) => ReplyBubble(text: text),
                    _ReplayMsg(:final text) => ReplayLine(text: text),
                    _CardMsg(:final card) => CardBubble(
                        text: card.text,
                        prompt: card.prompt,
                        startLabel: l10n.rel_chat_card_start,
                        anotherLabel: l10n.rel_chat_card_another,
                        onStart: () => _startCard(card),
                        onAnother: () => _another(card.id),
                      ),
                  };
                },
              ),
            ),
            if (_softBanner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: CrisisBanner(
                  text: l10n.rel_chat_soft_crisis_banner,
                  actionLabel: l10n.rel_chat_soft_crisis_action,
                  onTap: () => context.push(ReleasePaths.crisis),
                ),
              ),
            if (freeTextAllowed)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: l10n.rel_chat_input_placeholder,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: _sending ? null : _submit,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(l10n.rel_chat_send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
