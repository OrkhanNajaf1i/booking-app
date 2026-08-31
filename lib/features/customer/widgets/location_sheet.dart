import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/nearby_filter.dart';

/// "Haradasınız?" pəncərəsi.
///
/// İki yol yan-yana durur, çünki biri həmişə işləmir: GPS-ə icazə
/// verilməyə bilər, brauzerdə bloklana bilər. Ünvan axtarışı bu halda
/// ekranı bağlamır — istifadəçi rayonu əl ilə seçir.
///
/// Nəticə [NearbyFilter] kimi qaytarılır; ləğv edilsə `null`.
class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key, this.current});

  final NearbyFilter? current;

  static Future<NearbyFilter?> show(
    BuildContext context, {
    NearbyFilter? current,
  }) {
    return showModalBottomSheet<NearbyFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocationSheet(current: current),
    );
  }

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  static const _service = LocationService();

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<AddressSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  late double _radiusKm = widget.current?.radiusKm ?? 10;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Nominatim saniyədə bir sorğu qaydası qoyur — hər hərfdə getməsin.
  void _onSearchChanged(String value) {
    _debounce?.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _service.searchAddress(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    final result = await _service.currentPosition();
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _locating = false;
        _error = result.error;
      });
      return;
    }

    // Ad tapılmasa da davam edirik — koordinat kifayətdir.
    final label = await _service.describe(result.latitude!, result.longitude!);
    if (!mounted) return;

    Navigator.of(context).pop(NearbyFilter(
      latitude: result.latitude!,
      longitude: result.longitude!,
      radiusKm: _radiusKm,
      label: label ?? 'Cari yerim',
    ),);
  }

  void _pick(AddressSuggestion suggestion) {
    Navigator.of(context).pop(NearbyFilter(
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      radiusKm: _radiusKm,
      label: suggestion.label,
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Haradasınız?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yaxınlıqdakı xidmət göstərənləri görmək üçün yerinizi seçin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // ─── Cihazın yeri ────────────────────────────────
              FilledButton.tonalIcon(
                onPressed: _locating ? null : _useDeviceLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_locating ? 'Tapılır…' : 'Cari yerimi tap'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // ─── Radius ──────────────────────────────────────
              Text(
                'Məsafə',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in NearbyFilter.radiusOptions)
                    ChoiceChip(
                      label: Text('${option.toStringAsFixed(0)} km'),
                      selected: _radiusKm == option,
                      onSelected: (_) => setState(() => _radiusKm = option),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // ─── Ünvanla axtarış ─────────────────────────────
              Text(
                'Və ya ünvanı yazın',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'məs., Nərimanov, Bakı',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),

              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return InkWell(
                        onTap: () => _pick(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  suggestion.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (_searchController.text.trim().length >= 3 &&
                  !_searching &&
                  _suggestions.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ünvan tapılmadı. Başqa yazılışla cəhd edin.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // ─── Seçimi ləğv et ──────────────────────────────
              if (widget.current != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(NearbyFilter.cleared),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Yaxınlıq süzgəcini ləğv et'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
