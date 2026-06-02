import 'package:flutter/material.dart';

class LiveRoomAppBarStatus extends StatelessWidget
    implements PreferredSizeWidget {
  const LiveRoomAppBarStatus({
    super.key,
    required this.roomDescription,
    this.cameraStatus,
    required this.tickerBuilder,
  });

  final String roomDescription;
  final String? cameraStatus;
  final Widget Function(String text) tickerBuilder;

  bool get _isEmpty => roomDescription.isEmpty && cameraStatus == null;

  @override
  Size get preferredSize => Size.fromHeight(
        (roomDescription.isEmpty ? 0.0 : 24.0) +
            (cameraStatus != null ? 20.0 : 0.0),
      );

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (roomDescription.isNotEmpty) tickerBuilder(roomDescription),
        if (cameraStatus != null)
          Container(
            width: double.infinity,
            color: const Color(0x9910131A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              cameraStatus!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
