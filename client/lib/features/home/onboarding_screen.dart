import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers.dart';

import '../../core/widgets/navigation_shell.dart';
import '../../design_system/colors.dart';
import 'dart:io';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  String? _mnemonic;
  bool _isGenerating = false;
  bool _backupSaved = false;

  final List<int> _verificationIndices = [];
  final Map<int, String> _verificationAnswers = {};

  final List<int> _drillIndices = [];
  final Map<int, String> _drillAnswers = {};

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _generateIdentity() async {
    setState(() => _isGenerating = true);
    final idService = ref.read(identityServiceProvider);
    
    await Future.delayed(const Duration(seconds: 2));
    
    final mnemonic = idService.generateNewMnemonic();
    setState(() {
      _mnemonic = mnemonic;
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

  void _verifyAndProceed() {
    final words = _mnemonic!.split(' ');
    bool allCorrect = true;
    for (final idx in _verificationIndices) {
      if (_verificationAnswers[idx]?.trim().toLowerCase() != words[idx]) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      _nextPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect words. Please check your seed phrase.')));
    }
  }

  void _saveBackup() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ENCRYPT BACKUP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Choose a backup password...'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                final idService = ref.read(identityServiceProvider);
                final backupService = ref.read(backupServiceProvider);

                await idService.restoreIdentity(_mnemonic!);
                await backupService.exportBackup(controller.text);
                
                if (mounted) setState(() => _backupSaved = true);
                
                _drillIndices.clear();
                while (_drillIndices.length < 3) {
                  final idx = (DateTime.now().microsecondsSinceEpoch % 24);
                  if (!_drillIndices.contains(idx) && !_verificationIndices.contains(idx)) {
                    _drillIndices.add(idx);
                  }
                }
                _drillIndices.sort();

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _verifyDrillAndProceed() {
    final words = _mnemonic!.split(' ');
    bool allCorrect = true;
    for (final idx in _drillIndices) {
      if (_drillAnswers[idx]?.trim().toLowerCase() != words[idx]) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      _nextPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drill failed. You must know your seed to proceed.')));
    }
  }

  void _completeOnboarding() async {
    final idService = ref.read(identityServiceProvider);
    if (!idService.hasIdentity) {
       await idService.restoreIdentity(_mnemonic!);
    }
    
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NavigationShell()));
    }
  }

  void _restoreFromSeed() {
    final controller = TextEditingController();
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundSecondary,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('RESTORE FROM SEED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your 24-word seed phrase...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  final idService = ref.read(identityServiceProvider);
                  await idService.restoreIdentity(controller.text.trim());
                  if (mounted) {
                    nav.pop();
                    nav.pushReplacement(MaterialPageRoute(builder: (_) => const NavigationShell()));
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                }
              },
              child: const Text('RESTORE'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _restoreFromBackup() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    
    try {
      final platformFile = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (platformFile == null || platformFile.path == null) return;
      if (!context.mounted) return;

      final fileBytes = await File(platformFile.path!).readAsBytes();
      
      final passController = TextEditingController();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('BACKUP PASSWORD'),
          content: TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Enter your backup password'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            TextButton(
              onPressed: () async {
              try {
                final backupService = ref.read(backupServiceProvider);
                await backupService.importBackup(fileBytes, passController.text);
                if (!context.mounted) return;
                
                Navigator.pop(dialogContext);
                nav.pushReplacement(MaterialPageRoute(builder: (_) => const NavigationShell()));
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Decryption failed: $e')));
                }
              }
            },
              child: const Text('IMPORT'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcome(),
            _buildSovereignty(),
            _buildGeneration(),
            _buildSecurityWarning(),
            _buildSeedReveal(),
            _buildSeedVerification(),
            _buildInitialBackup(),
            _buildRecoveryDrill(),
            _buildSuccess(),
          ],
        ),
      ),
    );
  }

  Widget _makeScrollable({required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }

  Widget _buildWelcome() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF0A0A0A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset('assets/images/banner.png', height: 100),
            ),
            const SizedBox(height: 48),
            const Text(
              'GhostRoom',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 24),
            const Text(
              'No phone number.\nNo email.\nTotal privacy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('GET STARTED'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _restoreFromSeed,
              child: const Text('RESTORE FROM SEED', style: TextStyle(color: Colors.white24, letterSpacing: 1, fontSize: 11)),
            ),
            TextButton(
              onPressed: _restoreFromBackup,
              child: const Text('RESTORE FROM BACKUP', style: TextStyle(color: Colors.white24, letterSpacing: 1, fontSize: 11)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSovereignty() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.key_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 48),
            const Text(
              'Your identity lives\non your device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Only you control your keys.\nOnly you control your data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneration() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isGenerating) ...[
            const CircularProgressIndicator(color: Colors.white24, strokeWidth: 1),
            const SizedBox(height: 32),
            const Text('Generating cryptographic keys...', style: TextStyle(color: Colors.white24)),
          ] else if (_mnemonic == null) ...[
             const Icon(Icons.auto_awesome, size: 64, color: Colors.white10),
             const SizedBox(height: 32),
             const Text('Ready to generate your identity.', style: TextStyle(color: Colors.white70)),
             const SizedBox(height: 48),
             ElevatedButton(
               onPressed: _generateIdentity, 
               style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
               child: const Text('GENERATE')
             ),
          ]
        ],
      ),
    );
  }

  Widget _buildSecurityWarning() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 32),
            const Text(
              'Recovery is your\nresponsibility.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'If you lose your seed phrase and backup file, nobody can recover your identity. There is no "Forgot Password".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              child: const Text('I UNDERSTAND'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedReveal() {
    final words = _mnemonic?.split(' ') ?? [];
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text('RECOVERY SEED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Write these 24 words down in order.', style: TextStyle(color: Colors.white24, fontSize: 12)),
            Column(
              children: [
                for (int r = 0; r < 8; r++) ...[
                  if (r > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int c = 0; c < 3; c++) ...[
                        if (c > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final index = r * 3 + c;
                              if (index >= words.length) return const SizedBox.shrink();
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${index + 1}. ${words[index]}',
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              child: const Text('I HAVE WRITTEN IT DOWN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedVerification() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VERIFY SEED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Confirm a few words to ensure you have them.', style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 48),
            ..._verificationIndices.map((idx) => Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: TextField(
                onChanged: (val) => _verificationAnswers[idx] = val,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Word #${idx + 1}',
                  border: const OutlineInputBorder(),
                ),
              ),
            )),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _verifyAndProceed,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              child: const Text('VERIFY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialBackup() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.backup_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text(
              'Secure Backup',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create an encrypted backup file to migrate your contacts and settings later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 48),
            if (!_backupSaved)
              ElevatedButton(
                onPressed: _saveBackup,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                child: const Text('SAVE ENCRYPTED BACKUP'),
              )
            else
              Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Backup Created', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                    child: const Text('CONTINUE'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (!_backupSaved)
              TextButton(
                onPressed: _nextPage, 
                child: const Text('SKIP FOR NOW', style: TextStyle(color: Colors.white10))
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryDrill() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RECOVERY DRILL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            const Text('Final check. Can you restore your identity?', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 48),
            const Text(
              'Imagine you lost your device. You need your seed phrase now.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 32),
            ..._drillIndices.map((idx) => Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: TextField(
                onChanged: (val) => _drillAnswers[idx] = val,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Word #${idx + 1}',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
            )),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _verifyDrillAndProceed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('FINISH DRILL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return _makeScrollable(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined, size: 80, color: Colors.green),
            const SizedBox(height: 32),
            const Text(
              'Vault Active',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your identity is secured and backed up.\nYou are ready to communicate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('ENTER GHOSTROOM'),
            ),
          ],
        ),
      ),
    );
  }
}
