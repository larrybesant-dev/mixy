// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webrtc_signaling_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SDPOfferModel _$SDPOfferModelFromJson(Map<String, dynamic> json) =>
    SDPOfferModel(
      peerId: json['peerId'] as String,
      sdpOffer: json['sdpOffer'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SDPOfferModelToJson(SDPOfferModel instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'sdpOffer': instance.sdpOffer,
      'createdAt': instance.createdAt.toIso8601String(),
    };

SDPAnswerModel _$SDPAnswerModelFromJson(Map<String, dynamic> json) =>
    SDPAnswerModel(
      peerId: json['peerId'] as String,
      sdpAnswer: json['sdpAnswer'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SDPAnswerModelToJson(SDPAnswerModel instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'sdpAnswer': instance.sdpAnswer,
      'createdAt': instance.createdAt.toIso8601String(),
    };

ICECandidateModel _$ICECandidateModelFromJson(Map<String, dynamic> json) =>
    ICECandidateModel(
      candidate: json['candidate'] as String,
      sdpMLineIndex: (json['sdpMLineIndex'] as num).toInt(),
      sdpMid: json['sdpMid'] as String,
      fromPeer: json['fromPeer'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ICECandidateModelToJson(ICECandidateModel instance) =>
    <String, dynamic>{
      'candidate': instance.candidate,
      'sdpMLineIndex': instance.sdpMLineIndex,
      'sdpMid': instance.sdpMid,
      'fromPeer': instance.fromPeer,
      'createdAt': instance.createdAt.toIso8601String(),
    };

WebRTCPeerModel _$WebRTCPeerModelFromJson(Map<String, dynamic> json) =>
    WebRTCPeerModel(
      peerId: json['peerId'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
    );

Map<String, dynamic> _$WebRTCPeerModelToJson(WebRTCPeerModel instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'userId': instance.userId,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'connectedAt': instance.connectedAt?.toIso8601String(),
    };

RoomWebRTCStateModel _$RoomWebRTCStateModelFromJson(
        Map<String, dynamic> json) =>
    RoomWebRTCStateModel(
      roomId: json['roomId'] as String,
      hostPeerId: json['hostPeerId'] as String,
      hostStatus: json['hostStatus'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      activePeerCount: (json['activePeerCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RoomWebRTCStateModelToJson(
        RoomWebRTCStateModel instance) =>
    <String, dynamic>{
      'roomId': instance.roomId,
      'hostPeerId': instance.hostPeerId,
      'hostStatus': instance.hostStatus,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'activePeerCount': instance.activePeerCount,
    };
