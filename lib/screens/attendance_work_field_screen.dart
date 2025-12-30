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
  State<AttendanceWorkFieldScreen> createState() =>
      _AttendanceWorkFieldScreenState();
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

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
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
              content: Text(
                'Location permission denied. Unable to capture coordinates.',
              ),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable it from Settings.',
            ),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to punch in')));
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
      final ym =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';

      final records = await ApiClient().fetchMonthlyPunchRecords(
        agentId: agentId,
        yearMonth: ym,
      );

      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-'
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
      final ym =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';

      final records = await ApiClient().fetchMonthlyPunchRecords(
        agentId: agentId,
        yearMonth: ym,
      );

      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-'
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Punch Out successful')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to punch out')));
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
        title: const Text('Work From Field'),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFEEF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Camera Card
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 240,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.grey.shade50],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _photoFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF0052CC),
                                            Color(0xFF2563EB),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Capture Your Photo',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0D1B2A),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'No photo captured yet',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF94A3B8),
                                          ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_photoFile!, fit: BoxFit.cover),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Color(0xFF22C55E),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Captured',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
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
                    const SizedBox(height: 20),

                    // Action Buttons
                    if (_photoFile == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0052CC),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, size: 20),
                          label: const Text(
                            'Capture Photo & Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _capturePhotoAndLocation,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                              ),
                              label: const Text('Retake'),
                              onPressed: _capturePhoto,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.my_location_outlined,
                                size: 18,
                              ),
                              label: const Text('Refresh'),
                              onPressed: _getLocation,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Location Card
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0052CC),
                                      Color(0xFF2563EB),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Location',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0D1B2A),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _loadingLocation
                                          ? 'Fetching coordinates...'
                                          : 'GPS Coordinates',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF94A3B8),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingLocation)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_loadingLocation)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0052CC),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFF0F4F8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Color(0xFF0052CC),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Latitude',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _latitude?.toStringAsFixed(6) ?? '-',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF0D1B2A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Color(0xFF0052CC),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Longitude',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _longitude?.toStringAsFixed(6) ?? '-',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF0D1B2A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Punch Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _punchIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 4,
                            ),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.login, size: 18),
                            label: Text(
                              _submitting ? 'Processing…' : 'Punch In',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _submitting ? null : _punchOut,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.logout, size: 18),
                            label: Text(
                              _submitting ? 'Processing…' : 'Punch Out',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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
