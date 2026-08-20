import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/lga.dart';
import '../providers/auth_provider.dart';
import '../providers/lga_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.password});

  /// Set on the previous screen (SetPasswordScreen) - null if skipped.
  final String? password;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedState;
  Lga? _selectedLga;
  String _sellerType = 'none';
  bool _acceptedAgreement = false;
  Uint8List? _photoBytes;
  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _errorText;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          lockAspectRatio: true,
        ),
        IOSUiSettings(aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission denied. Please select your LGA manually.',
        );
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Location services are off. Please select your LGA manually.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw Exception('Could not determine your address.');
      }

      final placemark = placemarks.first;
      final stateGuess = placemark.administrativeArea;
      final lgaGuess = placemark.subAdministrativeArea ?? placemark.locality;
      final lgas = await ref.read(lgaListProvider.future);

      Lga? matched;
      if (stateGuess != null && lgaGuess != null) {
        for (final lga in lgas) {
          if (lga.state.toLowerCase() == stateGuess.toLowerCase() &&
              lga.name.toLowerCase() == lgaGuess.toLowerCase()) {
            matched = lga;
            break;
          }
        }
      }

      if (!mounted) return;

      if (matched == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't match your location to a supported LGA - "
              "please select it manually.",
            ),
          ),
        );
        return;
      }

      setState(() {
        _selectedState = matched!.state;
        _selectedLga = matched;
        if (_landmarkController.text.trim().isEmpty &&
            (placemark.street ?? '').isNotEmpty) {
          _landmarkController.text = placemark.street!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(e, fallback: 'Could not get your location.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_acceptedAgreement) {
      setState(() => _errorText = 'You must accept the seller agreement to continue.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        sellerType: _sellerType,
        acceptedAgreement: _acceptedAgreement,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        lgaId: _selectedLga?.id,
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        password: widget.password,
        passwordConfirmation: widget.password,
        photoBytes: _photoBytes,
        photoFilename: _photoBytes != null ? 'profile.jpg' : null,
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(
              e,
              fallback: 'Could not save your profile. Please try again.',
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Shrinks to fit on one line instead of Text's default behaviour of
  /// wrapping mid-word once a segment's equal share of the width runs out.
  Widget _segmentLabel(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, softWrap: false),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _landmarkController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lgasAsync = ref.watch(lgaListProvider);

    final sectionLabelStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Material(
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            color: AppColors.accent,
                            child: InkWell(
                              onTap: _pickPhoto,
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: _photoBytes != null
                                    ? Image.memory(
                                        _photoBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(
                                    color: AppColors.background,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Profile', style: sectionLabelStyle),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final isValid = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value.trim());
                        return isValid ? null : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(
                          _isLocating ? 'Locating...' : 'Use current location',
                        ),
                      ),
                    ),
                    lgasAsync.when(
                      data: (lgas) {
                        final states = lgas.map((l) => l.state).toSet().toList()
                          ..sort();
                        final lgasForState = _selectedState == null
                            ? <Lga>[]
                            : lgas
                                  .where((l) => l.state == _selectedState)
                                  .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedState,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                              items: states
                                  .map(
                                    (state) => DropdownMenuItem(
                                      value: state,
                                      child: Text(state),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() {
                                _selectedState = value;
                                _selectedLga = null;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Autocomplete<Lga>(
                              key: ValueKey(_selectedState),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return lgasForState;
                                }
                                final query = textEditingValue.text
                                    .toLowerCase();
                                return lgasForState.where(
                                  (l) => l.name.toLowerCase().contains(query),
                                );
                              },
                              displayStringForOption: (lga) => lga.name,
                              initialValue: TextEditingValue(
                                text: _selectedLga?.name ?? '',
                              ),
                              onSelected: (lga) =>
                                  setState(() => _selectedLga = lga),
                              fieldViewBuilder:
                                  (context, controller, focusNode, onSubmitted) {
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      enabled: _selectedState != null,
                                      decoration: InputDecoration(
                                        labelText: 'LGA',
                                        hintText: _selectedState == null
                                            ? 'Pick a state first'
                                            : 'Search LGA',
                                        prefixIcon: const Icon(
                                          Icons.location_on_outlined,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => Text(
                        'Could not load LGAs.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: const InputDecoration(
                        labelText: 'Landmark (optional)',
                        prefixIcon: Icon(Icons.signpost_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio (optional)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('I want to', style: sectionLabelStyle),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'none',
                            label: _segmentLabel('Just buy'),
                          ),
                          ButtonSegment(
                            value: 'personal',
                            label: _segmentLabel('Sell my wardrobe'),
                          ),
                          ButtonSegment(
                            value: 'business',
                            label: _segmentLabel('Run a store'),
                          ),
                        ],
                        selected: {_sellerType},
                        onSelectionChanged: (selection) =>
                            setState(() => _sellerType = selection.first),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acceptedAgreement,
                      onChanged: (value) =>
                          setState(() => _acceptedAgreement = value ?? false),
                      title: Text(
                        'I agree to the seller agreement and anti-leakage policy',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorText!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Text('Continue'),
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
