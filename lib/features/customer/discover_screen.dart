import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/location/location_service.dart';
import '../../core/location/nearby_filter.dart';
import '../../models/staff.dart';
import '../../repositories/repositories.dart';
import 'widgets/booking_widgets.dart';
import 'widgets/business_map.dart';
import 'widgets/discover_filters.dart';
import 'widgets/location_sheet.dart';
import '../../core/theme/app_theme.dart';

/// Kəşf ekranı — müştəri xidmət göstərəni burada tapır.
///
/// Axın: kateqoriya (Bərbər / Diş həkimi / Usta…) → həmin kateqoriyadakı
/// bizneslər → biznes seçilir və bron ekranına keçilir.
///
/// Axtarış kateqoriya seçimini atlayır: adam birbaşa "Elit" yazıb
/// bərbəri tapa bilər.
///
/// Yaxınlıq süzgəci hər üç görünüşə eyni cür təsir edir — kateqoriya
/// sayğacları da radiusdakı bizneslərə görə hesablanır, əks halda
/// "3 həkim" yazır, açanda boş çıxır.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onBusinessSelected});

  final ValueChanged<BusinessCard> onBusinessSelected;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _repo = PublicRepository();
  static const _location = LocationService();

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<ServiceCategory> _categories = const [];
  List<BusinessCard> _businesses = const [];

  /// null olanda kateqoriya siyahısı göstərilir.
  ServiceCategory? _category;
  String _query = '';

  NearbyFilter? _nearby;
  DiscoverSort _sort = DiscoverSort.relevance;

  /// Nəticələr siyahı və ya xəritə kimi göstərilir. Siyahı adları
  /// oxumaq, xəritə isə "hansı biri daha yaxındır" sualı üçündür.
  bool _mapView = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreThenLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Keçən dəfə seçilmiş yer bərpa olunur — adam hər açılışda eyni
  /// rayonu yenidən seçməməlidir.
  Future<void> _restoreThenLoad() async {
    final saved = await _location.restore();
    if (!mounted) return;
    setState(() => _nearby = saved);
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await _repo.listCategories(near: _nearby);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businesses = await _repo.listBusinesses(
        category: _category?.slug,
        query: _query,
        near: _nearby,
      );
      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _loading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    }
  }

  /// Cari görünüşü yenidən yükləyir.
  Future<void> _reload() =>
      _showingCategories ? _loadCategories() : _loadBusinesses();

  /// Sıralama serverdə deyil, burada tətbiq olunur: nəticə sayı azdır
  /// və seçim dəyişəndə yenidən sorğu göndərmək mənasızdır.
  List<BusinessCard> get _visibleBusinesses {
    final items = [..._businesses];

    switch (_sort) {
      case DiscoverSort.relevance:
        break;
      case DiscoverSort.nearest:
        // Məsafəsi bilinməyənlər sona düşür — "ən yaxın" siyahısında
        // yuxarıda durmaları yanıldıcı olardı.
        items.sort((a, b) {
          final left = a.distanceKm;
          final right = b.distanceKm;
          if (left == null && right == null) return 0;
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });
      case DiscoverSort.alphabetical:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return items;
  }

  /// Hər hərfdə sorğu göndərməmək üçün gecikdirilir.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _query = value);
      if (value.trim().isEmpty && _category == null) {
        _loadCategories();
      } else {
        _loadBusinesses();
      }
    });
  }

  void _openCategory(ServiceCategory category) {
    setState(() => _category = category);
    _loadBusinesses();
  }

  void _backToCategories() {
    setState(() {
      _category = null;
      _businesses = const [];
      _query = '';
      _searchController.clear();
    });
    _loadCategories();
  }

  Future<void> _pickLocation() async {
    final result = await LocationSheet.show(context, current: _nearby);
    if (result == null || !mounted) return;

    await _applyNearby(result.isCleared ? null : result);
  }

  /// Radius çipi — pəncərə açmadan dəyişir.
  Future<void> _changeRadius(double radiusKm) async {
    final current = _nearby;
    if (current == null || current.radiusKm == radiusKm) return;

    await _applyNearby(current.copyWith(radiusKm: radiusKm));
  }

  Future<void> _applyNearby(NearbyFilter? next) async {
    setState(() {
      _nearby = next;
      // Yaxınlıq ləğv olunanda "ən yaxın" sıralaması mənasız qalır.
      if (next == null && _sort == DiscoverSort.nearest) {
        _sort = DiscoverSort.relevance;
      }
    });

    await _location.save(next);
    await _reload();
  }

  /// Kateqoriya siyahısı yalnız kateqoriya seçilməyib və axtarış boş olanda.
  bool get _showingCategories => _category == null && _query.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ─── Axtarış ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Bərbər, həkim, usta axtarın…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
          ),
        ),

        // ─── Süzgəclər ───────────────────────────────────────
        DiscoverFilters(
          nearby: _nearby,
          sort: _sort,
          // Say yalnız biznes siyahısında mənalıdır.
          resultCount: _showingCategories ? null : _businesses.length,
          showSort: !_showingCategories,
          onPickLocation: _pickLocation,
          onClearLocation: () => _applyNearby(null),
          onRadiusChanged: _changeRadius,
          onSortChanged: (value) => setState(() => _sort = value),
        ),

        // ─── Nəticə başlığı ──────────────────────────────────
        if (!_showingCategories)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 12, 4),
            child: Row(
              children: [
                if (_category != null)
                  IconButton(
                    onPressed: _backToCategories,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Kateqoriyalara qayıt',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  const SizedBox(width: 8),

                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _category?.name ?? 'Axtarış nəticələri',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),

                // Siyahı ↔ xəritə. Xəritə koordinatı olan bizneslər
                // üçün mənalıdır, ona görə heç birində ünvan yoxdursa
                // düymə göstərilmir.
                if (_businesses.any((item) => item.hasCoordinates))
                  _ViewToggle(
                    mapView: _mapView,
                    onChanged: (value) => setState(() => _mapView = value),
                  ),
              ],
            ),
          ),

        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return EmptyState(icon: Icons.cloud_off_outlined, message: _error!);
    }

    if (_showingCategories) {
      if (_categories.isEmpty) {
        return EmptyState(
          icon: Icons.storefront_outlined,
          message: _nearby == null
              ? 'Hazırda əlçatan xidmət yoxdur'
              : '${_nearby!.radiusLabel} radiusunda xidmət tapılmadı.\n'
                  'Məsafəni artırın və ya başqa ünvan seçin.',
        );
      }

      return RefreshIndicator(
        onRefresh: _loadCategories,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _CategoryTile(
              category: category,
              onTap: () => _openCategory(category),
            );
          },
        ),
      );
    }

    if (_businesses.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        message: _query.trim().isNotEmpty
            ? '"${_query.trim()}" üzrə nəticə tapılmadı'
            : 'Bu kateqoriyada hələ biznes yoxdur',
      );
    }

    final visible = _visibleBusinesses;

    if (_mapView) {
      return BusinessMap(
        businesses: visible,
        origin: _nearby,
        onBusinessSelected: widget.onBusinessSelected,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBusinesses,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _BusinessTile(
          business: visible[index],
          onTap: () => widget.onBusinessSelected(visible[index]),
        ),
      ),
    );
  }
}

// ─── Siyahı ↔ xəritə ─────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mapView, required this.onChanged});

  final bool mapView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.view_list,
            tooltip: 'Siyahı',
            selected: !mapView,
            onTap: () => onChanged(false),
          ),
          _ToggleButton(
            icon: Icons.map_outlined,
            tooltip: 'Xəritə',
            selected: mapView,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? theme.colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Icon(
              icon,
              size: 17,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Biznes kartı ────────────────────────────────────────────

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({required this.business, required this.onTap});

  final BusinessCard business;
  final VoidCallback onTap;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = business.distanceLabel;

    // Ünvan sətri: "Nərimanov, Bakı" — ikisi də olmaya bilər.
    final place = [business.address, business.city]
        .where((part) => part.isNotEmpty)
        .join(', ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(business.name),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (business.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        business.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        distance,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kateqoriya kartı ────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ServiceCategory category;

  final VoidCallback onTap;

  /// Serverdən gələn ikon açarı → Material ikonu.
  ///
  /// Açar taksonomiya ilə birlikdə serverdə təyin olunur; burada yalnız
  /// göstərilişi var. Tanınmayan açar üçün ümumi mağaza ikonu qalır —
  /// serverə yeni kateqoriya əlavə olunanda tətbiq sınmır.
  static IconData _iconFor(String key) {
    switch (key) {
      case 'dentist':
        return Icons.medication_liquid_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'doctor':
        return Icons.medical_services_outlined;
      case 'lab':
        return Icons.biotech_outlined;
      case 'barber':
        return Icons.content_cut;
      case 'beauty':
        return Icons.spa_outlined;
      case 'spa':
        return Icons.self_improvement_outlined;
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'vet':
        return Icons.pets_outlined;
      case 'master':
        return Icons.handyman_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'photo':
        return Icons.photo_camera_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconFor(category.icon),
                  size: 21,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.count} xidmət göstərən',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
