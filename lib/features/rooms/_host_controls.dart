import 'package:flutter/material.dart';
import '../../models/room_member_model.dart';
import '../../services/room_service.dart';

// ignore: unused_element
class _HostControls extends StatelessWidget {
  final RoomMember member;
  final String roomId;
  const _HostControls({required this.member, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<RoomMemberRole>(
          value: member.role,
          items: RoomMemberRole.values.map((role) => DropdownMenuItem(
            value: role,
            child: Text(role.toString().split('.').last),
          )).toList(),
          onChanged: (role) async {
            if (role != null) {
              final updated = RoomMember(
                userId: member.userId,
                role: role,
                joinedAt: member.joinedAt,
              );
              await RoomService().joinRoom(roomId, updated);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.volume_off),
          onPressed: () {
            // Mute logic (to be implemented)
          },
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle),
          onPressed: () async {
            await RoomService().leaveRoom(roomId, member.userId);
          },
        ),
      ],
    );
  }
}
