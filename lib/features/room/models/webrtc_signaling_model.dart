import 'package:json_annotation/json_annotation.dart';

part 'webrtc_signaling_model.g.dart';

/// Represents a peer's SDP offer in the signaling exchange
@JsonSerializable()
class SDPOfferModel {
  final String peerId;
  final String sdpOffer;
  final DateTime createdAt;

  SDPOfferModel({
    required this.peerId,
    required this.sdpOffer,
    required this.createdAt,
  });

  factory SDPOfferModel.fromJson(Map<String, dynamic> json) =>
      _$SDPOfferModelFromJson(json);

  Map<String, dynamic> toJson() => _$SDPOfferModelToJson(this);
}

/// Represents the host's SDP answer to a peer
@JsonSerializable()
class SDPAnswerModel {
  final String peerId;
  final String sdpAnswer;
  final DateTime createdAt;

  SDPAnswerModel({
    required this.peerId,
    required this.sdpAnswer,
    required this.createdAt,
  });

  factory SDPAnswerModel.fromJson(Map<String, dynamic> json) =>
      _$SDPAnswerModelFromJson(json);

  Map<String, dynamic> toJson() => _$SDPAnswerModelToJson(this);
}

/// Represents an ICE candidate for NAT traversal
@JsonSerializable()
class ICECandidateModel {
  final String candidate;
  final int sdpMLineIndex;
  final String sdpMid;
  final String fromPeer; // "host" or audience member's ID
  final DateTime createdAt;

  ICECandidateModel({
    required this.candidate,
    required this.sdpMLineIndex,
    required this.sdpMid,
    required this.fromPeer,
    required this.createdAt,
  });

  factory ICECandidateModel.fromJson(Map<String, dynamic> json) =>
      _$ICECandidateModelFromJson(json);

  Map<String, dynamic> toJson() => _$ICECandidateModelToJson(this);
}

/// WebRTC connection status for a peer
enum WebRTCPeerStatus { connecting, connected, failed, disconnected }

/// Tracks the WebRTC connection state for a peer in a room
@JsonSerializable()
class WebRTCPeerModel {
  final String peerId;
  final String userId;
  final String status; // "connecting", "connected", "failed", "disconnected"
  final DateTime createdAt;
  final DateTime? connectedAt;

  WebRTCPeerModel({
    required this.peerId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.connectedAt,
  });

  factory WebRTCPeerModel.fromJson(Map<String, dynamic> json) =>
      _$WebRTCPeerModelFromJson(json);

  Map<String, dynamic> toJson() => _$WebRTCPeerModelToJson(this);
}

/// Root WebRTC state for a room
@JsonSerializable()
class RoomWebRTCStateModel {
  final String roomId;
  final String hostPeerId;
  final String hostStatus; // "streaming", "idle", "offline"
  final DateTime lastUpdated;
  final int activePeerCount;

  RoomWebRTCStateModel({
    required this.roomId,
    required this.hostPeerId,
    required this.hostStatus,
    required this.lastUpdated,
    this.activePeerCount = 0,
  });

  factory RoomWebRTCStateModel.fromJson(Map<String, dynamic> json) =>
      _$RoomWebRTCStateModelFromJson(json);

  Map<String, dynamic> toJson() => _$RoomWebRTCStateModelToJson(this);
}
