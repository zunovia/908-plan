import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String getDailyPrompt(AppLocalizations l10n, int dayNumber) {
  final prompts = [
    l10n.prompt_0, l10n.prompt_1, l10n.prompt_2, l10n.prompt_3,
    l10n.prompt_4, l10n.prompt_5, l10n.prompt_6, l10n.prompt_7,
    l10n.prompt_8, l10n.prompt_9, l10n.prompt_10, l10n.prompt_11,
    l10n.prompt_12, l10n.prompt_13, l10n.prompt_14, l10n.prompt_15,
    l10n.prompt_16, l10n.prompt_17, l10n.prompt_18, l10n.prompt_19,
  ];
  return prompts[dayNumber % prompts.length];
}
