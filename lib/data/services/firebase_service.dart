import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../models/space_model.dart';

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
        final doc = await firestore.collection('users').doc(user.uid).get();
        UserProfile profile;
        if (!doc.exists) {
          profile = UserProfile(
            id: user.uid,
            email: user.email ?? '',
            nickname: (user.displayName != null && user.displayName!.trim().isNotEmpty)
                ? user.displayName!.trim()
                : (user.email != null && user.email!.contains('@')
                    ? user.email!.split('@')[0]
                    : 'Partner'),
            avatarUrl: user.photoURL,
            createdAt: DateTime.now().toIso8601String(),
          );
          await saveUserProfile(profile);
        } else {
          profile = UserProfile.fromJson(doc.data()!);
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
    await auth.signOut();
  }

  // User Profile
  static Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    await firestore
        .collection('users')
        .doc(profile.id)
        .set(profile.toJson(), SetOptions(merge: true));
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
    }, SetOptions(merge: true));

    // Update partner's profile
    if (partnerUid.isNotEmpty) {
      await firestore.collection('users').doc(partnerUid).set({
        'spaceId': targetSpaceId,
        'space_id': targetSpaceId,
      }, SetOptions(merge: true));
    }

    // Bi-directional code redirect: If current user had an old solo space code, redirect it to targetSpaceId
    if (user.spaceId != null && user.spaceId!.isNotEmpty && user.spaceId != targetSpaceId) {
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

    // 3. Update currentUser's spaceId to the new space
    await firestore.collection('users').doc(effectiveUid).set({
      'spaceId': newSpaceId,
      'space_id': newSpaceId,
    }, SetOptions(merge: true));

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
    Map<String, dynamic> data,
  ) async {
    await firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('features')
        .doc(featureName)
        .set(data, SetOptions(merge: true));
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
