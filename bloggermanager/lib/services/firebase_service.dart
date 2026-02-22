import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads the picked image to Firebase Storage and returns the download URL.
  static Future<String> uploadProfileImage(XFile file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    final ref = _storage.ref().child('profiles').child(fileName);
    final uploadTask = ref.putFile(File(file.path));
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  /// Saves profile data to Firestore in `profiles` collection.
  static Future<void> saveProfile(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    data['createdAt'] = data['createdAt'] ?? now;

    if (user != null) {
      // Save under the user's document (single profile)
      await _firestore.collection('users').doc(user.uid).collection('profiles').doc('profile').set({...data, 'ownerUid': user.uid});

      // Also add to global `profiles` collection for listing (overwrite if exists for the user)
      final query = await _firestore.collection('profiles').where('ownerUid', isEqualTo: user.uid).limit(1).get();
      if (query.docs.isNotEmpty) {
        await _firestore.collection('profiles').doc(query.docs.first.id).set({...data, 'ownerUid': user.uid});
      } else {
        await _firestore.collection('profiles').add({...data, 'ownerUid': user.uid});
      }
    } else {
      // Fallback: save to global collection
      await _firestore.collection('profiles').add(data);
    }
  }

  /// Returns a stream of all profiles for listing.
  static Stream<QuerySnapshot<Map<String, dynamic>>> profilesStream() {
    return _firestore.collection('profiles').orderBy('createdAt', descending: true).snapshots();
  }

  /// Returns a stream of profiles belonging to [uid].
  static Stream<QuerySnapshot<Map<String, dynamic>>> profilesStreamForUser(String uid) {
    return _firestore.collection('profiles').where('ownerUid', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();
  }
}
