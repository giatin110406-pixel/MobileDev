import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/app/pocket_top_bar.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// "MM.DD  h:mm AM" for print timestamps.
String formatPrintDate(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}  $hour:$minute $period';
}

/// The PRINTS tab: every photo kept on this device, newest first.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({
    super.key,
    required this.photos,
    required this.onOpenPhoto,
    required this.onOpenCamera,
  });

  final List<NeoPhoto> photos;
  final ValueChanged<NeoPhoto> onOpenPhoto;
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) => _buildArchive(context);

  Widget _buildArchive(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PocketTopBar(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).localCollection,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).printArchive,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              NeoLabel(
                AppLocalizations.of(context).itemsCount(photos.length),
                color: NeoColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: photos.isEmpty
                ? _buildEmptyArchive(context)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    itemCount: photos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildArchiveRow(context, photos[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveRow(BuildContext context, NeoPhoto photo, int index) {
    final thumbnail = photo.processedPath ?? photo.originalPath;
    return InkWell(
      onTap: () => onOpenPhoto(photo),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: NeoTheme.panel(
          color: index.isEven ? NeoColors.surface : NeoColors.yellow,
          borderWidth: 2,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: NeoColors.teal,
                border: Border.all(color: NeoColors.ink, width: 2),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(thumbnail),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.photo_outlined, color: NeoColors.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRINT ${(photos.length - index).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatPrintDate(photo.createdAt)}  /  ${_statusText(AppLocalizations.of(context), photo.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.photo_camera_outlined, color: NeoColors.ink, size: 23),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyArchive(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: NeoTheme.panel(color: NeoColors.blue, borderWidth: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: NeoTheme.panel(
              color: NeoColors.pink,
              borderWidth: 2,
              radius: 999,
            ),
            child: const Icon(
              Icons.collections_outlined,
              color: NeoColors.ink,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NOTHING\nPRINTED YET',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NeoFont.display,
              color: NeoColors.ink,
              fontSize: 24,
              height: 0.98,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).archiveEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          NeoButton(
            label: AppLocalizations.of(context).openCamera,
            icon: Icons.photo_camera_outlined,
            variant: NeoButtonVariant.primary,
            onPressed: onOpenCamera,
          ),
        ],
      ),
    );
  }

  String _statusText(AppLocalizations l10n, ProcessingStatus status) =>
      switch (status) {
        ProcessingStatus.pending => l10n.statusInking,
        ProcessingStatus.done => l10n.printReady,
        ProcessingStatus.failed => l10n.originalSaved,
      };
}
