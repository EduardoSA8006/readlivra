import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/models/ebook.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class TocDrawer extends ConsumerWidget{
  const TocDrawer({
    super.key,
    required this.ebook,
    required this.currentChapter,
    required this.onChapterTap,
  });

  final Ebook ebook;
  final int currentChapter;
  final void Function(int chapterIndex) onChapterTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    final controller = ItemScrollController();
    final initial = currentChapter.clamp(0, ebook.chapterCount - 1).toInt();
    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUMÁRIO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ebook.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  if (ebook.author != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      ebook.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${ebook.chapterCount} ${ebook.chapterCount == 1 ? "capítulo" : "capítulos"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDE7DD)),
            Expanded(
              child: ScrollablePositionedList.builder(
                itemScrollController: controller,
                initialScrollIndex: initial,
                initialAlignment: 0.1,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: ebook.chapterCount,
                itemBuilder: (context, i) => _ChapterTile(
                  index: i,
                  title: ebook.chapters[i].title,
                  isCurrent: i == currentChapter,
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onChapterTap(i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget{
  const _ChapterTile({
    required this.index,
    required this.title,
    required this.isCurrent,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? palette.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isCurrent ? palette.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isCurrent ? palette.accent : palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  fontSize: 14,
                  color: palette.textPrimary,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            if (isCurrent)
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.bookmark_rounded,
                    size: 16, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}
