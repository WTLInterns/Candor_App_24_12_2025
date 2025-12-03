import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';

class AttendanceWorkFieldScreen extends StatefulWidget {
  const AttendanceWorkFieldScreen({super.key});

  @override
  State<AttendanceWorkFieldScreen> createState() => _AttendanceWorkFieldScreenState();
}

class _AttendanceWorkFieldScreenState extends State<AttendanceWorkFieldScreen> {
  File? _photoFile;
  double? _latitude;
  double? _longitude;
  bool _loadingLocation = false;
  bool _submitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _capturePhotoAndLocation() async {
    await _capturePhoto();
    await _getLocation();
  }

  Future<void> _capturePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _photoFile = File(picked.path);
    });
  }

  Future<void> _getLocation() async {
    setState(() {
      _loadingLocation = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    // kept for compatibility; not used directly in UI anymore
    if (_photoFile == null || _submitting) return;
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    final agentName = session.agentName ?? 'Agent';
    if (agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent not loaded, please re-login')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      await ApiClient().submitFieldAttendance(
        agentId: agentId,
        agentName: agentName,
        imageFile: _photoFile!,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work From Field attendance submitted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit attendance')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _punchIn() async {
    if (_photoFile == null || _submitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a photo first')),
      );
      return;
    }
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    final agentName = session.agentName ?? 'Agent';
    if (agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent not loaded, please re-login')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      await ApiClient().punchInAttendance(
        agentId: agentId,
        agentName: agentName,
        imageFile: _photoFile!,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punch In successful (Present)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to punch in')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _punchOut() async {
    if (_submitting) return;
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    final agentName = session.agentName ?? 'Agent';
    if (agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent not loaded, please re-login')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      await ApiClient().punchOutAttendance(
        agentId: agentId,
        agentName: agentName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punch Out successful')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to punch out')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work From Field Attendance'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Capture a photo and location to mark your Work From Field attendance.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _photoFile == null
                            ? Center(
                                child: Text(
                                  'No photo captured yet',
                                  style: theme.textTheme.bodySmall,
                                ),
                              )
                            : Image.file(
                                _photoFile!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 12),
                      if (_photoFile == null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Capture photo & location'),
                            onPressed: _capturePhotoAndLocation,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Retake photo'),
                                onPressed: _capturePhoto,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.my_location_outlined),
                                label: const Text('Refresh location'),
                                onPressed: _getLocation,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_loadingLocation)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      Text(
                        'Latitude: ${_latitude?.toStringAsFixed(6) ?? '-'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Longitude: ${_longitude?.toStringAsFixed(6) ?? '-'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _punchIn,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(_submitting ? 'Working…' : 'Punch In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: _submitting ? null : _punchOut,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_submitting ? 'Working…' : 'Punch Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
