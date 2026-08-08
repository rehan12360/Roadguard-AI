import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hazard.dart';
import '../services/database_service.dart';
import 'image_viewer_screen.dart';
import 'video_viewer_screen.dart';

class HazardDetailSheet extends StatefulWidget {
  final Hazard hazard;

  const HazardDetailSheet({super.key, required this.hazard});

  @override
  State<HazardDetailSheet> createState() => _HazardDetailSheetState();
}

class _HazardDetailSheetState extends State<HazardDetailSheet> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isUploading = false;
  String? _localMediaPath; // Temp path for immediate feedback

  Future<void> _showMediaPickerOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadMedia(ImageSource.camera, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Record Video', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadMedia(ImageSource.camera, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadMedia(ImageSource.gallery, isVideo: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadMedia(ImageSource source, {required bool isVideo}) async {
    final ImagePicker picker = ImagePicker();
    XFile? mediaFile;
    
    if (isVideo) {
      mediaFile = await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 30));
    } else {
      mediaFile = await picker.pickImage(source: source, imageQuality: 70);
    }

    if (mediaFile != null) {
      setState(() {
        _isUploading = true;
        _localMediaPath = mediaFile!.path;
      });

      final File fileToUpload = File(mediaFile.path);
      
      final String? downloadUrl = await _databaseService.uploadHazardMedia(
        widget.hazard.hazardId, 
        fileToUpload,
        isVideo: mediaFile.path.endsWith('.mp4'),
      );

      if (downloadUrl != null) {
        await _databaseService.updateHazardAttachment(widget.hazard.hazardId, downloadUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isVideo ? 'Video' : 'Photo'} attached successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload media.'), backgroundColor: Colors.red),
          );
        }
        setState(() => _localMediaPath = null);
      }

      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hazard;
    final currentAttachment = h.attachmentUrl ?? _localMediaPath;
    final isNetworkImage = h.attachmentUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618).withOpacity(0.95), // Glassmorphism base
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                h.hazardType.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: h.isCritical ? const Color(0xFFFF2A5F).withOpacity(0.2) : const Color(0xFFFFB300).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: h.isCritical ? const Color(0xFFFF2A5F) : const Color(0xFFFFB300)),
                ),
                child: Text(
                  h.severity.toUpperCase(),
                  style: TextStyle(
                    color: h.isCritical ? const Color(0xFFFF2A5F) : const Color(0xFFFFB300),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details grid
          Row(
            children: [
              _buildDetailItem(Icons.group, 'Verifications', '${h.verifications}'),
              const SizedBox(width: 24),
              _buildDetailItem(Icons.analytics, 'Confidence', '${(h.confidence * 100).toInt()}%'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'ATTACHMENT PROOF',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),

          // Attachment Area
          if (currentAttachment != null)
            GestureDetector(
              onTap: () {
                // Open full screen viewer
                if (isNetworkImage) {
                  final isVideo = currentAttachment.endsWith('.mp4');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isVideo
                          ? VideoViewerScreen(
                              videoUrl: currentAttachment,
                              heroTag: 'attachment_${h.hazardId}',
                            )
                          : ImageViewerScreen(
                              imageUrl: currentAttachment,
                              heroTag: 'attachment_${h.hazardId}',
                            ),
                    ),
                  );
                }
              },
              child: Hero(
                tag: 'attachment_${h.hazardId}',
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    color: Colors.black26,
                  ),
                  child: currentAttachment.endsWith('.mp4')
                      ? const Center(child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white70))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: isNetworkImage
                              ? Image.network(currentAttachment, fit: BoxFit.cover)
                              : Image.file(File(currentAttachment), fit: BoxFit.cover),
                        ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _isUploading ? null : _showMediaPickerOptions,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Color(0xFF00F2FE))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: Colors.white.withOpacity(0.5), size: 32),
                            const SizedBox(height: 8),
                            Text('Tap to add photo or video', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ],
                        ),
                ),
              ),
            ),
            
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
