import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers.dart';
import '../../core/widgets/navigation_shell.dart';
import 'dart:io';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
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
                await ref.read(identityServiceProvider).restoreIdentity(_mnemonic!);
                await ref.read(backupServiceProvider).exportBackup(controller.text);
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
    if (!ref.read(identityServiceProvider).hasIdentity) {
       await ref.read(identityServiceProvider).restoreIdentity(_mnemonic!);
    }
    
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NavigationShell()));
    }
  }

  void _restoreFromSeed() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
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
                  await ref.read(identityServiceProvider).restoreIdentity(controller.text.trim());
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
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      final fileBytes = await File(result.files.single.path!).readAsBytes();
      
      if (!mounted) return;

      final passController = TextEditingController();
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
                  await ref.read(backupServiceProvider).importBackup(fileBytes, passController.text);
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    nav.pushReplacement(MaterialPageRoute(builder: (_) => const NavigationShell()));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Decryption failed: $e')));
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

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/banner.png', height: 100),
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
          const Spacer(),
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
    );
  }

  Widget _buildSovereignty() {
    return Padding(
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
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
            child: const Text('CONTINUE'),
          ),
        ],
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
    return Padding(
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
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
            child: const Text('I UNDERSTAND'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedReveal() {
    final words = _mnemonic?.split(' ') ?? [];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('RECOVERY SEED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('Write these 24 words down in order.', style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: words.length,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${index + 1}. ${words[index]}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
            child: const Text('I HAVE WRITTEN IT DOWN'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedVerification() {
    return Padding(
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
          const Spacer(),
          ElevatedButton(
            onPressed: _verifyAndProceed,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
            child: const Text('VERIFY'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialBackup() {
    return Padding(
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
          const Spacer(),
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
    );
  }

  Widget _buildRecoveryDrill() {
    return Padding(
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
          const Spacer(),
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
    );
  }

  Widget _buildSuccess() {
    return Padding(
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
          const Spacer(),
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
    );
  }
}
