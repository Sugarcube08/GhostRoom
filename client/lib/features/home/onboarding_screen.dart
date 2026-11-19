import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers.dart';
import '../../core/widgets/navigation_shell.dart';
import '../../core/theme/brand_assets.dart';
import '../../core/theme/ghost_theme.dart';
import '../../design_system/colors.dart';
import '../../design_system/spacing.dart';
import '../../design_system/typography.dart';
import '../../design_system/components/ghost_button.dart';
import '../../design_system/components/ghost_input.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  String? _mnemonic;
  String? _publicId;
  String? _fingerprint;
  bool _isGenerating = false;
  bool _keyfileExported = false;

  final TextEditingController _pinController = TextEditingController();
  final List<int> _verificationIndices = [];
  final Map<int, String> _verificationAnswers = {};

  @override
  void dispose() {
    _pageController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutQuad,
    );
  }

  void _generateIdentity() async {
    setState(() => _isGenerating = true);
    final idService = ref.read(identityServiceProvider);

    await Future.delayed(const Duration(milliseconds: 600));

    final mnemonic = idService.generateNewMnemonic();
    final tempIdentity = await idService.restoreIdentity(mnemonic);

    setState(() {
      _mnemonic = mnemonic;
      _publicId = tempIdentity.publicId;
      _fingerprint = tempIdentity.fingerprint;
      _isGenerating = false;
    });

    _verificationIndices.clear();
    while (_verificationIndices.length < 3) {
      final idx = (DateTime.now().microsecondsSinceEpoch % 24);
      if (!_verificationIndices.contains(idx)) {
        _verificationIndices.add(idx);
      }
    }
    _verificationIndices.sort();

    _nextPage();
  }

  Future<void> _exportKeyfile() async {
    if (_mnemonic == null || _publicId == null || _fingerprint == null) return;

    final keyfileService = ref.read(keyfileServiceProvider);
    final password = _pinController.text.trim();

    try {
      final keyfile = keyfileService.createKeyfile(
        mnemonic: _mnemonic!,
        publicId: _publicId!,
        fingerprint: _fingerprint!,
        password: password,
      );

      await keyfileService.shareKeyfile(keyfile: keyfile);

      if (mounted) {
        setState(() => _keyfileExported = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted .ghostkey file generated and exported.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export keyfile: $e')),
        );
      }
    }
  }

  void _verifyAndProceed() {
    if (_mnemonic == null) return;
    final words = _mnemonic!.split(' ');
    bool allCorrect = true;

    for (final idx in _verificationIndices) {
      final answer = _verificationAnswers[idx]?.trim().toLowerCase() ?? '';
      if (answer != words[idx]) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      _nextPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Word verification mismatch. Please check your recovery seed.'),
        ),
      );
    }
  }

  void _completeOnboarding() async {
    final idService = ref.read(identityServiceProvider);
    if (!idService.hasIdentity && _mnemonic != null) {
      await idService.restoreIdentity(_mnemonic!);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NavigationShell()),
      );
    }
  }

  void _openDualRecoveryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const DualRecoverySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomeView(colors),
            _buildCredentialsView(colors),
            _buildVerificationView(colors),
            _buildReadyView(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView(GhostColorsExtension colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const GhostRoomMark(size: 84),
          const SizedBox(height: 20),
          const GhostRoomWordmark(height: 26),
          const SizedBox(height: 12),
          Text(
            'SOVEREIGN CRYPTOGRAPHIC IDENTITY',
            style: AppTypography.caption(context).copyWith(
              color: colors.accent,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: colors.hairline, width: 1),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  icon: Icons.shield_outlined,
                  title: 'Zero Account Infrastructure',
                  desc: 'No phone number. No email. No servers hold your private keys.',
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.vpn_key_outlined,
                  title: 'Dual-Method Key Derivation',
                  desc: 'Unlock with a 24-word BIP-39 mnemonic or a portable .ghostkey file.',
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.lock_clock_outlined,
                  title: 'End-to-End Cryptography',
                  desc: 'Ed25519 signing, X25519 key-exchange, and XChaCha20-Poly1305 AEAD.',
                  colors: colors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          GhostButton(
            label: _isGenerating ? 'DERIVING KEYS...' : 'CREATE NEW IDENTITY',
            type: GhostButtonType.accent,
            isLoading: _isGenerating,
            width: double.infinity,
            onPressed: _isGenerating ? null : _generateIdentity,
          ),
          const SizedBox(height: 14),
          GhostButton(
            label: 'LOGIN / IMPORT KEYFILE',
            type: GhostButtonType.secondary,
            width: double.infinity,
            onPressed: _openDualRecoveryModal,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
    required GhostColorsExtension colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.hairline),
          ),
          child: Icon(icon, size: 20, color: colors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialsView(GhostColorsExtension colors) {
    final words = _mnemonic?.split(' ') ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.accent.withAlpha(80)),
                ),
                child: Text(
                  'STEP 1 OF 2',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'DUAL CREDENTIALS',
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Save Your Identity Vault',
            style: AppTypography.title(context),
          ),
          const SizedBox(height: 6),
          Text(
            'GhostRoom creates two recovery methods: an offline BIP-39 mnemonic passphrase and an encrypted .ghostkey file.',
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 20),

          // Card 1: BIP-39 Mnemonic Passphrase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: colors.hairline, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_outlined, size: 18, color: colors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'BIP-39 RECOVERY PASSPHRASE',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy all 24 words',
                      color: colors.textSecondary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _mnemonic ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('24-word seed phrase copied to clipboard.')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(words.length, (i) {
                    return Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.hairline),
                      ),
                      child: Text(
                        '${i + 1}. ${words[i]}',
                        style: AppTypography.mono(
                          context,
                          fontSize: 11,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: Encrypted .ghostkey File Export
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                color: _keyfileExported ? colors.success.withAlpha(120) : colors.hairline,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _keyfileExported ? Icons.check_circle_outline : Icons.file_download_outlined,
                      size: 20,
                      color: _keyfileExported ? colors.success : colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PORTABLE .GHOSTKEY FILE',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_keyfileExported)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.success.withAlpha(80)),
                        ),
                        child: Text(
                          'EXPORTED',
                          style: TextStyle(color: colors.success, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Hardware-encrypted backup file (Argon2id + XChaCha20-Poly1305). Unlock anytime with your file and password.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                GhostInput(
                  controller: _pinController,
                  hintText: 'Set a Keyfile decryption PIN or password...',
                  obscureText: true,
                  labelText: 'KEYFILE PASSWORD / PIN',
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: _keyfileExported ? 'EXPORT AGAIN' : 'DOWNLOAD & SAVE .GHOSTKEY',
                  type: _keyfileExported ? GhostButtonType.secondary : GhostButtonType.primary,
                  icon: Icons.download,
                  width: double.infinity,
                  onPressed: _exportKeyfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          GhostButton(
            label: 'PROCEED TO VERIFICATION',
            type: GhostButtonType.accent,
            width: double.infinity,
            onPressed: _nextPage,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVerificationView(GhostColorsExtension colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.accent.withAlpha(80)),
                ),
                child: Text(
                  'STEP 2 OF 2',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'SECURITY CHECK',
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm Recovery Seed',
            style: AppTypography.title(context),
          ),
          const SizedBox(height: 6),
          Text(
            'Verify three random words from your 24-word seed phrase to ensure you have documented it accurately.',
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 24),
          ..._verificationIndices.map((idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GhostInput(
                labelText: 'Word #${idx + 1}',
                hintText: 'Enter word #${idx + 1}...',
                isMonospace: true,
                onChanged: (val) => _verificationAnswers[idx] = val,
              ),
            );
          }),
          const SizedBox(height: 24),
          GhostButton(
            label: 'VERIFY & ACTIVATE',
            type: GhostButtonType.accent,
            width: double.infinity,
            onPressed: _verifyAndProceed,
          ),
          const SizedBox(height: 14),
          GhostButton(
            label: 'BACK TO SEED',
            type: GhostButtonType.ghost,
            width: double.infinity,
            onPressed: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutQuad,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyView(GhostColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withAlpha(20),
              border: Border.all(color: colors.accent.withAlpha(80), width: 1.5),
            ),
            child: const GhostRoomMark(size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            'IDENTITY READY',
            style: AppTypography.title(context).copyWith(
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your sovereign cryptographic keys are initialized and secured locally on this device.',
            textAlign: TextAlign.center,
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: colors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PUBLIC ID (BASE-58)',
                  style: AppTypography.caption(context).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _publicId ?? 'Deriving...',
                  style: AppTypography.publicId(context, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Text(
                  'CRYPTOGRAPHIC FINGERPRINT',
                  style: AppTypography.caption(context).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _fingerprint ?? 'Calculating...',
                  style: AppTypography.fingerprint(context, fontSize: 11),
                ),
              ],
            ),
          ),
          const Spacer(),
          GhostButton(
            label: 'ENTER GHOSTROOM',
            type: GhostButtonType.accent,
            width: double.infinity,
            onPressed: _completeOnboarding,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Modal Sheet providing dual-unlock recovery (Mnemonic Passphrase OR Encrypted .ghostkey File)
class DualRecoverySheet extends ConsumerStatefulWidget {
  const DualRecoverySheet({super.key});

  @override
  ConsumerState<DualRecoverySheet> createState() => _DualRecoverySheetState();
}

class _DualRecoverySheetState extends ConsumerState<DualRecoverySheet> {
  int _selectedTab = 0; // 0 = Passphrase, 1 = Keyfile
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _keyfilePasswordController = TextEditingController();

  PlatformFile? _pickedKeyfile;
  String? _keyfileContent;
  bool _isUnlocking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passphraseController.dispose();
    _keyfilePasswordController.dispose();
    super.dispose();
  }

  void _pickKeyfile() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (result == null) return;

      String content = '';
      if (result.path != null) {
        content = await File(result.path!).readAsString();
      } else {
        final bytes = await result.readAsBytes();
        content = utf8.decode(bytes);
      }

      setState(() {
        _pickedKeyfile = result;
        _keyfileContent = content;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to read file: $e');
    }
  }

  void _unlockViaPassphrase() async {
    final raw = _passphraseController.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mnemonic seed phrase.');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    try {
      final idService = ref.read(identityServiceProvider);
      await idService.restoreIdentity(raw);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NavigationShell()),
        );
      }
    } catch (e) {
      setState(() {
        _isUnlocking = false;
        _errorMessage = 'Invalid passphrase: ${e.toString().replaceFirst(RegExp(r'^Exception: '), '')}';
      });
    }
  }

  void _unlockViaKeyfile() async {
    if (_keyfileContent == null) {
      setState(() => _errorMessage = 'Please select a .ghostkey file first.');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    try {
      final keyfileService = ref.read(keyfileServiceProvider);
      final idService = ref.read(identityServiceProvider);
      final password = _keyfilePasswordController.text.trim();

      final mnemonic = keyfileService.unlockKeyfile(
        keyfileJson: _keyfileContent!,
        password: password,
      );

      await idService.restoreIdentity(mnemonic);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NavigationShell()),
        );
      }
    } catch (e) {
      setState(() {
        _isUnlocking = false;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colors.hairline),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'RECOVER IDENTITY',
                style: AppTypography.header(context).copyWith(
                  letterSpacing: 1.0,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: colors.textSecondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select your preferred recovery credential to restore your cryptographic keys.',
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 18),

          // Segmented selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedTab = 0;
                      _errorMessage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? colors.surfaceSecondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedTab == 0 ? Border.all(color: colors.hairline) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'PASSPHRASE',
                        style: TextStyle(
                          color: _selectedTab == 0 ? colors.textPrimary : colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedTab = 1;
                      _errorMessage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? colors.surfaceSecondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedTab == 1 ? Border.all(color: colors.hairline) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '.GHOSTKEY FILE',
                        style: TextStyle(
                          color: _selectedTab == 1 ? colors.textPrimary : colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.error.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_selectedTab == 0) ...[
            GhostInput(
              controller: _passphraseController,
              labelText: 'BIP-39 SEED PHRASE',
              hintText: 'Paste or type your 24-word recovery phrase...',
              maxLines: 4,
              isMonospace: true,
            ),
            const SizedBox(height: 20),
            GhostButton(
              label: _isUnlocking ? 'RESTORING IDENTITY...' : 'RESTORE FROM PASSPHRASE',
              type: GhostButtonType.accent,
              width: double.infinity,
              isLoading: _isUnlocking,
              onPressed: _isUnlocking ? null : _unlockViaPassphrase,
            ),
          ] else ...[
            // Keyfile import UI
            GestureDetector(
              onTap: _pickKeyfile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  border: Border.all(
                    color: _pickedKeyfile != null ? colors.accent : colors.hairline,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedKeyfile != null ? Icons.file_present : Icons.file_open_outlined,
                      color: _pickedKeyfile != null ? colors.accent : colors.textMuted,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedKeyfile?.name ?? 'Select .ghostkey file',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickedKeyfile != null
                                ? '${(_pickedKeyfile!.size / 1024).toStringAsFixed(1)} KB • Ready to decrypt'
                                : 'Tap to browse storage for your keyfile',
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GhostInput(
              controller: _keyfilePasswordController,
              labelText: 'KEYFILE PASSWORD / PIN',
              hintText: 'Enter password or PIN set during keyfile export...',
              obscureText: true,
            ),
            const SizedBox(height: 20),
            GhostButton(
              label: _isUnlocking ? 'DECRYPTING & UNLOCKING...' : 'UNLOCK & RESTORE',
              type: GhostButtonType.accent,
              width: double.infinity,
              isLoading: _isUnlocking,
              onPressed: _isUnlocking ? null : _unlockViaKeyfile,
            ),
          ],
        ],
      ),
    );
  }
}
