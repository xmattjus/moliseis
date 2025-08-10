import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/suggestion/view_models/suggestion_view_model.dart';

class SuggestionSendButton extends StatelessWidget {
  const SuggestionSendButton({
    super.key,
    required this.onPressed,
    required this.viewModel,
  });

  final void Function() onPressed;

  final SuggestionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    // The widget success/loading states background and foreground colors.
    final bgColor = theme.tertiaryContainer;
    final fgColor = theme.onTertiaryContainer;

    // The widget error state background and foreground colors.
    final bgErrorColor = theme.errorContainer;
    final fgErrorColor = theme.onErrorContainer;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListenableBuilder(
        listenable: viewModel.uploadSuggestion,
        builder: (context, child) {
          if (viewModel.uploadSuggestion.error) {
            return _OutlinedCard(
              backgroundColor: bgErrorColor,
              foregroundColor: fgErrorColor,
              children: [
                Expanded(
                  child: Text(
                    "Si è verificato un errore durante l'invio.",
                    style: TextStyle(color: fgErrorColor),
                  ),
                ),
                TextButton(
                  onPressed: () => viewModel.uploadSuggestion.execute(),
                  style: TextButton.styleFrom(
                    backgroundColor: bgErrorColor,
                    foregroundColor: fgErrorColor,
                  ),
                  child: const Text('Riprova'),
                ),
              ],
            );
          }

          if (viewModel.uploadSuggestion.completed) {
            return _OutlinedCard(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              children: [
                Expanded(
                  child: Text(
                    "Il suggerimento è stato inviato correttamente, grazie!",
                    style: TextStyle(color: fgColor),
                  ),
                ),
              ],
            );
          }

          return AnimatedSwitcher(
            duration: Durations.medium1,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Align(
              key: ValueKey<bool>(viewModel.uploadSuggestion.running),
              alignment: Alignment.centerRight,
              child: viewModel.uploadSuggestion.running
                  ? _OutlinedCard(
                      backgroundColor: bgColor,
                      foregroundColor: fgColor,
                      children: [
                        CircularProgressIndicator(
                          constraints: BoxConstraints.tight(
                            const Size.square(20.0),
                          ),
                          color: fgColor,
                        ),
                        Text(
                          'Invio in corso...',
                          style: TextStyle(color: fgColor),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.send),
                      label: const Text('Invia'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: fgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        minimumSize: const Size(80.0, 56.0),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.children,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: foregroundColor),
        borderRadius: BorderRadius.circular(Shapes.medium),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8.0,
          children: children,
        ),
      ),
    );
  }
}
