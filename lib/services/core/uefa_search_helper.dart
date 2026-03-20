import 'package:flutter/material.dart';
import 'package:sportsense/widgets/uefa_search_indicator.dart';
import 'uefa_search_manager.dart';

/// Helper для интеграции UEFA Search в чат.
class UefaSearchWrapper extends StatelessWidget {
  final UefaSearchManager searchManager;
  final Widget child;

  const UefaSearchWrapper({
    super.key,
    required this.searchManager,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: searchManager,
      builder: (context, _) {
        return Column(
          children: [
            child,

            // Индикатор поиска
            if (searchManager.isSearching)
              const UefaSearchIndicator(),

            // Индикатор ошибки
            if (searchManager.hasError)
              UefaErrorIndicator(
                message: searchManager.errorMessage,
                onRetry: () => searchManager.retry(),
              ),
          ],
        );
      },
    );
  }
}
