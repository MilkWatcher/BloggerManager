import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ProfileListScreen extends StatelessWidget {
  const ProfileListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.profilesStreamForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No profile yet'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['name'] ?? 'No name';
              final bio = data['bio'] ?? '';
              final imageUrl = data['imageUrl'] as String?;

              return ListTile(
                leading: imageUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(imageUrl))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text(bio),
              );
            },
          );
        },
      ),
    );
  }
}
