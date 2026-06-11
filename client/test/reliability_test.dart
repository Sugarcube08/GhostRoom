import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:sodium/sodium_sumo.dart';
import 'package:ghostroom/features/chat/dm_service.dart';
import 'package:ghostroom/core/crypto/identity_service.dart';
import 'package:ghostroom/features/chat/chat_repository.dart';
import 'package:ghostroom/features/chat/message.dart';
import 'package:ghostroom/features/contacts/contact_service.dart';
import 'package:ghostroom/features/contacts/contact.dart';
import 'package:ghostroom/core/network/websocket_service.dart';
import 'package:ghostroom/core/notification_service.dart';
import 'package:ghostroom/features/media/media_manager.dart';
import 'package:ghostroom/features/media/media_service.dart';
import 'package:ghostroom/core/network/relay_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:hive/hive.dart';

class ManualMockMediaManager implements MediaManager {
  @override
  Future<void> deleteMedia(String mediaId) async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockNotificationService implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> showNotification({required String title, required String body, String? payload}) async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockWebSocketService implements WebSocketService {
  String? lastAckedId;
  @override
  void acknowledgeMessage(String? messageId) => lastAckedId = messageId;
  
  @override
  void onIdentityVerified(Function(dynamic) callback) {}
  @override
  void onMessage(Function(dynamic) callback) {}
  @override
  void onStatusUpdate(Function(dynamic) callback) {}

  @override
  void onInboxMessages(Function(List<dynamic>) callback) {}

  @override
  bool get isConnected => false;
  @override
  bool get isAuthenticated => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockContactService implements ContactService {
  List<Contact> contacts = [];
  @override
  List<Contact> getAllContacts() => contacts;
  @override
  Contact? getContact(String publicId) => contacts.where((c) => c.publicId == publicId).firstOrNull;
  @override
  bool isBlocked(String publicId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockIdentityService implements IdentityService {
  final SodiumSumo _sodium;
  Identity? _identity;
  ManualMockIdentityService(this._sodium);

  @override
  SodiumSumo get sodium => _sodium;
  @override
  Identity? get currentIdentity => _identity;
  void setIdentity(Identity id) => _identity = id;
  @override
  String derivePublicId(Uint8List ed25519PubKey) {
    // In test, we know Bob's key vs Alice's key
    if (_identity != null && listEquals(ed25519PubKey, _identity!.ed25519KeyPair.publicKey)) {
      return _identity!.publicId;
    }
    return 'id-bob'; // Fallback for test sender
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockMediaService implements MediaService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualMockRelayManager implements RelayManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool listEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('ghostroom_test_hive_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Message Reliability: Replay protection and ACK flow', () async {
    final sodium = await SodiumSumoInit.init();
    final dmService = DMService(sodium);
    final idService = ManualMockIdentityService(sodium);
    
    Identity deriveIdentity(String mnemonic, String idSuffix) {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final ed25519Seed = SecureKey.fromList(sodium, seed.sublist(0, 32));
      final ed25519 = sodium.crypto.sign.seedKeyPair(ed25519Seed);
      final sumo = sodium;
      final x25519Pk = sumo.crypto.sign.pkToCurve25519(ed25519.publicKey);
      final x25519Sk = sumo.crypto.sign.skToCurve25519(ed25519.secretKey);
      final x25519 = KeyPair(publicKey: x25519Pk, secretKey: x25519Sk);

      return Identity(
        mnemonic: mnemonic,
        ed25519KeyPair: ed25519,
        x25519KeyPair: x25519,
        publicId: 'id-$idSuffix',
        fingerprint: 'fp-$idSuffix',
        deviceId: 'dev-$idSuffix',
      );
    }

    final aliceIdentity = deriveIdentity(bip39.generateMnemonic(strength: 256), 'alice');
    idService.setIdentity(aliceIdentity);
    
    final bobIdentity = deriveIdentity(bip39.generateMnemonic(strength: 256), 'bob');

    final mockWs = ManualMockWebSocketService();
    final mockContacts = ManualMockContactService();
    final mockNotifications = ManualMockNotificationService();
    final mockMedia = ManualMockMediaManager();
    
    final bobContact = Contact(
      publicId: bobIdentity.publicId,
      alias: 'Bob',
      eid: base64Encode(bobIdentity.ed25519KeyPair.publicKey),
      xid: base64Encode(bobIdentity.x25519KeyPair.publicKey),
      fingerprint: 'fp-bob',
      createdAt: DateTime.now(),
    );
    mockContacts.contacts.add(bobContact);

    final mockMediaService = ManualMockMediaService();
    final mockRelayManager = ManualMockRelayManager();
    final repo = ChatRepository(
      idService, 
      dmService, 
      mockContacts, 
      mockWs, 
      mockNotifications, 
      mockMedia,
      mockMediaService,
      mockRelayManager,
    );
    await repo.init();
    await repo.dangerouslyClearAll();

    // 1. Bob sends to Alice
    final bobToAlicePayload = {
      'type': MessageType.text.name,
      'text': 'Hello Alice, Bob here',
      'sender_eid': base64Encode(bobIdentity.ed25519KeyPair.publicKey),
      'sender_xid': base64Encode(bobIdentity.x25519KeyPair.publicKey),
    };

    final incomingEnvelope = await dmService.encryptDM(
      plaintext: jsonEncode(bobToAlicePayload),
      recipientPublicId: aliceIdentity.publicId,
      recipientXid: aliceIdentity.x25519KeyPair.publicKey,
      senderIdentity: bobIdentity,
    );

    // 2. Process Envelope
    await repo.processEnvelopes([incomingEnvelope.toJson()]);

    final messages = repo.getMessagesForContact(bobIdentity.publicId);
    expect(messages.length, 1);
    expect(messages[0].plaintext, 'Hello Alice, Bob here');
    expect(mockWs.lastAckedId, incomingEnvelope.id);

    // 3. Test Replay Protection
    mockWs.lastAckedId = null;
    await repo.processEnvelopes([incomingEnvelope.toJson()]);
    expect(repo.getMessagesForContact(bobIdentity.publicId).length, 1);
    expect(mockWs.lastAckedId, incomingEnvelope.id); 

    await repo.dangerouslyClearAll();
  });
}
