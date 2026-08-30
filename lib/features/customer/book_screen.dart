import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../models/availability.dart';
import '../../models/staff.dart';
import '../../repositories/repositories.dart';
import 'widgets/booking_widgets.dart';

/// Vaxt seçmə ekranı.
///
/// Axın: biznes → mütəxəssis → xidmət → tarix → boş saat → bron.
///
/// Boş saatlar hər dəfə backend-dən gəlir; işçinin iş qrafiki, nahar
/// fasiləsi və seçim addımı orada tətbiq olunur — burada heç bir
/// vaxt hesablaması aparılmır.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  static const _publicRepo = PublicRepository();
  static const _customerRepo = CustomerRepository();
  static const _bookingRepo = BookingRepository();

  List<BusinessCard> _businesses = const [];
  List<StaffMember> _staff = const [];
  List<ServiceItem> _services = const [];

  BusinessCard? _business;
  StaffMember? _staffMember;
  ServiceItem? _service;
  DateTime _date = DateTime.now();
  TimeSlot? _slot;

  DayAvailability? _day;
  AvailabilityResult? _availability;

  bool _loadingBusinesses = true;
  bool _loadingSlots = false;
  bool _booking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loadingBusinesses = true;
      _error = null;
    });

    try {
      final businesses = await _publicRepo.listBusinesses();
      if (!mounted) return;

      setState(() {
        _businesses = businesses;
        _loadingBusinesses = false;
      });

      if (businesses.length == 1) {
        // Tək biznes varsa seçim addımını atlayırıq.
        await _selectBusiness(businesses.first);
      }
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loadingBusinesses = false;
      });
    }
  }

  Future<void> _selectBusiness(BusinessCard business) async {
    setState(() {
      _business = business;
      _staff = const [];
      _services = const [];
      _staffMember = null;
      _service = null;
      _slot = null;
      _day = null;
    });

    try {
      final staff = await _publicRepo.listStaff(business.id);
      if (!mounted) return;

      setState(() {
        _staff = staff;
        _staffMember = staff.isNotEmpty ? staff.first : null;
      });

      if (_staffMember != null) {
        await _loadServices();
        await _jumpToFirstOpenDay();
        await _loadSlots();
      }
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message);
    }
  }

  Future<void> _loadServices() async {
    final business = _business;
    final staff = _staffMember;
    if (business == null || staff == null) return;

    try {
      final services = await _publicRepo.listServices(
        business.id,
        staffId: staff.id,
      );
      if (!mounted) return;

      setState(() {
        _services = services;
        // Xidmət məcburi deyil — seçilməsə default müddət işlənir.
        _service = services.isNotEmpty ? services.first : null;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _services = const [];
        _service = null;
      });
    }
  }

  Future<void> _loadSlots() async {
    final business = _business;
    final staff = _staffMember;
    if (business == null || staff == null) return;

    setState(() {
      _loadingSlots = true;
      _slot = null;
      _error = null;
    });

    try {
      final result = await _publicRepo.getAvailability(
        businessId: business.id,
        staffId: staff.id,
        serviceId: _service?.id,
        from: _date,
        to: _date,
      );
      if (!mounted) return;

      setState(() {
        _availability = result;
        _day = result.days.isNotEmpty ? result.days.first : null;
        _loadingSlots = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loadingSlots = false;
      });
    }
  }

  /// Ilk acıq gune kecir.
  ///
  /// Bu gun bazar/bayram ola biler — bele halda musteri ekrani acan kimi
  /// "is gunu deyil" gorur ve elle tarix axtarmali olur. Ona gore
  /// birinci yuklemede novbeti 14 gunu bir sorguda goturub bos vaxti
  /// olan ilk gune atlayiriq.
  Future<void> _jumpToFirstOpenDay() async {
    final business = _business;
    final staff = _staffMember;
    if (business == null || staff == null) return;

    final today = DateTime.now();

    try {
      final result = await _publicRepo.getAvailability(
        businessId: business.id,
        staffId: staff.id,
        serviceId: _service?.id,
        from: today,
        to: today.add(const Duration(days: 13)),
      );

      for (final day in result.days) {
        if (day.availableSlots.isEmpty) continue;

        final parsed = DateTime.tryParse(day.date);
        if (parsed != null && mounted) {
          setState(() => _date = parsed);
        }
        return;
      }
    } on ApiException {
      // Tapilmasa secilmis gun oldugu kimi qalir.
    }
  }

  Future<void> _confirm() async {
    final business = _business;
    final staff = _staffMember;
    final slot = _slot;
    if (business == null || staff == null || slot == null) return;

    setState(() => _booking = true);

    try {
      // Bron customer_id tələb edir; JWT-də yalnız user_id var.
      final customerId = await _customerRepo.resolveSelfId(business.id);

      await _bookingRepo.create(
        customerId: customerId,
        staffId: staff.id,
        serviceId: _service?.id,
        startTime: slot.start,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorğunuz göndərildi — təsdiq gözlənilir'),
        ),
      );

      await _loadSlots();
    } on ApiException catch (exception) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );

      // Başqası eyni anda tutubsa siyahı köhnə qalmasın.
      if (exception.isSlotTaken) await _loadSlots();
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingBusinesses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_businesses.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        message: _error ?? 'Hazırda əlçatan biznes yoxdur',
      );
    }

    // Addım 1 — biznes seçimi.
    if (_business == null) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _businesses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final business = _businesses[index];
          return Card(
            child: ListTile(
              title: Text(business.name),
              subtitle:
                  business.subtitle.isEmpty ? null : Text(business.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectBusiness(business),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Seçilmiş biznes — dəyişdirmək mümkündür.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(_business!.name),
                  subtitle: _business!.subtitle.isEmpty
                      ? null
                      : Text(_business!.subtitle),
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _business = null;
                      _staffMember = null;
                      _slot = null;
                      _day = null;
                    }),
                    child: const Text('Dəyiş'),
                  ),
                ),
              ),

              if (_staff.isEmpty) ...[
                const SizedBox(height: 16),
                const EmptyState(
                  icon: Icons.person_off_outlined,
                  message: 'Bu biznesdə hələ mütəxəssis yoxdur',
                ),
              ] else ...[
                const SizedBox(height: 20),
                SectionLabel(label: 'Mütəxəssis', theme: theme),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _staff.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final member = _staff[index];
                      return ChoiceChip(
                        label: Text(member.displayName),
                        selected: _staffMember?.id == member.id,
                        onSelected: (_) async {
                          setState(() => _staffMember = member);
                          await _loadServices();
                          await _loadSlots();
                        },
                      );
                    },
                  ),
                ),

                if (_services.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SectionLabel(label: 'Xidmət', theme: theme),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _services.map((service) {
                      return ChoiceChip(
                        label: Text(
                          '${service.name} · ${service.durationMinutes} dəq',
                        ),
                        selected: _service?.id == service.id,
                        onSelected: (_) {
                          setState(() => _service = service);
                          _loadSlots();
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 20),
                SectionLabel(label: 'Tarix', theme: theme),
                const SizedBox(height: 8),
                DateStrip(
                  selected: _date,
                  onChanged: (date) {
                    setState(() => _date = date);
                    _loadSlots();
                  },
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    SectionLabel(label: 'Boş vaxtlar', theme: theme),
                    const Spacer(),
                    if (_availability != null)
                      Text(
                        '${_availability!.durationMins} dəq · '
                        '${_availability!.slotStepMins} dəq addım',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                if (_day?.breakInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nahar fasiləsi: '
                    '${_day!.breakInfo!.start}–${_day!.breakInfo!.end}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                SlotGrid(
                  loading: _loadingSlots,
                  day: _day,
                  selected: _slot,
                  onSelect: (slot) => setState(() => _slot = slot),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),

        // Seçim edilən kimi alt panel görünür.
        if (_slot != null)
          BookingBar(
            label: DateFormat('d MMMM, HH:mm', 'az').format(_slot!.start),
            subtitle: '${_slot!.durationMins} dəqiqə',
            busy: _booking,
            onConfirm: _confirm,
          ),
      ],
    );
  }
}
