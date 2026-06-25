import 'package:flutter/material.dart';

class LiveRoomScreen extends StatelessWidget {
  final String roomId;
  final dynamic previewRoom;

  const LiveRoomScreen({super.key, required this.roomId, this.previewRoom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Room')),
      body: const Center(
        child: Text('Live Room Coming Soon'),
      ),
    );
  }
}





