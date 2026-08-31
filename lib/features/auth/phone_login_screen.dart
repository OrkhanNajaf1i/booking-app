import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/phone_code.dart';
import '../../state/app_state.dart';

/// Telefon nömrəsi ilə giriş.
///
/// İki addım: nömrə → kod. Şifrə yoxdur — şifrə unudulur, telefon isə
/// əldədir. Hesabı olmayan adam üçün ayrıca qeydiyyat da lazım deyil,
/// ilk təsdiqdə hesab özü yaranır.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key, required this.onUseEmail});

  /// E-poçt/şifrə ekranına keçid — xidmət göstərənlər üçün lazımdır.
  final VoidCallback onUseEmail;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

  /// null olanda nömrə addımı, dolu olanda kod addımı göstərilir.
  PhoneCodeRequest? _pending;

  Timer? _ticker;
  int _resendIn = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _ticker?.cancel();
    setState(() => _resendIn = seconds);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _requestCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final result = await auth.requestPhoneCode(_phoneController.text);

    if (!mounted) return;

    if (result == null) {
      _showError(auth.error ?? 'Kod göndərilmədi');
      return;
    }

    setState(() {
      _pending = result;
      _codeController.clear();
    });
    _startResendCountdown(result.resendAfter);

    // İnkişaf rejimində kod cavabda gəlir — əl ilə köçürmək
    // lazım gəlməsin deyə sahəyə yazılır.
    if (result.debugCode != null) {
      _codeController.text = result.debugCode!;
    }
  }

  Future<void> _verify() async {
    final pending = _pending;
    if (pending == null) return;

    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('Kod 6 rəqəmdən ibarətdir');
      return;
    }

    final auth = context.read<AuthController>();
    final ok = await auth.verifyPhoneCode(
      // Serverin qaytardığı forma göndərilir: istifadəçinin yazdığı
      // "050…" ilə normallaşdırılmış "+994 50…" fərqlidir.
      phone: pending.phone,
      code: code,
      fullName: _nameController.text.trim(),
    );

    if (!ok && mounted) _showError(auth.error ?? 'Kod təsdiqlənmədi');
    // Uğurlu olanda AuthController notifyListeners edir və kök widget
    // ana ekrana keçir.
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _backToPhone() {
    _ticker?.cancel();
    setState(() {
      _pending = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 36),
                  if (_pending == null)
                    _buildPhoneStep(theme, auth)
                  else
                    _buildCodeStep(theme, auth, _pending!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. Nömrə ────────────────────────────────────────────

  Widget _buildPhoneStep(ThemeData theme, AuthController auth) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nömrənizi yazın', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Nömrənizə 6 rəqəmli təsdiq kodu göndərəcəyik.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobil nömrə',
              hintText: '050 111 22 33',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 9) return 'Nömrəni tam yazın';
              return null;
            },
            onFieldSubmitted: (_) => _requestCode(),
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.isLoading ? null : _requestCode,
            child: auth.isLoading
                ? const _ButtonSpinner()
                : const Text('Kod göndər'),
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onUseEmail,
            child: const Text('E-poçt və şifrə ilə daxil ol'),
          ),
        ],
      ),
    );
  }

  // ─── 2. Kod ──────────────────────────────────────────────

  Widget _buildCodeStep(ThemeData theme, AuthController auth, PhoneCodeRequest pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _backToPhone,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Nömrəni dəyiş'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 12),

        Text('Kodu yazın', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              TextSpan(text: _channelLabel(pending.channel)),
              TextSpan(
                text: pending.maskedPhone,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' nömrəsinə göndərildi.'),
            ],
          ),
        ),

        if (pending.isDevelopmentChannel) ...[
          const SizedBox(height: 14),
          _DevelopmentNotice(code: pending.debugCode ?? ''),
        ],

        const SizedBox(height: 22),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: theme.textTheme.headlineSmall?.copyWith(
            letterSpacing: 10,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
          ),
          onChanged: (value) {
            // Altı rəqəm dolan kimi özü göndərilir — adam ayrıca
            // düyməyə basmasın.
            if (value.length == 6 && !auth.isLoading) _verify();
          },
        ),

        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Adınız (istəyə bağlı)',
            hintText: 'Randevu zamanı göstərilir',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),

        const SizedBox(height: 20),
        FilledButton(
          onPressed: auth.isLoading ? null : _verify,
          child: auth.isLoading
              ? const _ButtonSpinner()
              : const Text('Təsdiqlə və daxil ol'),
        ),

        const SizedBox(height: 10),
        TextButton(
          onPressed: _resendIn > 0 || auth.isLoading ? null : _requestCode,
          child: Text(
            _resendIn > 0
                ? 'Yeni kod $_resendIn saniyə sonra'
                : 'Yeni kod göndər',
          ),
        ),
      ],
    );
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'whatsapp':
        return 'Kod WhatsApp ilə ';
      case 'sms':
        return 'Kod SMS ilə ';
      default:
        return 'Kod ';
    }
  }
}

// ─── Köməkçi parçalar ────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.event_available, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          'Bookify',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Həkim, bərbər və ustalara randevu',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// İnkişaf rejimində kodun harada olduğunu izah edir.
///
/// Real kanalda görünmür — `channel == 'log'` yalnız SMS/WhatsApp
/// açarları qurulmayanda olur.
class _DevelopmentNotice extends StatelessWidget {
  const _DevelopmentNotice({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppPalette.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.construction, size: 16, color: AppPalette.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'İnkişaf rejimi: SMS göndərilmir. Kod — $code',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppPalette.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
