import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
    if (_photoFile == null) {
      // Camera permission denied or user cancelled; don't proceed further.
      return;
    }

    await _getLocation();
    if (_latitude == null || _longitude == null) {
      // Location permission denied or failed; stop here.
      return;
    }
  }

  Future<void> _capturePhoto() async {
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Camera permission required'),
          content: const Text(
            'We use your camera to capture a photo as proof for your attendance. '
            'Please allow camera access on the next prompt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (proceed != true) {
      return;
    }

    final requestResult = await Permission.camera.request();
    if (!requestResult.isGranted) {
      if (!mounted) return;
      final permanentlyDenied = requestResult.isPermanentlyDenied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permanentlyDenied
                ? 'Camera permission is permanently denied. Please enable it from Settings to capture attendance photo.'
                : 'Camera permission is required to capture a photo.',
          ),
        ),
      );
      return;
    }

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
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Location permission required'),
              content: const Text(
                'We use your location to attach coordinates to your attendance. '
                'Please allow location access on the next prompt.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );

        if (proceed != true) {
          return;
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Unable to capture coordinates.'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied. Please enable it from Settings.'),
          ),
        );
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

    // Prevent multiple punch-ins for the same day.
    final alreadyPunchedIn = await _hasAlreadyPunchedInToday(agentId);
    if (alreadyPunchedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already punched in for today')),
      );
      return;
    }

    // Check if the user has already punched out today.
    final alreadyPunchedOut = await _hasAlreadyPunchedOutToday(agentId);
    if (alreadyPunchedOut) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already punched out for today')),
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
    if (_submitting) return;
    if (_photoFile == null || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Punch In requires both a photo and your current location. Please capture photo & location first.',
          ),
        ),
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

  Future<bool> _hasAlreadyPunchedInToday(String agentId) async {
    try {
      final now = DateTime.now();
      final ym = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';

      final records = await ApiClient().fetchMonthlyPunchRecords(
        agentId: agentId,
        yearMonth: ym,
      );

      final todayStr = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      for (final r in records) {
        final date = r['date']?.toString();
        final punchIn = r['punchInTime']?.toString();
        if (date == todayStr && punchIn != null && punchIn.isNotEmpty) {
          return true;
        }
      }
    } catch (_) {
      // If anything fails, fall back to allowing punch-in so we don't block the user.
    }
    return false;
  }

  Future<bool> _hasAlreadyPunchedOutToday(String agentId) async {
    try {
      final now = DateTime.now();
      final ym = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';

      final records = await ApiClient().fetchMonthlyPunchRecords(
        agentId: agentId,
        yearMonth: ym,
      );

      final todayStr = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      for (final r in records) {
        final date = r['date']?.toString();
        final punchOut = r['punchOutTime']?.toString();
        if (date == todayStr && punchOut != null && punchOut.isNotEmpty) {
          return true;
        }
      }
    } catch (_) {
      // If anything fails, fall back to allowing punch-out so we don't block the user.
    }
    return false;
  }

  Future<void> _punchOut() async {
    if (_submitting) return;
    if (_photoFile == null || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Punch Out requires both a photo and your current location. Please capture photo & location first.',
          ),
        ),
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
      await ApiClient().punchOutAttendance(
        agentId: agentId,
        agentName: agentName,
        imageFile: _photoFile!,
        latitude: _latitude,
        longitude: _longitude,
        reason: null,
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
        elevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A66C2), Color(0xFF4FA0FF), Color(0xFFE6F3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.grey.shade100,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _photoFile == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_outlined,
                                          size: 40,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No photo captured yet',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
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
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0052CC),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
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
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.my_location_outlined),
                                      label: const Text('Refresh location'),
                                      onPressed: _getLocation,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Location details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_loadingLocation)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: LinearProgressIndicator(minHeight: 3),
                              ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey.shade100,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: Color(0xFF0052CC),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Current coordinates',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
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
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _submitting ? null : _punchIn,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: _submitting ? null : _punchOut,
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
