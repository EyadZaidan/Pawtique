import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  _ProfileInfoPageState createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String _displayName = '';
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _address = 'Not provided';
  String? _imagePath; // Changed from _imageUrl to _imagePath for local storage
  File? _imageFile;
  bool _isEditing = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _loadUserInfo);
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = _auth.currentUser;
    if (user != null) {
      try {
        debugPrint('Loading user info for UID: ${user.uid}');
        setState(() {
          _displayName = user.displayName ?? 'User';
          _email = user.email ?? 'Not provided';
        });

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          debugPrint('User data retrieved: $userData');
          if (userData != null) {
            setState(() {
              _displayName = userData['displayName'] ?? user.displayName ?? 'User';
              _email = userData['email'] ?? user.email ?? 'Not provided';
              _phone = userData['phone'] ?? 'Not provided';
              _address = userData['address'] ?? 'Not provided';
              _imagePath = userData['imagePath']; // Load local path instead of URL
            });
          }
        } else {
          debugPrint('User document does not exist. Creating one.');
          await _firestore.collection('users').doc(user.uid).set({
            'displayName': user.displayName ?? 'User',
            'email': user.email,
            'phone': 'Not provided',
            'address': 'Not provided',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error loading user info: $e');
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      debugPrint('No user is signed in');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to view your profile';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _saveImageLocally();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _saveImageLocally() async {
    if (_imageFile == null) return;
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user signed in')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving image locally...')),
      );

      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final userDir = Directory('${directory.path}/profile_images/${user.uid}');

      // Create the directory if it doesn't exist
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }

      // Generate a unique filename
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${userDir.path}/$fileName';

      // Copy the image to the new location
      await _imageFile!.copy(filePath);
      debugPrint('Image saved to: $filePath');

      // Update Firestore with the local file path
      await _firestore.collection('users').doc(user.uid).update({
        'imagePath': filePath, // Store the local path instead of a URL
        'lastProfileUpdateTime': FieldValue.serverTimestamp(),
      });

      setState(() {
        _imagePath = filePath;
        _imageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      String errorMessage = 'Failed to save image';
      if (e is FileSystemException) {
        errorMessage = 'File system error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = _auth.currentUser;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving changes...')),
        );

        _firestore.collection('users').doc(user.uid).update({
          'displayName': _displayName,
          'phone': _phone,
          'address': _address,
          'updatedAt': FieldValue.serverTimestamp(),
        }).then((_) {
          setState(() {
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }).catchError((error) {
          debugPrint('Error saving profile: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile: $error')),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Information')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserInfo,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Information'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.cancel : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserInfo,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _isEditing ? _pickImage : null,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: _imagePath != null
                              ? FileImage(File(_imagePath!))
                              : _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: _imagePath == null && _imageFile == null
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _displayName,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          onSaved: (value) => _displayName = value ?? _displayName,
                          validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _email,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _phone,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          onSaved: (value) => _phone = value ?? _phone,
                          validator: (value) => value!.isEmpty ? 'Please enter a phone number' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _address,
                          enabled: _isEditing,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                            alignLabelWithHint: true,
                          ),
                          onSaved: (value) => _address = value ?? _address,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}