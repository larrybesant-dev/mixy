import '../room_controller.dart';

export '../room_controller.dart'
    show
        RoomController,
        MicRequestResult,
        LiveRoomPhase,
        RoomAudioState,
        RoomMembershipState,
        RoomMembershipStateX,
        RoomSessionSnapshot,
        RoomState,
        roomControllerProvider;

typedef LiveRoomController = RoomController;
typedef LiveRoomState = RoomState;

final liveRoomControllerProvider = roomControllerProvider;
