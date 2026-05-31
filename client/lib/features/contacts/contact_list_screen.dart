import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';
import '../chat/chat_screens.dart';
import '../chat/conversation_service.dart';

class ContactListScreen extends ConsumerWidget {
  const ContactListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMyPassportCard(context, ref),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Row(
              children: [
                Text(
                  'YOUR CONNECTIONS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? _buildEmptyState(context, ref)
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white.withAlpha(5),
                          child: Text(
                            contact.alias.isNotEmpty ? contact.alias[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        title: Text(contact.alias, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          contact.publicId,
                          style: const TextStyle(fontSize: 10, color: Colors.white10),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white10),
                        onTap: () => _showContactDetails(context, ref, contact),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: () => _showAddOptions(context, ref),
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  Widget _buildMyPassportCard(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;
    if (identity == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPassportScreen())),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
                  const Text('MY IDENTITY PASSPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    identity.publicId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tap to share your QR and Identity Package', style: TextStyle(fontSize: 10, color: Colors.white24)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white10),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diversity_3_outlined, size: 64, color: Colors.white.withAlpha(5)),
          const SizedBox(height: 24),
          const Text(
            'The Social Graph is Local.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'GhostRoom does not store your contacts in the cloud. Exchange identities in person or via secure channels.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('SCAN QR CODE'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('PASTE IDENTITY PACKAGE'),
            onTap: () {
              Navigator.pop(context);
              _showManualImport(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('ENTER PUBLIC ID MANUALLY'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showManualImport(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('IMPORT PACKAGE'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Paste Identity Package string...'),
          maxLines: 4,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              _importPackage(context, ref, controller.text);
            },
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
  }

  void _importPackage(BuildContext context, WidgetRef ref, String data) async {
    try {
      final idService = ref.read(identityServiceProvider);
      final pkg = IdentityPackage.fromEncodedString(data);
      final isValid = idService.verifyPackage(pkg);
      if (!isValid) throw Exception('Invalid package signature');

      final eidBytes = base64Decode(pkg.eid);
      final xidBytes = base64Decode(pkg.xid);
      
      final publicId = idService.derivePublicId(eidBytes);
      final fingerprint = idService.calculateFingerprint(eidBytes, xidBytes);

      final contact = Contact(
        publicId: publicId,
        alias: 'New Contact',
        eid: pkg.eid,
        xid: pkg.xid,
        fingerprint: fingerprint,
        createdAt: DateTime.now(),
        preferredRelay: pkg.relays.isNotEmpty ? pkg.relays.first : null,
      );

      await ref.read(contactServiceProvider).saveContact(contact);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact Added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showContactDetails(BuildContext context, WidgetRef ref, Contact contact) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ContactDetailScreen(contact: contact)));
  }
}

class MyPassportScreen extends ConsumerWidget {
  const MyPassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idService = ref.watch(identityServiceProvider);
    final identity = idService.currentIdentity;
    if (identity == null) return const Scaffold(body: Center(child: Text('Loading...')));

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
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final pkgString = snapshot.data!.toEncodedString();
                  return Column(
                    children: [
                      Container(
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
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Text('PUBLIC ID', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SelectableText(
                        identity.publicId, 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 32),
                      const Text('FINGERPRINT', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        identity.fingerprint, 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 64),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                onPressed: () async {
                   // Placeholder for share
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                ),
                label: const Text('SHARE IDENTITY PACKAGE'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class QRScannerScreen extends ConsumerWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCAN PASSPORT')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              _processScannedData(context, ref, barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }

  void _processScannedData(BuildContext context, WidgetRef ref, String data) async {
    try {
      final idService = ref.read(identityServiceProvider);
      final pkg = IdentityPackage.fromEncodedString(data);
      final isValid = idService.verifyPackage(pkg);
      if (!isValid) throw Exception('Invalid package signature');

      final eidBytes = base64Decode(pkg.eid);
      final xidBytes = base64Decode(pkg.xid);
      
      final publicId = idService.derivePublicId(eidBytes);
      final fingerprint = idService.calculateFingerprint(eidBytes, xidBytes);

      final contact = Contact(
        publicId: publicId,
        alias: 'Scanned Contact',
        eid: pkg.eid,
        xid: pkg.xid,
        fingerprint: fingerprint,
        createdAt: DateTime.now(),
        preferredRelay: pkg.relays.isNotEmpty ? pkg.relays.first : null,
      );

      await ref.read(contactServiceProvider).saveContact(contact);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact Added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ALIAS', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(contact.alias, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            const Text('PUBLIC ID', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableText(contact.publicId, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
            const SizedBox(height: 48),
            const Text('SAFETY NUMBERS', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(12)),
              child: Text(
                contact.fingerprint, 
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1),
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
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ConversationScreen(conversation: conv)),
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
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => _deleteContact(context, ref),
                child: const Text('DELETE CONTACT', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ref.read(contactServiceProvider).updateAlias(contact.publicId, controller.text);
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
