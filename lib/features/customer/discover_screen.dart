import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/staff.dart';
import '../../repositories/repositories.dart';
import 'widgets/booking_widgets.dart';

/// Kəşf ekranı — müştəri xidmət göstərəni burada tapır.
///
/// Axın: sahə (Bərbər / Diş Həkimi / Usta…) → həmin sahədəki bizneslər
/// → biznes seçilir və bron ekranına keçilir.
///
/// Axtarış sahə seçimini atlayır: adam birbaşa "Elit" yazıb bərbəri
/// tapa bilər.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onBusinessSelected});

  final ValueChanged<BusinessCard> onBusinessSelected;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _repo = PublicRepository();

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<ServiceCategory> _categories = const [];
  List<BusinessCard> _businesses = const [];

  /// null olanda kateqoriya siyahısı göstərilir.
  String? _category;
  String _query = '';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await _repo.listCategories();
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
        category: _category,
        query: _query,
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

  void _openCategory(String name) {
    setState(() => _category = name);
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

  /// Sahə siyahısı yalnız kateqoriya seçilməyib və axtarış boş olanda.
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

        // ─── Seçilmiş sahə ───────────────────────────────────
        if (_category != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _backToCategories,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Sahələrə qayıt',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _category!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
        return const EmptyState(
          icon: Icons.storefront_outlined,
          message: 'Hazırda əlçatan xidmət yoxdur',
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
              onTap: () => _openCategory(category.name),
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
            : 'Bu sahədə hələ biznes yoxdur',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBusinesses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _businesses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final business = _businesses[index];

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => widget.onBusinessSelected(business),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
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
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.toUpperCase();
  }
}

// ─── Kateqoriya kartı ────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  /// Sahə adına uyğun ikon — tanınmayan sahə üçün ümumi mağaza ikonu.
  static IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bərbər') || lower.contains('berber') ||
        lower.contains('barber') || lower.contains('saç')) {
      return Icons.content_cut;
    }
    if (lower.contains('həkim') || lower.contains('hekim') ||
        lower.contains('diş') || lower.contains('dentist') ||
        lower.contains('klinika') || lower.contains('health')) {
      return Icons.medical_services_outlined;
    }
    if (lower.contains('usta') || lower.contains('repair') ||
        lower.contains('təmir')) {
      return Icons.handyman_outlined;
    }
    if (lower.contains('gözəllik') || lower.contains('beauty') ||
        lower.contains('salon')) {
      return Icons.spa_outlined;
    }
    return Icons.storefront_outlined;
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
                  _iconFor(category.name),
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
