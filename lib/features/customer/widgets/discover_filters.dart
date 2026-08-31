import 'package:flutter/material.dart';

import '../../../core/location/nearby_filter.dart';
import '../../../core/theme/app_theme.dart';

/// Nəticələrin sıralanması.
enum DiscoverSort {
  /// Serverin qaytardığı sıra: yaxınlıq seçilibsə onsuz da məsafəyə
  /// görədir, seçilməyibsə ən yenilər əvvəldədir.
  relevance,
  nearest,
  alphabetical;

  String get label => switch (this) {
        DiscoverSort.relevance => 'Uyğunluq',
        DiscoverSort.nearest => 'Ən yaxın',
        DiscoverSort.alphabetical => 'Əlifba',
      };
}

/// Kəşf ekranının süzgəc zolağı.
///
/// Əvvəl burada yalnız "Yaxınlıqdakıları göstər" adlı bir sətir vardı
/// və süzgəc kimi oxunmurdu: nə aktiv olduğu, nəyi kəsdiyi
/// görünmürdü. İndi vəziyyət nişan kimi göstərilir, radius və sıralama
/// isə bir toxunuşla dəyişir.
class DiscoverFilters extends StatelessWidget {
  const DiscoverFilters({
    super.key,
    required this.nearby,
    required this.sort,
    required this.resultCount,
    required this.onPickLocation,
    required this.onClearLocation,
    required this.onRadiusChanged,
    required this.onSortChanged,
    this.showSort = true,
  });

  final NearbyFilter? nearby;
  final DiscoverSort sort;

  /// Süzgəcin nəyə gətirdiyini göstərmək üçün — "12 nəticə".
  final int? resultCount;

  final VoidCallback onPickLocation;
  final VoidCallback onClearLocation;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<DiscoverSort> onSortChanged;

  /// Kateqoriya siyahısında sıralamanın mənası yoxdur.
  final bool showSort;

  bool get _active => nearby != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocationRow(
            nearby: nearby,
            resultCount: resultCount,
            onPick: onPickLocation,
            onClear: onClearLocation,
          ),

          // Radius və sıralama yalnız yer seçiləndən sonra məna kəsb
          // edir — əks halda boş yerə yer tutur.
          if (_active) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final option in NearbyFilter.radiusOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: '${option.toStringAsFixed(0)} km',
                        selected: nearby!.radiusKm == option,
                        onTap: () => onRadiusChanged(option),
                      ),
                    ),

                  if (showSort) ...[
                    const _ChipDivider(),
                    for (final option in DiscoverSort.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          label: option.label,
                          icon: option == DiscoverSort.nearest
                              ? Icons.near_me
                              : null,
                          selected: sort == option,
                          onTap: () => onSortChanged(option),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Yer sətri ───────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.nearby,
    required this.resultCount,
    required this.onPick,
    required this.onClear,
  });

  final NearbyFilter? nearby;
  final int? resultCount;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = nearby != null;

    return Material(
      color: active
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.field),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                active ? Icons.near_me : Icons.near_me_outlined,
                size: 17,
                color: active
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active ? nearby!.label : 'Yaxınlıqdakıları göstər',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (active)
                      Text(
                        resultCount == null
                            ? '${nearby!.radiusLabel} radius'
                            : '${nearby!.radiusLabel} radius · $resultCount nəticə',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),

              // Aktiv süzgəci ləğv etmək bir toxunuşluq olmalıdır —
              // pəncərəni açıb "ləğv et" axtarmaq lazım gəlməsin.
              if (active)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: 'Süzgəci ləğv et',
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onPrimaryContainer,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kiçik parçalar ──────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
