import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../models/space_model.dart';

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
    }
    return cred;
  }

  // Google Sign-In
  // TODO: Wire up Google Sign In native tokens if configured in Firebase Console
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await auth.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final profile = UserProfile(
            id: user.uid,
            email: user.email ?? '',
            nickname: user.displayName ?? 'Partner',
            avatarUrl: user.photoURL,
            createdAt: DateTime.now().toIso8601String(),
          );
          await saveUserProfile(profile);
        }
      }
      return cred;
    } catch (e) {
      // Keep wired up as was in legacy app
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

  static Future<SpaceModel> createSpace(UserProfile user) async {
    final spaceId = 'space_${DateTime.now().millisecondsSinceEpoch}';
    final pairCode = (spaceId.hashCode.abs() % 900000 + 100000).toString();

    final space = SpaceModel(
      id: spaceId,
      name: 'Our Sanctuary',
      pairCode: pairCode,
      members: [user.id],
      createdAt: DateTime.now().toIso8601String(),
    );

    await firestore.collection('spaces').doc(spaceId).set(space.toJson());
    await firestore.collection('pair_codes').doc(pairCode).set({'spaceId': spaceId});

    // Link user to space
    final updated = user.copyWith(spaceId: spaceId);
    await saveUserProfile(updated);

    return space;
  }

  static Future<SpaceModel?> joinSpace(String pairCode, UserProfile user) async {
    final codeDoc = await firestore.collection('pair_codes').doc(pairCode.trim()).get();
    if (!codeDoc.exists || codeDoc.data() == null) return null;

    final spaceId = codeDoc.data()!['spaceId'] as String?;
    if (spaceId == null) return null;

    final spaceDoc = await firestore.collection('spaces').doc(spaceId).get();
    if (!spaceDoc.exists || spaceDoc.data() == null) return null;

    final existingSpace = SpaceModel.fromJson(spaceDoc.data()!);
    final members = List<String>.from(existingSpace.members);
    if (!members.contains(user.id)) {
      members.add(user.id);
    }

    final updatedSpace = SpaceModel(
      id: existingSpace.id,
      name: existingSpace.name,
      pairCode: existingSpace.pairCode,
      partnerId: members.firstWhere((m) => m != user.id, orElse: () => ''),
      members: members,
      createdAt: existingSpace.createdAt,
    );

    await firestore
        .collection('spaces')
        .doc(spaceId)
        .set(updatedSpace.toJson(), SetOptions(merge: true));

    final updatedUser = user.copyWith(spaceId: spaceId);
    await saveUserProfile(updatedUser);

    return updatedSpace;
  }

  // Feature Documents (Anniversary, Moods, Pinned Notes)
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
}
