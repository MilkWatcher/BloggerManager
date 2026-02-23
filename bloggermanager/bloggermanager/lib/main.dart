import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: FirestoreConnectionTestScreen(),
    );
  }
}

class FirestoreConnectionTestScreen extends StatefulWidget {
  const FirestoreConnectionTestScreen({super.key});

  @override
  State<FirestoreConnectionTestScreen> createState() =>
      _FirestoreConnectionTestScreenState();
}

class _FirestoreConnectionTestScreenState
    extends State<FirestoreConnectionTestScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;
  String _status = 'Ready';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _textController.text.trim();
    if (value.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _status = 'Submitting...';
    });

    try {
      final submissionRef =
          FirebaseFirestore.instance.collection('submissions').doc();

      await submissionRef.set({
        'id': submissionRef.id,
        'text': value,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      final savedDoc = await submissionRef.get();
      final savedText = (savedDoc.data()?['text'] ?? '').toString();

      _textController.clear();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = '✅ Saved and read back: "$savedText"';
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final details = error.message == null
          ? error.code
          : '${error.code}: ${error.message}';

      setState(() {
        _status = '❌ $details';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final details = error.toString();

      setState(() {
        _status = '❌ $details';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Connection Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter test text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit to Firestore'),
              ),
            ),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
