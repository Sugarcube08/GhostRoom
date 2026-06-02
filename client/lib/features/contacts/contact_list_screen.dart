import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';
import '../chat/chat_screens.dart';
import '../chat/conversation_service.dart';
import '../settings/identity_actions.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'contact_actions.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with ContactActions, IdentityActions {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Contact>('contacts').listenable(),
      builder: (context, _, _) {
        final contacts = ref.watch(contactServiceProvider).getAllContacts();

        return Scaffold(
          backgroundColor: const Color(0xFF080808),
          appBar: AppBar(
            title: const Text('CONTACTS'),
            backgroundColor: const Color(0xFF080808),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => openScanner(context),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildMyPassportCard(context),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'YOUR CONNECTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white24,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: contacts.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.white.withAlpha(5),
                              child: Text(
                                contact.alias.isNotEmpty
                                    ? contact.alias[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            title: Text(
                              contact.alias,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              contact.publicId,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white10,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.white10,
                            ),
                            onTap: () => _showContactDetails(context, contact),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: () => showAddOptions(context),
            child: const Icon(Icons.person_add_alt_1),
          ),
        );
      },
    );
  }

  Widget _buildMyPassportCard(BuildContext context) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;
    if (identity == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyPassportScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withAlpha(10), Colors.white.withAlpha(5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: identity.publicId,
                version: QrVersions.auto,
                size: 60.0,
                gapless: false,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MY IDENTITY PASSPORT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    identity.publicId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to share your QR and Identity Package',
                    style: TextStyle(fontSize: 10, color: Colors.white24),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.diversity_3_outlined,
              size: 64,
              color: Colors.white.withAlpha(5),
            ),
            const SizedBox(height: 24),
            const Text(
              'The Social Graph is Local.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'GhostRoom does not store your contacts in the cloud. Exchange identities in person or via secure channels.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDetails(BuildContext context, Contact contact) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contact: contact)),
    );
  }
}

class MyPassportScreen extends ConsumerStatefulWidget {
  const MyPassportScreen({super.key});

  @override
  ConsumerState<MyPassportScreen> createState() => _MyPassportScreenState();
}

class _MyPassportScreenState extends ConsumerState<MyPassportScreen> with IdentityActions {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _saveQRToGallery(String publicId) async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        final downloadsDir = Directory('$home/Downloads/GhostRoom');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final file = File('${downloadsDir.path}/ghost_identity_${publicId.substring(0, 8)}.png');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identity saved to: ${file.path}')));
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ghost_identity_${publicId.substring(0, 8)}.png');
        await file.writeAsBytes(bytes);

        await Gal.putImage(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity QR saved to gallery!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save QR: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final idService = ref.watch(identityServiceProvider);
    final identity = idService.currentIdentity;
    if (identity == null) {
      return const Scaffold(body: Center(child: Text('Loading...')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('MY PASSPORT'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              FutureBuilder<IdentityPackage>(
                future: idService.createPackage([]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final pkgString = snapshot.data!.toEncodedString();
                  return Column(
                    children: [
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: QrImageView(
                            data: pkgString,
                            version: QrVersions.auto,
                            size: 260,
                            gapless: false,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        identity.publicId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'YOUR GHOSTROOM IDENTITY',
                        style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.w900),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sharing this passport allows others to connect with you securely. No phone number or email is exposed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        onPressed: () => _saveQRToGallery(identity.publicId),
                        label: const Text('DOWNLOAD PASSPORT'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        onPressed: () => shareIdentity(ref),
                        label: const Text('SHARE IDENTITY LINK'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactDetailScreen extends ConsumerWidget {
  final Contact contact;
  const ContactDetailScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('CONTACT'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRenameDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ALIAS',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                contact.alias,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              const Text(
                'PUBLIC ID',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                contact.publicId,
                style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 48),
              const Text(
                'SAFETY NUMBERS',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  contact.fingerprint,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final conv = Conversation(
                      contact: contact,
                      contactId: contact.publicId,
                      alias: contact.alias,
                      messages: [],
                      lastActivityAt: DateTime.now(),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConversationScreen(conversation: conv),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('OPEN SECURE CHANNEL'),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => _deleteContact(context, ref),
                  child: const Text(
                    'DELETE CONTACT',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: contact.alias);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('RENAME CONTACT'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new alias...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(contactServiceProvider)
                  .updateAlias(contact.publicId, controller.text);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to list to refresh
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _deleteContact(BuildContext context, WidgetRef ref) async {
    await ref.read(contactServiceProvider).deleteContact(contact.publicId);
    if (context.mounted) Navigator.pop(context);
  }
}
