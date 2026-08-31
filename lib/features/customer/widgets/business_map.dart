import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/location/nearby_filter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/staff.dart';

/// Bizneslərin xəritə görünüşü.
///
/// Siyahı "hansı biri daha yaxındır" sualına yaxşı cavab vermir —
/// məsafə rəqəmi bir şey deyir, amma adam şəhəri xəritədə tanıyır.
/// Ona görə eyni nəticələr həm siyahı, həm xəritə kimi göstərilir.
///
/// Koordinatı olmayan biznes xəritədə görünə bilmir; onların sayı
/// aşağıda qeyd kimi yazılır ki, adam "niyə hamısı yoxdur" deməsin.
class BusinessMap extends StatefulWidget {
  const BusinessMap({
    super.key,
    required this.businesses,
    required this.onBusinessSelected,
    this.origin,
  });

  final List<BusinessCard> businesses;
  final ValueChanged<BusinessCard> onBusinessSelected;

  /// İstifadəçinin nöqtəsi — seçilibsə xəritədə ayrıca göstərilir.
  final NearbyFilter? origin;

  @override
  State<BusinessMap> createState() => _BusinessMapState();
}

class _BusinessMapState extends State<BusinessMap> {
  final _controller = MapController();

  /// Nişana toxunanda aşağıda həmin biznesin kartı çıxır.
  BusinessCard? _selected;

  /// Bakının mərkəzi — heç nə tapılmayanda xəritə boş qalmasın.
  static const _fallbackCenter = LatLng(40.4093, 49.8671);

  List<BusinessCard> get _mappable =>
      widget.businesses.where((item) => item.hasCoordinates).toList();

  @override
  void didUpdateWidget(BusinessMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Siyahı dəyişəndə seçim köhnəlmiş ola bilər.
    if (_selected != null &&
        !widget.businesses.any((item) => item.id == _selected!.id)) {
      setState(() => _selected = null);
    }
  }

  LatLng get _initialCenter {
    if (widget.origin != null) {
      return LatLng(widget.origin!.latitude, widget.origin!.longitude);
    }
    final points = _mappable;
    if (points.isEmpty) return _fallbackCenter;

    // Nöqtələrin ortası — hamısı bir ekranda görünsün.
    final latitude =
        points.map((item) => item.latitude!).reduce((a, b) => a + b) / points.length;
    final longitude =
        points.map((item) => item.longitude!).reduce((a, b) => a + b) / points.length;
    return LatLng(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    final mappable = _mappable;
    final hidden = widget.businesses.length - mappable.length;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: widget.origin != null ? 12.5 : 11,
            // Xəritəyə boş yerə toxunanda seçim bağlanır.
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // OpenStreetMap istifadə qaydası tətbiqin adını tələb edir.
              userAgentPackageName: 'az.bookify.app',
              maxZoom: 19,
            ),

            // İstifadəçinin nöqtəsi və radius dairəsi.
            if (widget.origin != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(
                      widget.origin!.latitude,
                      widget.origin!.longitude,
                    ),
                    radius: widget.origin!.radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: AppPalette.brand600.withValues(alpha: 0.08),
                    borderColor: AppPalette.brand600.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      widget.origin!.latitude,
                      widget.origin!.longitude,
                    ),
                    width: 22,
                    height: 22,
                    child: const _OriginDot(),
                  ),
                ],
              ),
            ],

            MarkerLayer(
              markers: [
                for (final business in mappable)
                  Marker(
                    point: LatLng(business.latitude!, business.longitude!),
                    width: 44,
                    height: 44,
                    child: _BusinessPin(
                      business: business,
                      selected: _selected?.id == business.id,
                      onTap: () => setState(() => _selected = business),
                    ),
                  ),
              ],
            ),

            // OpenStreetMap-in istifadə şərti: mənbə göstərilməlidir.
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('OpenStreetMap')],
            ),
          ],
        ),

        // Koordinatı olmayanlar xəritədə görünmür — bunu deyirik.
        if (hidden > 0)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _Notice(text: '$hidden xidmət göstərənin ünvanı qeyd olunmayıb'),
          ),

        if (mappable.isEmpty)
          Center(
            child: _Notice(
              text: widget.businesses.isEmpty
                  ? 'Nəticə yoxdur'
                  : 'Heç birinin xəritə ünvanı yoxdur',
            ),
          ),

        // Seçilmiş biznesin kartı.
        if (_selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedCard(
              business: _selected!,
              onOpen: () => widget.onBusinessSelected(_selected!),
              onClose: () => setState(() => _selected = null),
            ),
          ),

        // Yaxınlaşdırma düymələri — bəzi cihazlarda barmaqla
        // miqyaslamaq çətindir.
        Positioned(
          right: 12,
          bottom: _selected != null ? 130 : 20,
          child: Column(
            children: [
              _ZoomButton(
                icon: Icons.add,
                onTap: () => _controller.move(
                  _controller.camera.center,
                  _controller.camera.zoom + 1,
                ),
              ),
              const SizedBox(height: 6),
              _ZoomButton(
                icon: Icons.remove,
                onTap: () => _controller.move(
                  _controller.camera.center,
                  _controller.camera.zoom - 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Xəritə nişanları ────────────────────────────────────────

class _BusinessPin extends StatelessWidget {
  const _BusinessPin({
    required this.business,
    required this.selected,
    required this.onTap,
  });

  final BusinessCard business;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: selected ? 1.2 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppPalette.brand800 : AppPalette.brand700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront, size: 15, color: Colors.white),
            ),
            // Nişanın ucu — nöqtəni dəqiq göstərir.
            CustomPaint(
              size: const Size(10, 6),
              painter: _PinTail(
                color: selected ? AppPalette.brand800 : AppPalette.brand700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  const _PinTail({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTail oldDelegate) => oldDelegate.color != color;
}

class _OriginDot extends StatelessWidget {
  const _OriginDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppPalette.info.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Köməkçi parçalar ────────────────────────────────────────

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.business,
    required this.onOpen,
    required this.onClose,
  });

  final BusinessCard business;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = [business.address, business.city]
        .where((part) => part.isNotEmpty)
        .join(', ');

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.card),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (business.subtitle.isNotEmpty)
                      Text(
                        business.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (place.isNotEmpty || business.distanceLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          [
                            if (business.distanceLabel != null)
                              business.distanceLabel!,
                            if (place.isNotEmpty) place,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.brand700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Bağla',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
