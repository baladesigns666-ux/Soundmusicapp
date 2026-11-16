import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import '../widgets/retro_radio_widgets.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AudioController.instance,
        builder: (context, _) {
          final c = AudioController.instance;
          final queue = c.playQueue;
          final current = c.currentSong;
          final firstUpcoming = (c.currentIndex + 1).clamp(0, queue.length).toInt();
          final upcoming = queue.skip(firstUpcoming).toList(growable: false);
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6E8D5), Color(0xFFFAF3E8)],
                  stops: [0, .45], begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                    child: Row(children: [
                      RetroTactileButton(
                        width: 42.w, height: 42.w,
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: const Color(0xFF4A1818), size: 18.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(child: Text('PLAY QUEUE (${upcoming.length} UP NEXT)', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF4A1818)))),
                      if (upcoming.isNotEmpty)
                        RetroTactileButton(
                          width: 104.w, height: 38.h, isPrimaryRed: true,
                          onTap: () async => c.clearQueue(),
                          child: Text('CLEAR NEXT', style: GoogleFonts.montserrat(fontSize: 9.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: current == null && upcoming.isEmpty
                        ? const RetroRadioIllustration(message: 'NO SONGS IN QUEUE')
                        : CustomScrollView(slivers: [
                            if (current != null) ...[
                              SliverToBoxAdapter(child: _heading('NOW PLAYING', Icons.equalizer_rounded)),
                              SliverToBoxAdapter(child: _songCard(current, number: c.currentIndex + 1, current: true, onTap: () => c.playSong(current))),
                            ],
                            SliverToBoxAdapter(child: _heading('UP NEXT  •  ${upcoming.length}', Icons.queue_music_rounded)),
                            if (upcoming.isEmpty)
                              SliverToBoxAdapter(child: Padding(
                                padding: EdgeInsets.all(24.w),
                                child: Text('No upcoming songs. Add songs using Play Next.', textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(fontSize: 12.sp, color: const Color(0xFF8D6E63), fontWeight: FontWeight.w600)),
                              ))
                            else
                              SliverReorderableList(
                                itemCount: upcoming.length,
                                onReorder: c.reorderUpcoming,
                                itemBuilder: (context, index) {
                                  final song = upcoming[index];
                                  return _songCard(
                                    song, key: ValueKey('queue-${song.id}'), number: index + 1,
                                    current: false, added: c.userAddedQueueIds.contains(song.id),
                                    onTap: () => c.playSong(song),
                                    onRemove: () => c.removeFromQueue(firstUpcoming + index),
                                    trailing: ReorderableDragStartListener(index: index, child: Icon(Icons.drag_handle_rounded, color: const Color(0xFF8D6E63), size: 23.sp)),
                                  );
                                },
                              ),
                            SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                          ]),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  Widget _heading(String text, IconData icon) => Padding(
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 5.h),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFC62828), size: 17.sp), SizedBox(width: 7.w),
          Text(text, style: GoogleFonts.montserrat(fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 1, color: const Color(0xFF6D4C41))),
        ]),
      );

  Widget _songCard(SongModel song, {Key? key, required int number, required bool current, bool added = false,
    required VoidCallback onTap, VoidCallback? onRemove, Widget? trailing}) => Container(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r), onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: current ? const LinearGradient(colors: [Color(0xFFFFCDD2), Color(0xFFFFFBF4)]) : null,
              color: current ? null : const Color(0xFFFFFBF4),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: current ? const Color(0xFFC62828) : added ? const Color(0xFFD4A359) : const Color(0xFF4A1818).withOpacity(.35), width: current ? 2.w : 1.3.w),
              boxShadow: [BoxShadow(color: const Color(0xFF4A1818).withOpacity(current ? .25 : .12), offset: Offset(3.w, 3.h), blurRadius: 0)],
            ),
            child: Row(children: [
              Container(width: 30.w, height: 30.w, decoration: BoxDecoration(color: current ? const Color(0xFFC62828) : const Color(0xFFF6E8D5), borderRadius: BorderRadius.circular(8.r)),
                child: Center(child: current ? Icon(Icons.equalizer_rounded, color: Colors.white, size: 19.sp) : Text('$number', style: GoogleFonts.montserrat(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF4A1818))))),
              SizedBox(width: 12.w),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: 13.sp, fontWeight: FontWeight.w800, color: current ? const Color(0xFFB71C1C) : const Color(0xFF2B1212))),
                SizedBox(height: 3.h),
                Text('${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Single'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF6D4C41))),
              ])),
              if (current)
                Padding(padding: EdgeInsets.only(left: 8.w), child: Text('PLAYING', style: GoogleFonts.montserrat(fontSize: 8.sp, fontWeight: FontWeight.w900, color: const Color(0xFFC62828))))
              else ...[
                if (added) Padding(padding: EdgeInsets.only(left: 5.w), child: Text('PLAY NEXT', style: GoogleFonts.montserrat(fontSize: 8.sp, fontWeight: FontWeight.w900, color: const Color(0xFFC62828)))),
                if (onRemove != null) IconButton(visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), padding: EdgeInsets.zero, onPressed: onRemove, icon: Icon(Icons.close_rounded, size: 18.sp, color: const Color(0xFF8D6E63))),
                if (trailing != null) trailing,
              ],
            ]),
          ),
        ),
      ),
    );
}
