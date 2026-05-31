import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/widgets/navigation_shell.dart';

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

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _generateIdentity() async {
    setState(() => _isGenerating = true);
    final idService = ref.read(identityServiceProvider);
    
    // Simulate generation time for UX
    await Future.delayed(const Duration(seconds: 2));
    
    final mnemonic = idService.generateNewMnemonic();
    setState(() {
      _mnemonic = mnemonic;
      _isGenerating = false;
    });
    
    // Prepare verification indices (pick 3 random words)
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
      builder: (context) => AlertDialog(
        title: const Text('ENCRYPT BACKUP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Choose a backup password...'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                // We need to restore identity FIRST before we can backup, 
                // but we are in onboarding. Let's use a temporary restore.
                await ref.read(identityServiceProvider).restoreIdentity(_mnemonic!);
                await ref.read(backupServiceProvider).exportBackup(controller.text);
                setState(() => _backupSaved = true);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _completeOnboarding() async {
    // Identity is already restored during backup step or we do it now
    if (!ref.read(identityServiceProvider).hasIdentity) {
       await ref.read(identityServiceProvider).restoreIdentity(_mnemonic!);
    }
    
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NavigationShell()));
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
            _buildGeneration(),
            _buildSecurityWarning(),
            _buildSeedReveal(),
            _buildSeedVerification(),
            _buildInitialBackup(),
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
          const SizedBox(height: 16),
          const Text(
            'Private messaging without\nphone numbers, emails, or accounts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('CREATE IDENTITY'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // TODO: Implement restore identity flow
            },
            child: const Text('RESTORE EXISTING IDENTITY', style: TextStyle(color: Colors.white24)),
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
             ElevatedButton(
               onPressed: _generateIdentity, 
               child: const Text('START GENERATION')
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
            'Your identity belongs\nonly to you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'If you lose your seed phrase and backup file, nobody can recover your messages. Not even us.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.6),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
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
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
            child: const Text('CONTINUE'),
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
          const Text('Confirm a few words to ensure you wrote them down.', style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 48),
          ..._verificationIndices.map((idx) => Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: TextField(
              onChanged: (val) => _verificationAnswers[idx] = val,
              decoration: InputDecoration(
                labelText: 'Word #${idx + 1}',
                border: const OutlineInputBorder(),
              ),
            ),
          )),
          const Spacer(),
          ElevatedButton(
            onPressed: _verifyAndProceed,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
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
            'Save Backup File',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'A backup file makes it easy to move your contacts and settings to a new device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.6),
          ),
          const Spacer(),
          if (!_backupSaved)
            ElevatedButton(
              onPressed: _saveBackup,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
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
                    Text('Backup Saved Successfully', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
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

  Widget _buildSuccess() {
    final publicId = ref.read(identityServiceProvider).currentIdentity?.publicId ?? '...';
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, size: 80, color: Colors.green),
          const SizedBox(height: 32),
          const Text(
            'Identity Ready',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to the GhostRoom network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 48),
          Text(publicId, style: const TextStyle(fontFamily: 'monospace', color: Colors.white30, fontSize: 12)),
          const Spacer(),
          ElevatedButton(
            onPressed: _completeOnboarding,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
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
