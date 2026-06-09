import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageDirectoryHelper {
  static Future<Directory> getBaseDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'GhostRoom'));
  }

  static Future<Directory> getHiveDirectory() async {
    final baseDir = await getBaseDirectory();
    return Directory(p.join(baseDir.path, 'hive'));
  }

  static Future<Directory> getIdentitiesDirectory() async {
    final baseDir = await getBaseDirectory();
    return Directory(p.join(baseDir.path, 'identities'));
  }

  static Future<File> getIdentityFlagFile() async {
    final identitiesDir = await getIdentitiesDirectory();
    return File(p.join(identitiesDir.path, 'identity_exists.flag'));
  }

  static Future<Directory> getMediaDirectory() async {
    final baseDir = await getBaseDirectory();
    return Directory(p.join(baseDir.path, 'media'));
  }

  static Future<void> migrateIfNeeded() async {
    if (kIsWeb) return;

    try {
      final oldDocsDir = await getApplicationDocumentsDirectory();
      final newBaseDir = await getBaseDirectory();
      final newHiveDir = await getHiveDirectory();
      final newIdentitiesDir = await getIdentitiesDirectory();

      debugPrint('GHOST_LOG: Checking storage migration from ${oldDocsDir.path} to ${newBaseDir.path}');

      // List of Hive boxes we need to migrate if they exist
      final hiveBoxes = [
        'messages',
        'conversation_states',
        'sync_metadata',
        'processed_envelopes',
        'contacts',
        'blocked_identities',
        'offline_send_queue',
        'pending_deletions',
        'thumbnail_cache',
        'media_cache_index',
      ];

      bool migratedAny = false;

      // 1. Migrate Hive boxes (.hive and .lock files)
      for (final boxName in hiveBoxes) {
        final oldHiveFile = File(p.join(oldDocsDir.path, '$boxName.hive'));
        final oldLockFile = File(p.join(oldDocsDir.path, '$boxName.lock'));

        if (await oldHiveFile.exists()) {
          final newHiveFile = File(p.join(newHiveDir.path, '$boxName.hive'));
          await _moveFile(oldHiveFile, newHiveFile);
          migratedAny = true;
          debugPrint('GHOST_LOG: Migrated Hive box: $boxName.hive');
        }

        if (await oldLockFile.exists()) {
          final newLockFile = File(p.join(newHiveDir.path, '$boxName.lock'));
          await _moveFile(oldLockFile, newLockFile);
          debugPrint('GHOST_LOG: Migrated Hive lock: $boxName.lock');
        }
      }

      // 2. Migrate identity flag file
      final oldFlagFile = File(p.join(oldDocsDir.path, 'identity_exists.flag'));
      if (await oldFlagFile.exists()) {
        final newFlagFile = File(p.join(newIdentitiesDir.path, 'identity_exists.flag'));
        await _moveFile(oldFlagFile, newFlagFile);
        migratedAny = true;
        debugPrint('GHOST_LOG: Migrated identity_exists.flag');
      }

      // 3. Migrate media directory
      final oldMediaDir = Directory(p.join(oldDocsDir.path, 'media'));
      if (await oldMediaDir.exists()) {
        final newMediaDir = Directory(p.join(newBaseDir.path, 'media'));
        await _moveDirectory(oldMediaDir, newMediaDir);
        migratedAny = true;
        debugPrint('GHOST_LOG: Migrated media directory');
      }

      if (migratedAny) {
        debugPrint('GHOST_LOG: Storage migration completed successfully.');
      } else {
        debugPrint('GHOST_LOG: No migration needed.');
      }
    } catch (e, stack) {
      debugPrint('GHOST_LOG: Error during storage migration: $e');
      debugPrint(stack.toString());
    }
  }

  static Future<void> _moveFile(File sourceFile, File targetFile) async {
    if (await sourceFile.exists()) {
      await targetFile.parent.create(recursive: true);
      try {
        await sourceFile.rename(targetFile.path);
      } catch (_) {
        // Fallback for cross-device/partition links
        await sourceFile.copy(targetFile.path);
        await sourceFile.delete();
      }
    }
  }

  static Future<void> _moveDirectory(Directory sourceDir, Directory targetDir) async {
    if (await sourceDir.exists()) {
      await targetDir.create(recursive: true);
      await for (final entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: sourceDir.path);
          final targetPath = p.join(targetDir.path, relativePath);
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);
          try {
            await entity.rename(targetFile.path);
          } catch (_) {
            await entity.copy(targetFile.path);
            await entity.delete();
          }
        }
      }
      try {
        await sourceDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
