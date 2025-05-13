import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  _ProfileInfoPageState createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String _displayName = '';
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _address = 'Not provided';
  String? _imageUrl;
  File? _imageFile;
  bool _isEditing = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Add a slight delay to ensure Firebase is fully initialized
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

        // First set basic info from Firebase Auth
        setState(() {
          _displayName = user.displayName ?? 'User';
          _email = user.email ?? 'Not provided';
        });

        // Then try to get additional info from Firestore
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
              _imageUrl = userData['imageUrl'];
            });
          }
        } else {
          debugPrint('User document does not exist. Creating one.');
          // Create a user document if it doesn't exist
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
        await _uploadImage();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

// In profile_info_page.dart: Update the _uploadImage method

  Future<void> _uploadImage() async {
    if (_imageFile != null) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image...')),
          );

          // Ensure Firebase Storage is properly initialized before using it
          // Create a more specific reference path with better structure
          final storageRef = FirebaseStorage.instance.ref();
          final profileImageRef = storageRef.child('profile_images/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

          // Use putFile with SettableMetadata for better control
          final uploadTask = await profileImageRef.putFile(
            _imageFile!,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploaded_by': user.uid},
            ),
          );

          // Get download URL after successful upload
          final url = await profileImageRef.getDownloadURL();

          // Update Firestore document with the new image URL
          await _firestore.collection('users').doc(user.uid).update({
            'imageUrl': url,
            'lastProfileUpdateTime': FieldValue.serverTimestamp(),
          });

          setState(() {
            _imageUrl = url;
            _imageFile = null; // Clear the file reference after successful upload
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          debugPrint('Error uploading image: $e');
          // Provide more specific error feedback
          String errorMessage = 'Failed to upload image';
          if (e is FirebaseException) {
            switch (e.code) {
              case 'unauthorized':
                errorMessage = 'You do not have permission to upload files';
                break;
              case 'canceled':
                errorMessage = 'Upload was cancelled';
                break;
              case 'storage/object-not-found':
                errorMessage = 'Storage location not found. Check your Firebase configuration';
                break;
              default:
                errorMessage = 'Upload error: ${e.message}';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = _auth.currentUser;
      if (user != null) {
        // Show loading indicator
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
                          backgroundImage: _imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: _imageUrl == null && _imageFile == null
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