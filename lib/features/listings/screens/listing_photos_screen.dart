import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/listing.dart';
import '../providers/listings_provider.dart';

const _minimumPhotoCountByGrade = {
  'A++': 2,
  'A+': 2,
  'A': 3,
  'B': 3,
  'C': 4,
  'D': 5,
  'X': 5,
};

class ListingPhotosScreen extends ConsumerStatefulWidget {
  const ListingPhotosScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingPhotosScreen> createState() =>
      _ListingPhotosScreenState();
}

class _ListingPhotosScreenState extends ConsumerState<ListingPhotosScreen> {
  Listing? _listing;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final listing = await ref
          .read(myListingsProvider.notifier)
          .getListing(widget.listingId);
      if (!mounted) return;
      setState(() => _listing = listing);
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not load this listing.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading || _listing == null) return;

    final remaining = 6 - _listing!.photos.length;
    if (remaining <= 0) {
      _showError('A listing can have at most 6 photos.');
      return;
    }

    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();
        await ref.read(myListingsProvider.notifier).uploadPhoto(
          listingUuid: widget.listingId,
          bytes: bytes,
          filename: file.name,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not upload photo.'));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    try {
      await ref.read(myListingsProvider.notifier).deletePhoto(
        listingUuid: widget.listingId,
        photoId: photoId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not remove photo.'));
    }
  }

  Future<void> _publish() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      await ref
          .read(myListingsProvider.notifier)
          .publishListing(widget.listingId);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not publish listing.'));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    final minimum = listing != null
        ? (_minimumPhotoCountByGrade[listing.conditionGrade] ?? 3)
        : 3;
    final photoCount = listing?.photos.length ?? 0;
    final meetsMinimum = photoCount >= minimum;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add photos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meetsMinimum
                          ? 'You have $photoCount photo${photoCount == 1 ? '' : 's'}.'
                          : 'Grade ${listing?.conditionGrade} listings need at '
                                'least $minimum photos - you have $photoCount.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: meetsMinimum
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                            ),
                        itemCount: (listing?.photos.length ?? 0) + 1,
                        itemBuilder: (context, index) {
                          if (index == (listing?.photos.length ?? 0)) {
                            return _AddPhotoTile(
                              isUploading: _isUploading,
                              onTap: _pickAndUpload,
                            );
                          }

                          final photo = listing!.photos[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                child: Image.network(
                                  photo.url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => _deletePhoto(photo.id),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.error,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: AppColors.surface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!meetsMinimum || _isPublishing)
                            ? null
                            : _publish,
                        child: _isPublishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Text('Publish'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Save draft and finish later'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.isUploading, required this.onTap});

  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: isUploading ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Center(
          child: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
        ),
      ),
    );
  }
}
