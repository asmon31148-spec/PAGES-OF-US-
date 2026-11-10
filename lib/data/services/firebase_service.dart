import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../models/space_model.dart';
import 'supabase_service.dart';

class PairingException implements Exception {
  final String message;
  const PairingException(this.message);

  @override
  String toString() => message;
}

class FirebaseService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Stream of auth changes
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  // Current Firebase User
  static User? get currentUser => auth.currentUser;

  // Sign In with Email & Password
  static Future<UserCredential> signInWithEmail(String email, String password) async {
    return await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Send Password Reset Email
  static Future<void> sendPasswordResetEmail(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  // Register with Email & Password
  static Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String nickname,
  ) async {
    final cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      final profile = UserProfile(
        id: user.uid,
        email: email.trim(),
        nickname: nickname.trim().isEmpty ? 'Partner' : nickname.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );
      await saveUserProfile(profile);
      // Automatically ensure permanent Sanctuary space & pair code
      await ensureUserSpace(profile);
    }
    return cred;
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Google Sign-In
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Disconnect previous session to allow fresh account selection
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled account picker
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          'Google Sign-In failed: No auth tokens returned from Google Play Services. '
          'Please ensure the app SHA-1 fingerprint is added in Firebase Console.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await auth.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) {
        final existingEmail = user.email ?? '';
        UserProfile? emailProfile;
        if (existingEmail.isNotEmpty) {
          emailProfile = await getUserProfileByEmail(existingEmail);
        }

        final doc = await firestore.collection('users').doc(user.uid).get();
        UserProfile profile;
        if (!doc.exists) {
          final chosenNick = (emailProfile != null && emailProfile.nickname.isNotEmpty && emailProfile.nickname != 'Partner')
              ? emailProfile.nickname
              : ((user.displayName != null && user.displayName!.trim().isNotEmpty)
                  ? user.displayName!.trim()
                  : (existingEmail.contains('@') ? existingEmail.split('@')[0] : 'Partner'));

          final chosenAvatar = (emailProfile != null && emailProfile.avatarUrl != null && emailProfile.avatarUrl!.isNotEmpty)
              ? emailProfile.avatarUrl
              : user.photoURL;

          final chosenThought = emailProfile?.thought;
          final chosenSpaceId = emailProfile?.spaceId;

          profile = UserProfile(
            id: user.uid,
            email: existingEmail,
            nickname: chosenNick,
            avatarUrl: chosenAvatar,
            thought: chosenThought,
            spaceId: chosenSpaceId,
            createdAt: emailProfile?.createdAt ?? DateTime.now().toIso8601String(),
          );
          await saveUserProfile(profile);
        } else {
          final data = doc.data()!;
          final existingNick = data['nickname'] as String?;
          final existingAvatar = data['avatarUrl'] as String? ?? data['avatar_url'] as String?;
          final existingThought = data['thought'] as String?;
          final existingSpaceId = data['spaceId'] as String? ?? data['space_id'] as String?;

          final cleanNick = (existingNick != null && existingNick.trim().isNotEmpty && existingNick.trim() != 'Partner')
              ? existingNick.trim()
              : ((emailProfile != null && emailProfile.nickname.isNotEmpty && emailProfile.nickname != 'Partner')
                  ? emailProfile.nickname
                  : ((user.displayName != null && user.displayName!.trim().isNotEmpty)
                      ? user.displayName!.trim()
                      : (existingEmail.contains('@') ? existingEmail.split('@')[0] : 'Partner')));

          final cleanAvatar = (existingAvatar != null && existingAvatar.trim().isNotEmpty)
              ? existingAvatar
              : ((emailProfile != null && emailProfile.avatarUrl != null && emailProfile.avatarUrl!.isNotEmpty)
                  ? emailProfile.avatarUrl
                  : user.photoURL);

          final cleanThought = (existingThought != null && existingThought.trim().isNotEmpty)
              ? existingThought
              : emailProfile?.thought;

          final cleanSpaceId = (existingSpaceId != null && existingSpaceId.isNotEmpty)
              ? existingSpaceId
              : emailProfile?.spaceId;

          profile = UserProfile.fromJson({
            ...data,
            'id': user.uid,
            'nickname': cleanNick,
            'avatarUrl': cleanAvatar,
            'thought': cleanThought,
            'spaceId': cleanSpaceId,
            'email': existingEmail.isNotEmpty ? existingEmail : (data['email'] ?? ''),
          });
          await saveUserProfile(profile);
        }
        // Automatically ensure permanent Sanctuary space & pair code
        await ensureUserSpace(profile);
      }
      return cred;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR') ||
          msg.contains('10:')) {
        throw Exception(
          'Google Sign-In (Code 10): App SHA-1 fingerprint is not registered in Firebase Console. Please register your SHA-1 in Firebase Console -> Project Settings -> Your Android Apps.',
        );
      } else if (msg.contains('ApiException: 12500')) {
        throw Exception(
          'Google Sign-In (Code 12500): Please ensure Google sign-in is enabled in Firebase Console -> Authentication -> Sign-in method.',
        );
      } else if (msg.contains('network_error') || msg.contains('ApiException: 7')) {
        throw Exception(
          'Network error during Google Sign-In. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  // Sign Out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await auth.signOut();
  }

  // User Profile
  static Future<UserProfile?> getUserProfile(String uid) async {
    Map<String, dynamic>? data;
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        data = Map<String, dynamic>.from(doc.data()!);
      }
    } catch (e) {
      debugPrint('[FirebaseService] getUserProfile firestore note: $e');
    }

    // Fallback or augment with Supabase app_content
    try {
      final supaContent = await SupabaseService.getAppContent('user_profile_$uid');
      if (supaContent != null) {
        data = data == null ? supaContent : {...supaContent, ...data};
      }
    } catch (_) {}

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile?> getUserProfileByEmail(String email) async {
    if (email.trim().isEmpty) return null;
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check Supabase app_content by email
    try {
      final supaContent = await SupabaseService.getAppContent('user_profile_$cleanEmail');
      if (supaContent != null) {
        return UserProfile.fromJson(supaContent);
      }
    } catch (_) {}

    // 2. Check Firestore by email
    try {
      final q = await firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        return UserProfile.fromJson(q.docs.first.data());
      }
    } catch (_) {}

    return null;
  }

  static Stream<UserProfile?> streamUserProfile(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromJson(doc.data()!);
    });
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await firestore
          .collection('users')
          .doc(profile.id)
          .set(profile.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseService] saveUserProfile firestore note: $e');
    }

    // Dual-persist to Supabase app_content for resilient re-login recovery
    try {
      await SupabaseService.upsertAppContent('user_profile_${profile.id}', profile.toJson());
      if (profile.email.isNotEmpty) {
        await SupabaseService.upsertAppContent('user_profile_${profile.email.trim().toLowerCase()}', profile.toJson());
      }
    } catch (e) {
      debugPrint('[FirebaseService] saveUserProfile supabase note: $e');
    }
  }

  // Space
  static Future<SpaceModel?> getSpace(String spaceId) async {
    final doc = await firestore.collection('spaces').doc(spaceId).get();
    if (!doc.exists || doc.data() == null) return null;
    return SpaceModel.fromJson(doc.data()!);
  }

  static Future<String> _generateUniquePairCode() async {
    final rng = math.Random.secure();
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = (rng.nextInt(900000) + 100000).toString();
      try {
        final doc = await firestore.collection('pair_codes').doc(code).get();
        if (!doc.exists) {
          return code;
        }
      } catch (_) {
        return code;
      }
    }
    return (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
  }

  static Future<SpaceModel> ensureUserSpace(UserProfile user) async {
    final effectiveUid = user.id.isNotEmpty ? user.id : (auth.currentUser?.uid ?? '');
    if (effectiveUid.isEmpty) {
      throw const PairingException('User is not authenticated.');
    }

    // 1. If user already has spaceId, check if it exists in Firestore
    if (user.spaceId != null && user.spaceId!.isNotEmpty) {
      try {
        final existing = await getSpace(user.spaceId!);
        if (existing != null) {
          // Verify pair_codes collection mapping; repair if missing
          if (existing.pairCode.isNotEmpty) {
            try {
              final codeDoc = await firestore.collection('pair_codes').doc(existing.pairCode).get();
              if (!codeDoc.exists) {
                await firestore.collection('pair_codes').doc(existing.pairCode).set({
                  'spaceId': existing.id,
                  'space_id': existing.id,
                  'creatorId': effectiveUid,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
            } catch (_) {}
          }
          return existing;
        }
      } catch (e) {
        debugPrint('Error fetching existing space: $e');
      }
    }

    // 2. Check if an existing space has this user in members
    try {
      final query = await firestore
          .collection('spaces')
          .where('members', arrayContains: effectiveUid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final found = SpaceModel.fromJson(query.docs.first.data());
        // Link user profile to this space
        await firestore.collection('users').doc(effectiveUid).set({
          'spaceId': found.id,
          'space_id': found.id,
        }, SetOptions(merge: true));
        return found;
      }
    } catch (_) {}

    // 3. Create fresh permanent sanctuary space
    return await createSpace(user);
  }

  static Future<SpaceModel> createSpace(UserProfile user) async {
    final effectiveUid = user.id.isNotEmpty ? user.id : (auth.currentUser?.uid ?? '');
    if (effectiveUid.isEmpty) {
      throw const PairingException('User is not authenticated.');
    }

    final spaceId = 'space_${DateTime.now().millisecondsSinceEpoch}';
    final pairCode = await _generateUniquePairCode();

    final space = SpaceModel(
      id: spaceId,
      name: 'Our Sanctuary',
      pairCode: pairCode,
      members: [effectiveUid],
      createdAt: DateTime.now().toIso8601String(),
    );

    // Save space
    await firestore.collection('spaces').doc(spaceId).set(space.toJson());

    // Map pair code
    await firestore.collection('pair_codes').doc(pairCode).set({
      'spaceId': spaceId,
      'space_id': spaceId,
      'creatorId': effectiveUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Link user to space
    await firestore.collection('users').doc(effectiveUid).set({
      'spaceId': spaceId,
      'space_id': spaceId,
    }, SetOptions(merge: true));

    return space;
  }

  static Future<SpaceModel> joinSpace(String rawCode, UserProfile user) async {
    final cleanCode = rawCode.trim().replaceAll(RegExp(r'[\s\-_]'), '').toUpperCase();
    if (cleanCode.isEmpty) {
      throw const PairingException('Please enter a valid 6-digit pair code.');
    }

    final currentUid = user.id.isNotEmpty ? user.id : (auth.currentUser?.uid ?? '');
    if (currentUid.isEmpty) {
      throw const PairingException('You must be signed in to connect.');
    }

    // 1. Resolve pairCode -> spaceId
    String? targetSpaceId;
    try {
      final codeDoc = await firestore.collection('pair_codes').doc(cleanCode).get();
      if (codeDoc.exists && codeDoc.data() != null) {
        targetSpaceId = codeDoc.data()!['spaceId'] as String? ?? codeDoc.data()!['space_id'] as String?;
      }
    } catch (e) {
      debugPrint('Error reading pair_codes doc: $e');
    }

    // Fallback: search spaces directly by pairCode or pair_code
    if (targetSpaceId == null || targetSpaceId.isEmpty) {
      try {
        final q1 = await firestore
            .collection('spaces')
            .where('pairCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (q1.docs.isNotEmpty) {
          targetSpaceId = q1.docs.first.id;
        } else {
          final q2 = await firestore
              .collection('spaces')
              .where('pair_code', isEqualTo: cleanCode)
              .limit(1)
              .get();
          if (q2.docs.isNotEmpty) {
            targetSpaceId = q2.docs.first.id;
          }
        }

        // Repair pair_codes mapping
        if (targetSpaceId != null && targetSpaceId.isNotEmpty) {
          await firestore.collection('pair_codes').doc(cleanCode).set({
            'spaceId': targetSpaceId,
            'space_id': targetSpaceId,
            'repairedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Fallback space lookup error: $e');
      }
    }

    if (targetSpaceId == null || targetSpaceId.isEmpty) {
      throw PairingException('Invalid pair code. No sanctuary found with code "$cleanCode". Please verify with your partner.');
    }

    // 2. Fetch the target space
    final spaceDoc = await firestore.collection('spaces').doc(targetSpaceId).get();
    if (!spaceDoc.exists || spaceDoc.data() == null) {
      throw const PairingException('Sanctuary space data not found. Please try again.');
    }

    final existingSpace = SpaceModel.fromJson(spaceDoc.data()!);

    // Check if trying to pair with own code
    if (existingSpace.members.contains(currentUid) && existingSpace.members.length == 1) {
      throw const PairingException('That is your own invite code! Share this code with your partner so they can connect with you.');
    }

    // If already paired to this exact space with partner
    if (existingSpace.members.contains(currentUid) && existingSpace.members.length > 1) {
      return existingSpace;
    }

    // Check if space is already full with 2 other members
    if (existingSpace.members.length >= 2 && !existingSpace.members.contains(currentUid)) {
      throw const PairingException('This sanctuary is already shared by two partners.');
    }

    // 3. Add current user to space members
    final updatedMembers = List<String>.from(existingSpace.members);
    if (!updatedMembers.contains(currentUid)) {
      updatedMembers.add(currentUid);
    }

    final partnerUid = updatedMembers.firstWhere((id) => id != currentUid, orElse: () => '');

    final updatedSpace = SpaceModel(
      id: targetSpaceId,
      name: existingSpace.name.isNotEmpty ? existingSpace.name : 'Our Sanctuary',
      pairCode: existingSpace.pairCode,
      partnerId: partnerUid,
      members: updatedMembers,
      createdAt: existingSpace.createdAt,
    );

    // Save updated space
    await firestore.collection('spaces').doc(targetSpaceId).set({
      'id': targetSpaceId,
      'members': updatedMembers,
      'partnerId': partnerUid,
      'partner_id': partnerUid,
      'lastPairedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update current user's profile
    await firestore.collection('users').doc(currentUid).set({
      'spaceId': targetSpaceId,
      'space_id': targetSpaceId,
      'partnerId': partnerUid,
      'partner_id': partnerUid,
    }, SetOptions(merge: true));

    // Update partner's profile
    if (partnerUid.isNotEmpty) {
      await firestore.collection('users').doc(partnerUid).set({
        'spaceId': targetSpaceId,
        'space_id': targetSpaceId,
        'partnerId': currentUid,
        'partner_id': currentUid,
      }, SetOptions(merge: true));
    }

    // Bi-directional code redirect: If current user had an old solo space code, redirect it to targetSpaceId
    if (user.spaceId != null && user.spaceId!.isNotEmpty && user.spaceId != targetSpaceId) {
      // Migrate all memories, vaults, places, goals, prompts seamlessly to targetSpaceId
      await migrateSpaceData(
        oldSpaceId: user.spaceId!,
        targetSpaceId: targetSpaceId,
      );

      try {
        final oldSpaceDoc = await firestore.collection('spaces').doc(user.spaceId!).get();
        if (oldSpaceDoc.exists) {
          final oldCode = oldSpaceDoc.data()?['pairCode'] ?? oldSpaceDoc.data()?['pair_code'];
          if (oldCode != null && oldCode.toString().isNotEmpty) {
            await firestore.collection('pair_codes').doc(oldCode.toString()).set({
              'spaceId': targetSpaceId,
              'space_id': targetSpaceId,
              'redirectedTo': targetSpaceId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      } catch (_) {}
    }

    return updatedSpace;
  }

  static Future<void> _mergeAppContentList({
    required dynamic client,
    required String oldId,
    required String targetId,
    String? wrapperKey,
  }) async {
    try {
      final oldRow = await client.from('app_content').select('content').eq('id', oldId).maybeSingle();
      if (oldRow == null || oldRow['content'] == null) return;

      List<dynamic> extractList(dynamic content) {
        if (wrapperKey == null && content is List) return List<dynamic>.from(content);
        if (wrapperKey != null && content is Map && content[wrapperKey] is List) {
          return List<dynamic>.from(content[wrapperKey] as List);
        }
        return [];
      }

      final oldList = extractList(oldRow['content']);
      if (oldList.isEmpty) return;

      final targetRow = await client.from('app_content').select('content').eq('id', targetId).maybeSingle();
      final merged = extractList(targetRow?['content']);
      for (final item in oldList) {
        if (item is Map && item['id'] != null) {
          if (!merged.any((m) => m is Map && m['id'] == item['id'])) {
            merged.add(item);
          }
        } else if (!merged.contains(item)) {
          merged.add(item);
        }
      }

      final payload = wrapperKey == null
          ? merged
          : {wrapperKey: merged, 'updated_at': DateTime.now().toIso8601String()};
      await client.from('app_content').upsert({
        'id': targetId,
        'content': payload,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Migrates and merges ALL content (memories, letters, milestones, vaults, notes,
  /// prompts, care, goals, playlists, places) from oldSpaceId into targetSpaceId.
  static Future<void> migrateSpaceData({
    required String oldSpaceId,
    required String targetSpaceId,
  }) async {
    if (oldSpaceId.isEmpty || targetSpaceId.isEmpty || oldSpaceId == targetSpaceId) return;
    try {
      // 1. Migrate Firestore Milestones subcollection -> targetSpaceId
      try {
        final oldMlsSnap = await firestore.collection('spaces').doc(oldSpaceId).collection('milestones').get();
        for (final doc in oldMlsSnap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['space_id'] = targetSpaceId;
          await firestore.collection('spaces').doc(targetSpaceId).collection('milestones').doc(doc.id).set(data, SetOptions(merge: true));
        }
      } catch (_) {}

      final client = SupabaseService.client;
      if (client != null) {
        // 2. Migrate SQL tables: memories, letters, milestones
        for (final table in ['memories', 'letters', 'milestones']) {
          try {
            await client.from(table).update({'space_id': targetSpaceId}).eq('space_id', oldSpaceId);
          } catch (_) {}
        }

        // 3. Merge array-based app_content collections
        await _mergeAppContentList(client: client, oldId: 'vaults_$oldSpaceId', targetId: 'vaults_$targetSpaceId');
        await _mergeAppContentList(client: client, oldId: 'places_$oldSpaceId', targetId: 'places_$targetSpaceId');
        await _mergeAppContentList(client: client, oldId: 'couple_goals_$oldSpaceId', targetId: 'couple_goals_$targetSpaceId');
        await _mergeAppContentList(client: client, oldId: 'daily_care_$oldSpaceId', targetId: 'daily_care_$targetSpaceId');
        await _mergeAppContentList(client: client, oldId: 'bucket_list_$oldSpaceId', targetId: 'bucket_list_$targetSpaceId', wrapperKey: 'items');
        await _mergeAppContentList(client: client, oldId: 'playlists_$oldSpaceId', targetId: 'playlists_$targetSpaceId', wrapperKey: 'playlists');
        await _mergeAppContentList(client: client, oldId: 'music_$oldSpaceId', targetId: 'music_$targetSpaceId', wrapperKey: 'songs');
        await _mergeAppContentList(client: client, oldId: 'favorite_songs_$oldSpaceId', targetId: 'favorite_songs_$targetSpaceId', wrapperKey: 'favorites');

        // 4. Merge Pinned Notes map
        try {
          final oldNotesRow = await client.from('app_content').select('content').eq('id', 'pinned_notes_$oldSpaceId').maybeSingle();
          if (oldNotesRow != null && oldNotesRow['content'] is Map) {
            final targetNotesRow = await client.from('app_content').select('content').eq('id', 'pinned_notes_$targetSpaceId').maybeSingle();
            final targetNotes = <String, dynamic>{};
            if (targetNotesRow != null && targetNotesRow['content'] is Map) {
              final raw = Map<String, dynamic>.from(targetNotesRow['content'] as Map);
              final inner = raw['notes'] is Map ? Map<String, dynamic>.from(raw['notes'] as Map) : raw;
              targetNotes.addAll(inner);
            }
            final oldRaw = Map<String, dynamic>.from(oldNotesRow['content'] as Map);
            final oldInner = oldRaw['notes'] is Map ? Map<String, dynamic>.from(oldRaw['notes'] as Map) : oldRaw;
            oldInner.forEach((k, v) {
              if (k != 'updatedAt' && k != 'updated_at' && !targetNotes.containsKey(k)) {
                targetNotes[k] = v;
                if (v is Map) {
                  saveUserFeatureField(targetSpaceId, 'pinned_note', k, Map<String, dynamic>.from(v));
                }
              }
            });
            await client.from('app_content').upsert({
              'id': 'pinned_notes_$targetSpaceId',
              'content': {'notes': targetNotes, 'updated_at': DateTime.now().toIso8601String()},
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (_) {}

        // 5. Merge Daily Prompt answers & Location
        try {
          final oldPrompt = await client.from('app_content').select('content').eq('id', 'daily_prompt_$oldSpaceId').maybeSingle();
          if (oldPrompt != null && oldPrompt['content'] is Map) {
            final targetPrompt = await client.from('app_content').select('content').eq('id', 'daily_prompt_$targetSpaceId').maybeSingle();
            if (targetPrompt == null || targetPrompt['content'] == null) {
              await client.from('app_content').upsert({
                'id': 'daily_prompt_$targetSpaceId',
                'content': oldPrompt['content'],
                'updated_at': DateTime.now().toIso8601String(),
              });
            } else if (targetPrompt['content'] is Map) {
              final tMap = Map<String, dynamic>.from(targetPrompt['content'] as Map);
              final oMap = Map<String, dynamic>.from(oldPrompt['content'] as Map);
              if (tMap['id'] == oMap['id'] && oMap['answers'] is Map) {
                final mergedAns = Map<String, dynamic>.from(tMap['answers'] as Map? ?? {});
                (oMap['answers'] as Map).forEach((k, v) {
                  if (!mergedAns.containsKey(k) || (mergedAns[k]?.toString().isEmpty ?? true)) {
                    mergedAns[k.toString()] = v;
                  }
                });
                tMap['answers'] = mergedAns;
                await client.from('app_content').upsert({
                  'id': 'daily_prompt_$targetSpaceId',
                  'content': tMap,
                  'updated_at': DateTime.now().toIso8601String(),
                });
              }
            }
          }
        } catch (_) {}

        try {
          final oldLoc = await client.from('app_content').select('content').eq('id', 'location_$oldSpaceId').maybeSingle();
          if (oldLoc != null && oldLoc['content'] is Map) {
            final targetLoc = await client.from('app_content').select('content').eq('id', 'location_$targetSpaceId').maybeSingle();
            final merged = <String, dynamic>{
              ...Map<String, dynamic>.from(oldLoc['content'] as Map),
              if (targetLoc != null && targetLoc['content'] is Map)
                ...Map<String, dynamic>.from(targetLoc['content'] as Map),
            };
            await client.from('app_content').upsert({
              'id': 'location_$targetSpaceId',
              'content': merged,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error migrating space data: $e');
    }
  }

  static Future<SpaceModel> disconnectPartner({
    required UserProfile currentUser,
    required SpaceModel currentSpace,
  }) async {
    final effectiveUid = currentUser.id.isNotEmpty ? currentUser.id : (auth.currentUser?.uid ?? '');

    // 1. Remove currentUser from currentSpace.members in Firestore
    final remainingMembers = currentSpace.members.where((id) => id != effectiveUid).toList();
    final updatedCurrentSpace = SpaceModel(
      id: currentSpace.id,
      name: currentSpace.name,
      pairCode: currentSpace.pairCode,
      partnerId: '',
      members: remainingMembers,
      createdAt: currentSpace.createdAt,
    );
    await firestore
        .collection('spaces')
        .doc(currentSpace.id)
        .set(updatedCurrentSpace.toJson(), SetOptions(merge: true));

    // 2. Create a fresh personal sanctuary space for currentUser
    final newSpaceId = 'space_${DateTime.now().millisecondsSinceEpoch}';
    final newPairCode = await _generateUniquePairCode();
    final newSpace = SpaceModel(
      id: newSpaceId,
      name: 'Our Sanctuary',
      pairCode: newPairCode,
      members: [effectiveUid],
      createdAt: DateTime.now().toIso8601String(),
    );

    await firestore.collection('spaces').doc(newSpaceId).set(newSpace.toJson());
    await firestore.collection('pair_codes').doc(newPairCode).set({
      'spaceId': newSpaceId,
      'space_id': newSpaceId,
      'creatorId': effectiveUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Update currentUser's spaceId to the new space and clear partnerId
    await firestore.collection('users').doc(effectiveUid).set({
      'spaceId': newSpaceId,
      'space_id': newSpaceId,
      'partnerId': null,
      'partner_id': null,
    }, SetOptions(merge: true));

    // 4. Clear partnerId on remaining members (ex-partner)
    for (final memberId in remainingMembers) {
      try {
        await firestore.collection('users').doc(memberId).set({
          'partnerId': null,
          'partner_id': null,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    return newSpace;
  }

  // Feature Documents (Anniversary, Moods, Pinned Notes)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamSpace(String spaceId) {
    return firestore.collection('spaces').doc(spaceId).snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamFeatureDoc(
    String spaceId,
    String featureName,
  ) {
    return firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('features')
        .doc(featureName)
        .snapshots();
  }

  static Future<void> saveFeatureDoc(
    String spaceId,
    String featureName,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('features')
        .doc(featureName)
        .set(data, SetOptions(merge: merge));
  }

  /// Saves a feature field partitioned by userId so neither partner ever overwrites the other
  static Future<void> saveUserFeatureField(
    String spaceId,
    String featureName,
    String userId,
    Map<String, dynamic> data,
  ) async {
    final docRef = firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('features')
        .doc(featureName);

    try {
      await docRef.update({
        userId: data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await docRef.set({
        userId: data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Updates a nested map key (e.g. 'answers.$userId', 'locations.$userId', or 'touches.$userId') safely
  static Future<void> saveNestedFeatureField(
    String spaceId,
    String featureName,
    String fieldPath,
    dynamic value, {
    Map<String, dynamic>? rootDefaults,
  }) async {
    final docRef = firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('features')
        .doc(featureName);

    try {
      if (fieldPath.contains('.')) {
        final parts = fieldPath.split('.');
        final parent = parts[0];
        final child = parts.sublist(1).join('.');
        await docRef.set({
          parent: {child: value},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          fieldPath: value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      try {
        await docRef.update({
          fieldPath: value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }
}
