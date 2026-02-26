import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'firebase_options.dart';
import 'models/blogger_user.dart';
import 'screens/edit_blogger_profile_screen.dart';
import 'screens/home_blog_search_screen.dart';
import 'screens/upload_blog_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  developer.log('Firebase projectId: ${app.options.projectId}', name: 'app.startup');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blogger Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('users').doc(snapshot.data!.uid).snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
            ) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final Map<String, dynamic>? userData = userSnapshot.data?.data();
              final bool profileSetupCompleted =
                  userData?['profileSetupCompleted'] as bool? ?? false;

              if (profileSetupCompleted) {
                return ProfileDashboardScreen(user: snapshot.data!);
              }

              return CompleteProfileScreen(user: snapshot.data!);
            },
          );
        }

        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  bool _isLoginMode = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in email and password.')),
      );
      return;
    }

    if (!_isLoginMode && confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm your password.')),
      );
      return;
    }

    if (!_isLoginMode && confirmPassword != password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      late final UserCredential credential;
      if (_isLoginMode) {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final User? user = credential.user;
      if (user == null) {
        throw Exception('Authentication returned no user.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': user.displayName ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!_isLoginMode) 'createdAt': FieldValue.serverTimestamp(),
        if (!_isLoginMode) 'verificationStatus': 'Approved',
        if (!_isLoginMode) 'profileSetupCompleted': false,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      if (!_isLoginMode) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CompleteProfileScreen(user: user),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLoginMode
                ? 'Logged in and synced to Firestore.'
                : 'Account created and saved to Firestore.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $error')),
      );
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
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Login to Blogger Manager' : 'Join Blogger Manager'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!_isLoginMode) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAuth,
                  child: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : (_isLoginMode ? 'Login' : 'Sign Up'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                child: Text(
                  _isLoginMode
                      ? 'Need an account? Sign Up'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({required this.user, super.key});

  final User user;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _domainLinkController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final List<String> _availableTags = [
    'Politics',
    'Food',
    'Cats',
    'Travel',
    'Technology',
    'Business',
    'Lifestyle',
    'Sports',
    'Health',
    'Entertainment',
    'Education',
    'DIY',
    'Fashion',
    'Photography',
    'Music',
  ];
  final List<String> _selectedTags = [];

  Uint8List? _profileImageBytes;
  GeoPoint? _currentLocation;
  String? _city;
  String? _county;
  String? _country;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _domainLinkController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 500000) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image under 500KB.')),
        );
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _approveLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location services first.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String? city;
      String? county;
      String? country;
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final Placemark placemark = placemarks.first;
          city = placemark.locality;
          county = placemark.administrativeArea;
          country = placemark.country;
        }
      } catch (_) {
        city = null;
        county = null;
        country = null;
      }

      await _firestore.collection('users').doc(widget.user.uid).set({
        'location': GeoPoint(position.latitude, position.longitude),
        'city': city,
        'county': county,
        'country': country,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
        _city = city;
        _county = county;
        _country = country;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location approved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to approve location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _completeProfile() async {
    final String displayName = _displayNameController.text.trim();
    final String domainLink = _domainLinkController.text.trim();
    final String bio = _bioController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name.')),
      );
      return;
    }

    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one main content tag.')),
      );
      return;
    }

    if (domainLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your blog domain link.')),
      );
      return;
    }

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please approve geolocation before continuing.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String? profileImageBase64 =
          _profileImageBytes == null ? null : base64Encode(_profileImageBytes!);

      await _firestore.collection('users').doc(widget.user.uid).set({
        'displayName': displayName,
        'domainLink': domainLink,
        'profileDetails': bio.isEmpty ? null : bio,
        'tags': _selectedTags,
        'location': _currentLocation,
        'city': _city,
        'county': _county,
        'country': _country,
        'profileImageBase64': profileImageBase64,
        'profileSetupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await widget.user.updateDisplayName(displayName);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProfileDashboardScreen(
            user: widget.user,
            initialUserLocation: _currentLocation,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete profile: $error')),
      );
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
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage:
                    _profileImageBytes == null ? null : MemoryImage(_profileImageBytes!),
                child: _profileImageBytes == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isPickingImage || _isSubmitting)
                    ? null
                    : _pickProfileImage,
                icon: const Icon(Icons.upload),
                label: Text(
                  _isPickingImage ? 'Uploading...' : 'Upload Profile Picture',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _domainLinkController,
              decoration: const InputDecoration(
                labelText: 'Blog Domain Link',
                helperText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio / Profile Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Main Content Tags',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((String tag) {
                final bool isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Geolocation Approval',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow location access so we can support geographic discovery.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSubmitting || _isFetchingLocation)
                    ? null
                    : _approveLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _isFetchingLocation ? 'Approving Location...' : 'Approve Geolocation',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentLocation == null
                  ? 'Location not approved yet.'
                  : 'Approved: ${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _completeProfile,
                child: Text(
                  _isSubmitting ? 'Saving Profile...' : 'Finish Setup',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileDashboardScreen extends StatefulWidget {
  const ProfileDashboardScreen({
    required this.user,
    this.initialUserLocation,
    super.key,
  });

  final User user;
  final GeoPoint? initialUserLocation;

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  final List<String> _availableTags = [
    'Politics',
    'Food',
    'Cats',
    'Travel',
    'Technology',
    'Business',
    'Lifestyle',
    'Sports',
    'Health',
    'Entertainment',
    'Education',
    'DIY',
    'Fashion',
    'Photography',
    'Music',
  ];
  final List<String> _selectedTags = [];
  bool _isSavingProfile = false;
  bool _hasSeededProfile = false;
  int _selectedIndex = 0;
  GeoPoint? _currentUserLocation;

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.initialUserLocation;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSavingProfile = true;
    });

    try {
      await _firestore.collection('users').doc(widget.user.uid).set({
        'tags': _selectedTags,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blogger Manager'),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildPage(_selectedIndex),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UploadBlogScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Blog'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeBlogSearchScreen(
          userLocation: _currentUserLocation,
          onLocationUpdated: (GeoPoint location) {
            setState(() {
              _currentUserLocation = location;
            });
          },
        );
      case 1:
        return _buildProfilePage();
      default:
        return _buildProfilePage();
    }
  }

  Widget _buildProfilePage() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(widget.user.uid).snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<String, dynamic>? data = snapshot.data?.data();
        final BloggerUser blogger = BloggerUser.fromJson(
          data ?? {},
          widget.user.uid,
        );
        Uint8List? profileImageBytes;
        try {
          final String? profileImageBase64 = blogger.profileImageBase64;
          if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
            profileImageBytes = base64Decode(profileImageBase64);
          }
        } catch (_) {
          profileImageBytes = null;
        }

        if (!_hasSeededProfile) {
          _selectedTags
            ..clear()
            ..addAll(blogger.tags);
          _hasSeededProfile = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: profileImageBytes == null
                              ? null
                              : MemoryImage(profileImageBytes),
                          child: profileImageBytes == null
                              ? const Icon(Icons.person, size: 28)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        blogger.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        blogger.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (blogger.domainLink != null &&
                          blogger.domainLink!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          blogger.domainLink!,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                      if ((blogger.county != null && blogger.county!.isNotEmpty) ||
                          (blogger.country != null && blogger.country!.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Text(
                          [blogger.county, blogger.country]
                              .whereType<String>()
                              .where((part) => part.isNotEmpty)
                              .join(', '),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bio section
              if (blogger.profileDetails != null &&
                  blogger.profileDetails!.isNotEmpty) ...[
                const Text(
                  'Bio',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(blogger.profileDetails!),
                const SizedBox(height: 16),
              ],

              const Text(
                'Main Tags',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final bool isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _saveProfile,
                  child: Text(
                    _isSavingProfile ? 'Saving...' : 'Save Profile Details',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Edit profile button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditBloggerProfileScreen(
                          userId: widget.user.uid,
                          blogger: blogger,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'My Uploaded Blogs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildMyBlogsSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyBlogsSection() {
    final Query<Map<String, dynamic>> myBlogsQuery = _firestore
        .collection('blogs')
        .where('uploadedBy', isEqualTo: widget.user.uid)
        .orderBy('uploadedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: myBlogsQuery.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text('Failed to load your blogs: ${snapshot.error}');
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Text('You have not uploaded any blogs yet.');
        }

        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            final String title = data['title'] as String? ?? '';
            final String description = data['description'] as String? ?? '';
            final String domainLink = data['domainLink'] as String? ?? '';
            final Timestamp? uploadedAt = data['uploadedAt'] as Timestamp?;
            final List<dynamic> tags = data['tags'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                    if (domainLink.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        domainLink,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                    if (uploadedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Uploaded: ${uploadedAt.toDate().toLocal().toString().split('.').first}',
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .map<Widget>(
                              (dynamic tag) => Chip(label: Text('$tag')),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}









