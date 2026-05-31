import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:bs58/bs58.dart';
import 'dart:convert';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../contacts/contact_service.dart';
import '../../core/crypto/identity_service.dart';

class ContactListScreen extends ConsumerWidget {
  const ContactListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactServiceProvider).getAllContacts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTACTS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _showAddContactOptions(context, ref),
          ),
        ],
      ),
      body: contacts.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Text(contact.alias.isNotEmpty ? contact.alias[0].toUpperCase() : '?'),
                  ),
                  title: Text(contact.alias),
                  subtitle: Text(
                    contact.publicId,
                    style: const TextStyle(fontSize: 10, color: Colors.white24),
                  ),
                  onTap: () => _showContactDetails(context, ref, contact),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyIdentityScreen()),
        ),
        child: const Icon(Icons.qr_code_2),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          const Text('No contacts yet', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showAddContactOptions(context, ref),
            child: const Text('ADD CONTACT'),
          ),
        ],
      ),
    );
  }

  void _showAddContactOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            title: const Text('PASTE PACKAGE'),
            onTap: () {
              Navigator.pop(context);
              _showManualImport(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showManualImport(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT PACKAGE'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Paste Identity Package string...'),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => _importPackage(context, ref, controller.text),
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
  }

  void _importPackage(BuildContext context, WidgetRef ref, String data) async {
    try {
      final pkg = IdentityPackage.fromEncodedString(data);
      final isValid = ref.read(identityServiceProvider).verifyPackage(pkg);
      if (!isValid) throw Exception('Invalid package signature');

      final publicId = base58.encode(ref.read(sodiumProvider).crypto.genericHash(
        message: base64Decode(pkg.eid),
        outLen: 20,
      ));

      final contact = Contact(
        publicId: publicId,
        alias: 'New Contact',
        eid: pkg.eid,
        xid: pkg.xid,
        fingerprint: pkg.eid.substring(0, 8),
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

class MyIdentityScreen extends ConsumerWidget {
  const MyIdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;
    if (identity == null) return const Scaffold(body: Center(child: Text('Loading...')));

    return Scaffold(
      appBar: AppBar(title: const Text('MY IDENTITY')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              FutureBuilder<IdentityPackage>(
                future: ref.read(identityServiceProvider).createPackage([]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final pkgString = snapshot.data!.toEncodedString();
                  return Column(
                    children: [
                      QrImageView(
                        data: pkgString,
                        version: QrVersions.auto,
                        size: 280,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.white,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('YOUR PUBLIC ID', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      SelectableText(identity.publicId, textAlign: TextAlign.center),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              const Text('RECOVERY PHRASE', style: TextStyle(color: Colors.redAccent, fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 16),
              Text(
                identity.mnemonic,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
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
      appBar: AppBar(title: const Text('SCAN IDENTITY')),
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
      final pkg = IdentityPackage.fromEncodedString(data);
      final isValid = ref.read(identityServiceProvider).verifyPackage(pkg);
      if (!isValid) throw Exception('Invalid package signature');

      final publicId = base58.encode(ref.read(sodiumProvider).crypto.genericHash(
        message: base64Decode(pkg.eid),
        outLen: 20,
      ));

      final contact = Contact(
        publicId: publicId,
        alias: 'Scanned Contact',
        eid: pkg.eid,
        xid: pkg.xid,
        fingerprint: pkg.eid.substring(0, 8),
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
      appBar: AppBar(title: const Text('CONTACT DETAILS')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ALIAS', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(contact.alias, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 32),
            Text('PUBLIC ID', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 8),
            SelectableText(contact.publicId),
            const SizedBox(height: 32),
            Text('FINGERPRINT', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(contact.fingerprint, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _deleteContact(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE CONTACT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteContact(BuildContext context, WidgetRef ref) async {
    await ref.read(contactServiceProvider).deleteContact(contact.publicId);
    if (context.mounted) Navigator.pop(context);
  }
}
