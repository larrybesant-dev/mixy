// ============================================================================
// Agora Web Bridge - Production-Ready with Device Switching
// ============================================================================
// Exposes all Agora functions on window.agoraWebBridge for Dart JS interop.
// Includes: init, join, camera, mic, device switching, getDevices
// ============================================================================

// State - directly on window for debugging
window.agoraBridgeState = {
  initialized: false,
  sdkLoaded: false,
  client: null,
  localTracks: { audio: null, video: null },
  currentChannel: null,
  currentUid: null,
  appId: null,
  currentToken: null,
  currentVideoDeviceId: null,
  currentMicDeviceId: null,
  connectionState: 'DISCONNECTED',
  reconnecting: false,
  reconnectAttempts: 0,
  networkQuality: { uplink: 0, downlink: 0 },
  activeAgoraUsers: new Set(),
  lastError: null,
  remoteVideoSubscriberElementId: null,
  pendingRemoteTracks: {}
};

function findElementByIdDeep(id) {
  if (!id || typeof document === 'undefined') return null;

  function walk(root) {
    if (!root) return null;

    if (typeof root.getElementById === 'function') {
      const byId = root.getElementById(id);
      if (byId) return byId;
    }

    if (typeof root.querySelectorAll !== 'function') return null;
    const nodes = root.querySelectorAll('*');
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      if (node && node.id === id) return node;
      if (node && node.shadowRoot) {
        const fromShadow = walk(node.shadowRoot);
        if (fromShadow) return fromShadow;
      }
    }

    return null;
  }

  return walk(document);
}

function findAnyLocalVideoContainer() {
  if (typeof document === 'undefined') return null;

  function walk(root) {
    if (!root || typeof root.querySelectorAll !== 'function') return null;

    const direct = root.querySelector('[id^="mm_local_video_el_"]');
    if (direct) return direct;

    const nodes = root.querySelectorAll('*');
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      if (node && node.shadowRoot) {
        const fromShadow = walk(node.shadowRoot);
        if (fromShadow) return fromShadow;
      }
    }

    return null;
  }

  return walk(document);
}

// Logging helper
window.agoraBridgeLog = function (level, msg, data) {
  const timestamp = new Date().toLocaleTimeString();
  const prefix = `[${timestamp}] [AgoraBridge]`;
  const style = {
    INFO: "color: #4A90E2; font-weight: bold;",
    SUCCESS: "color: #4CAF50; font-weight: bold;",
    ERROR: "color: #F44336; font-weight: bold;",
    WARN: "color: #FF9800; font-weight: bold;",
  };
  console.log(`%c${prefix} ${level}: ${msg}`, style[level] || "", data || "");
};

// ========== SDK LOADING ==========

async function loadAgoraSDK() {
  if (window.AgoraRTC) {
    window.agoraBridgeState.sdkLoaded = true;
    return true;
  }

  return new Promise((resolve) => {
    const script = document.createElement("script");
    script.src = "https://download.agora.io/sdk/release/AgoraRTC_N.js";
    script.async = true;

    script.onload = () => {
      window.agoraBridgeLog("SUCCESS", "Agora SDK loaded");
      window.agoraBridgeState.sdkLoaded = true;
      resolve(true);
    };

    script.onerror = () => {
      window.agoraBridgeLog("ERROR", "Failed to load Agora SDK");
      resolve(false);
    };

    document.head.appendChild(script);
  });
}

// ========== MAIN BRIDGE OBJECT ==========

window.agoraWebBridge = {
  // Initialize Agora with App ID
  init: async function (appId) {
    window.agoraBridgeLog("INFO", "init called", { appId: appId?.substring(0, 8) + "..." });
    const state = window.agoraBridgeState;

    if (state.initialized && state.appId === appId) {
      window.agoraBridgeLog("INFO", "Already initialized");
      return true;
    }

    try {
      state.lastError = null;
      // Load SDK if needed
      if (!window.AgoraRTC) {
        window.agoraBridgeLog("INFO", "Loading Agora SDK...");
        await loadAgoraSDK();
      }

      if (!window.AgoraRTC) {
        window.agoraBridgeLog("ERROR", "AgoraRTC SDK not available");
        return false;
      }

      // Create client
      state.client = window.AgoraRTC.createClient({
        mode: "rtc",
        codec: "vp8",
      });

      // Set up event handlers
      state.client.on('user-published', async (user, mediaType) => {
        window.agoraBridgeLog('INFO', 'Remote user published', { uid: user.uid, mediaType });
        state.activeAgoraUsers.add(String(user.uid));
        try {
          await state.client.subscribe(user, mediaType);
          if (mediaType === 'video' && user.videoTrack) {
            const remoteContainer = document.getElementById('remote-video-' + user.uid);
            if (remoteContainer) user.videoTrack.play(remoteContainer);
          }
          if (mediaType === 'audio' && user.audioTrack) user.audioTrack.play();
          window.agoraBridgeLog('SUCCESS', 'Subscribed to track', { uid: user.uid, mediaType });
        } catch (e) {
          window.agoraBridgeLog('ERROR', 'Subscribe failed', { uid: user.uid, mediaType, error: e.message });
        }
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onRemoteUserPublished === 'function') {
          try { window.agoraWeb.onRemoteUserPublished(String(user.uid), String(mediaType)); } catch (_) {}
        }
      });

      state.client.on('user-unpublished', (user, mediaType) => {
        window.agoraBridgeLog('INFO', 'Remote user unpublished', { uid: user.uid, mediaType });
        if (!user.videoTrack && !user.audioTrack) {
          state.activeAgoraUsers.delete(String(user.uid));
        }
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onRemoteUserUnpublished === 'function') {
          try { window.agoraWeb.onRemoteUserUnpublished(String(user.uid), String(mediaType)); } catch (_) {}
        }
      });

      state.client.on('user-left', (user) => {
        window.agoraBridgeLog('INFO', 'Remote user left', { uid: user.uid });
        state.activeAgoraUsers.delete(String(user.uid));
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onRemoteUserLeft === 'function') {
          try { window.agoraWeb.onRemoteUserLeft({ uid: String(user.uid) }); } catch (_) {}
        }
      });

      state.client.on('user-joined', (user) => {
        state.activeAgoraUsers.add(String(user.uid));
        const totalCount = state.activeAgoraUsers.size + 1;
        window.agoraBridgeLog('INFO', `Remote user joined uid=${user.uid} room_total=${totalCount}`);
        if (totalCount > 6) {
          window.agoraBridgeLog('WARN', `Beta room-size limit (6) reached — ${totalCount} participants`);
          if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onRoomFull === 'function') {
            try { window.agoraWeb.onRoomFull({ count: totalCount }); } catch (_) {}
          }
        }
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onRemoteUserJoined === 'function') {
          try { window.agoraWeb.onRemoteUserJoined(String(user.uid)); } catch (_) {}
        }
      });

      state.client.on('connection-state-change', async (curState, prevState) => {
        window.agoraBridgeLog('INFO', `Connection: ${prevState} → ${curState}`);
        state.connectionState = curState;
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onConnectionStateChange === 'function') {
          try { window.agoraWeb.onConnectionStateChange(curState, prevState); } catch (_) {}
        }
        if (curState === 'CONNECTED') {
          state.reconnecting = false;
          state.reconnectAttempts = 0;
        }
        if (curState === 'DISCONNECTED' && prevState === 'RECONNECTING' && state.currentChannel && !state.reconnecting) {
          window.agoraBridgeLog('WARN', 'SDK reconnect failed — triggering manual rejoin');
          agoraBridgeReconnect();
        }
      });

      state.client.on('token-privilege-will-expire', () => {
        window.agoraBridgeLog('INFO', 'Token expiring soon — requesting renewal');
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onTokenWillExpire === 'function') {
          try { window.agoraWeb.onTokenWillExpire(state.currentChannel, String(state.currentUid)); } catch (_) {}
        }
      });

      state.client.on('token-privilege-did-expire', async () => {
        window.agoraBridgeLog('WARN', 'Token expired — requesting renewal');
        if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onTokenWillExpire === 'function') {
          try { window.agoraWeb.onTokenWillExpire(state.currentChannel, String(state.currentUid)); } catch (_) {}
        }
        await new Promise(r => setTimeout(r, 3000));
        if (state.currentChannel && !state.reconnecting) agoraBridgeReconnect();
      });

      state.client.on('network-quality', (stats) => {
        state.networkQuality = { uplink: stats.uplinkNetworkQuality, downlink: stats.downlinkNetworkQuality };
        if (stats.uplinkNetworkQuality >= 4 || stats.downlinkNetworkQuality >= 4) {
          window.agoraBridgeLog('WARN', `Weak network — uplink=${stats.uplinkNetworkQuality} downlink=${stats.downlinkNetworkQuality}`);
          if (typeof window.agoraWeb !== 'undefined' && typeof window.agoraWeb.onNetworkQuality === 'function') {
            try { window.agoraWeb.onNetworkQuality({ uplink: stats.uplinkNetworkQuality, downlink: stats.downlinkNetworkQuality }); } catch (_) {}
          }
        }
      });

      state.appId = appId;
      state.initialized = true;
      window.agoraBridgeLog("SUCCESS", "Agora initialized successfully");
      return true;
    } catch (error) {
      state.lastError = error?.message || String(error);
      window.agoraBridgeLog('ERROR', 'Init failed', error);
      return false;
    }
  },

  // Join channel
  joinChannel: async function (token, channel, uid) {
    window.agoraBridgeLog("INFO", "joinChannel called", { channel, uid });
    const state = window.agoraBridgeState;

    if (!state.client || !state.initialized) {
      window.agoraBridgeLog("ERROR", "Must call init() before joinChannel()");
      return false;
    }

    try {
      state.lastError = null;
      const numericUid = parseInt(uid) || 0;
      await state.client.join(state.appId, channel, token || null, numericUid);
      state.currentChannel = channel;
      state.currentUid = numericUid;
      state.currentToken = token || null;
      state.connectionState = 'CONNECTED';
      state.reconnectAttempts = 0;
      window.agoraBridgeLog('SUCCESS', 'Joined channel', { channel, uid: numericUid });
      return true;
    } catch (error) {
      state.lastError = error?.message || String(error);
      window.agoraBridgeLog('ERROR', 'Join channel failed', error);
      return false;
    }
  },

  // Create camera track with optional device ID
  createCameraTrack: async function (deviceId) {
    const state = window.agoraBridgeState;

    if (!window.AgoraRTC) {
      window.agoraBridgeLog("ERROR", "Agora SDK not loaded");
      return false;
    }

    try {
      // Stop existing camera track
      if (state.localTracks.video) {
        state.localTracks.video.stop();
        state.localTracks.video.close();
        // Unpublish if in channel
        if (state.client && state.currentChannel) {
          try {
            await state.client.unpublish([state.localTracks.video]);
          } catch (e) {}
        }
      }

      state.currentVideoDeviceId = deviceId || state.currentVideoDeviceId;

      window.agoraBridgeLog("INFO", "Creating camera track...", {
        deviceId: state.currentVideoDeviceId,
      });

      const config = { encoderConfig: "720p_2" };
      if (state.currentVideoDeviceId) {
        config.cameraId = state.currentVideoDeviceId;
      }

      state.localTracks.video = await window.AgoraRTC.createCameraVideoTrack(config);

      // Auto-publish if in channel
      if (state.client && state.currentChannel) {
        await state.client.publish([state.localTracks.video]);
        window.agoraBridgeLog("SUCCESS", "Camera track published");
      }

      window.agoraBridgeLog("SUCCESS", "Camera track created");
      return true;
    } catch (error) {
      window.agoraBridgeLog("ERROR", "Failed to create camera track", error.message);
      return false;
    }
  },

  // Create microphone track with optional device ID
  createMicrophoneTrack: async function (deviceId) {
    const state = window.agoraBridgeState;

    if (!window.AgoraRTC) {
      window.agoraBridgeLog("ERROR", "Agora SDK not loaded");
      return false;
    }

    try {
      // Stop existing mic track
      if (state.localTracks.audio) {
        state.localTracks.audio.stop();
        state.localTracks.audio.close();
        // Unpublish if in channel
        if (state.client && state.currentChannel) {
          try {
            await state.client.unpublish([state.localTracks.audio]);
          } catch (e) {}
        }
      }

      state.currentMicDeviceId = deviceId || state.currentMicDeviceId;

      window.agoraBridgeLog("INFO", "Creating microphone track...", {
        deviceId: state.currentMicDeviceId,
      });

      const config = { encoderConfig: "speech_standard" };
      if (state.currentMicDeviceId) {
        config.microphoneId = state.currentMicDeviceId;
      }

      state.localTracks.audio = await window.AgoraRTC.createMicrophoneAudioTrack(config);

      // Auto-publish if in channel
      if (state.client && state.currentChannel) {
        await state.client.publish([state.localTracks.audio]);
        window.agoraBridgeLog("SUCCESS", "Microphone track published");
      }

      window.agoraBridgeLog("SUCCESS", "Microphone track created");
      return true;
    } catch (error) {
      window.agoraBridgeLog("ERROR", "Failed to create microphone track", error.message);
      return false;
    }
  },

  // Play camera in element
  playCamera: function (videoElementId) {
    const state = window.agoraBridgeState;
    if (state.localTracks.video) {
      let el = findElementByIdDeep(videoElementId);
      if (!el) {
        el = findAnyLocalVideoContainer();
      }
      if (el) {
        state.localTracks.video.play(el);
        el.style.display = "block";
        window.agoraBridgeLog("SUCCESS", "Camera playing in #" + videoElementId);
        return true;
      } else {
        window.agoraBridgeLog("WARN", "Element not found: " + videoElementId);
        return false;
      }
    }
    window.agoraBridgeLog("WARN", "No camera track to play");
    return false;
  },

  // Switch camera (alias)
  switchCamera: async function (deviceId) {
    return await this.createCameraTrack(deviceId);
  },

  // Switch mic (alias)
  switchMic: async function (deviceId) {
    return await this.createMicrophoneTrack(deviceId);
  },

  // Leave channel
  leaveChannel: async function () {
    window.agoraBridgeLog("INFO", "leaveChannel called");
    const state = window.agoraBridgeState;

    try {
      state.lastError = null;
      // Stop and close local tracks
      if (state.localTracks.audio) {
        state.localTracks.audio.stop();
        state.localTracks.audio.close();
        state.localTracks.audio = null;
      }
      if (state.localTracks.video) {
        state.localTracks.video.stop();
        state.localTracks.video.close();
        state.localTracks.video = null;
      }

      // Hide video container
      const localContainer = document.getElementById("video-container");
      if (localContainer) localContainer.style.display = "none";

      // Leave channel
      if (state.client && state.currentChannel) {
        await state.client.leave();
      }

      state.currentChannel = null;
      state.currentUid = null;
      state.activeAgoraUsers.clear();
      state.remoteVideoSubscriberElementId = null;
      state.pendingRemoteTracks = {};
      window.agoraBridgeLog('SUCCESS', 'Left channel');
      return true;
    } catch (error) {
      state.lastError = error?.message || String(error);
      window.agoraBridgeLog('ERROR', 'Leave channel failed', error);
      return false;
    }
  },

  // Get available devices
  getDevices: async function () {
    if (!window.AgoraRTC) {
      // Load SDK first
      await loadAgoraSDK();
    }

    try {
      const devices = await window.AgoraRTC.getDevices();
      window.agoraBridgeLog("SUCCESS", "Got devices", { count: devices.length });
      return devices.map((d) => ({
        deviceId: d.deviceId,
        label: d.label || d.deviceId.substring(0, 8) + "...",
        kind: d.kind,
      }));
    } catch (error) {
      window.agoraBridgeLog("ERROR", "getDevices failed", error);
      return [];
    }
  },

  // Mute/unmute mic
  setMicMuted: async function (muted) {
    const state = window.agoraBridgeState;
    if (!state.localTracks.audio && muted === false) {
      window.agoraBridgeLog('WARN', 'No mic track found while unmuting; creating one now');
      const created = await this.createMicrophoneTrack(state.currentMicDeviceId);
      if (!created) {
        window.agoraBridgeLog('ERROR', 'Failed to create mic track during unmute request');
        return false;
      }
    }

    if (state.localTracks.audio) {
      await state.localTracks.audio.setMuted(muted);
      window.agoraBridgeLog("SUCCESS", `Mic ${muted ? "muted" : "unmuted"}`);
      return true;
    }
    window.agoraBridgeLog('WARN', 'Mic track unavailable');
    return false;
  },

  // Toggle camera: fully release hardware when OFF, recreate track when ON
  setVideoMuted: async function(muted) {
    const state = window.agoraBridgeState;

    if (muted) {
      // Camera OFF: unpublish, stop, close, and release the physical webcam
      if (state.localTracks.video) {
        if (state.client && state.currentChannel) {
          try { await state.client.unpublish([state.localTracks.video]); } catch (e) {}
        }
        state.localTracks.video.stop();
        state.localTracks.video.close();
        state.localTracks.video = null;
        window.agoraBridgeLog('SUCCESS', 'Camera track released — webcam light OFF');
      }
      return true;
    } else {
      // Camera ON: if a track already exists, nothing to do
      if (state.localTracks.video) {
        window.agoraBridgeLog('INFO', 'Camera track already active, skipping recreate');
        return true;
      }
      // Recreate and publish a fresh camera track
      window.agoraBridgeLog('INFO', 'Creating new camera track on enable request');
      const created = await this.createCameraTrack(state.currentVideoDeviceId);
      if (!created) {
        window.agoraBridgeLog('ERROR', 'Failed to create camera track during enable request');
        return false;
      }
      // Best-effort: play in local video container if already mounted in DOM
      if (state.localTracks.video) {
        const localEl = findAnyLocalVideoContainer();
        if (localEl) {
          state.localTracks.video.play(localEl);
          window.agoraBridgeLog('SUCCESS', 'Local camera replayed in DOM container');
        }
      }
      return true;
    }
  },

  // Get state
  getState: function () {
    const state = window.agoraBridgeState;
    return {
      initialized: state.initialized,
      sdkLoaded: !!window.AgoraRTC,
      inChannel: !!state.currentChannel,
      currentChannel: state.currentChannel,
      currentUid: state.currentUid,
      hasAudio: !!state.localTracks.audio,
      hasVideo: !!state.localTracks.video,
      audioMuted: state.localTracks.audio?.muted ?? true,
      videoMuted: state.localTracks.video?.muted ?? true,
      viewerCount: state.activeAgoraUsers.size + 1,
      currentVideoDeviceId: state.currentVideoDeviceId,
      currentMicDeviceId: state.currentMicDeviceId,
      lastError: state.lastError
    };
  },

  // Register an element ID to receive the first remote user's video.
  // Can be called before or after the remote user publishes.
  // On call: immediately plays any pending remote track into the element.
  subscribeRemoteVideoTo: function (elementId) {
    window.agoraBridgeLog("INFO", "subscribeRemoteVideoTo", { elementId });
    const state = window.agoraBridgeState;
    state.remoteVideoSubscriberElementId = elementId;

    // Drain any pending remote tracks into the newly registered element
    const pendingUids = Object.keys(state.pendingRemoteTracks);
    if (pendingUids.length > 0) {
      const uid = pendingUids[0];
      const pending = state.pendingRemoteTracks[uid];
      const el = document.getElementById(elementId);
      if (el && pending.videoTrack) {
        pending.videoTrack.play(el);
        window.agoraBridgeLog("SUCCESS", "Drained pending remote video into #" + elementId, {
          uid,
        });
        delete state.pendingRemoteTracks[uid];
      }
    }
    return true;
  },

  // Renew the Agora token for the current channel session.
  // Call this before the current token expires (typically ~23h into a session).
  // Returns true on success, false if not in a channel or renewal fails.
  renewToken: function (newToken) {
    const state = window.agoraBridgeState;
    if (!state.client || !state.currentChannel) {
      window.agoraBridgeLog("WARN", "renewToken: not in a channel, skipping");
      return false;
    }
    try {
      state.client.renewToken(newToken);
      window.agoraBridgeLog("SUCCESS", "Token renewed for channel: " + state.currentChannel);
      return true;
    } catch (e) {
      window.agoraBridgeLog("ERROR", "renewToken failed", e);
      return false;
    }
  },
};

// ========== FLAT STYLE API (for backward compatibility) ==========

window.agoraWebInit = async function (appId) {
  return await window.agoraWebBridge.init(appId);
};

window.agoraWebJoinChannel = async function (appId, channelName, token, uid) {
  if (!window.agoraBridgeState.initialized) {
    const initResult = await window.agoraWebBridge.init(appId);
    if (!initResult) return false;
  }
  return await window.agoraWebBridge.joinChannel(token, channelName, uid);
};

window.agoraWebLeaveChannel = async function () {
  return await window.agoraWebBridge.leaveChannel();
};

window.agoraWebSetMicMuted = async function (muted) {
  return await window.agoraWebBridge.setMicMuted(muted);
};

window.agoraWebSetVideoMuted = async function (muted) {
  return await window.agoraWebBridge.setVideoMuted(muted);
};

window.agoraWebPlayCamera = async function(videoElementId) {
  return await window.agoraWebBridge.playCamera(videoElementId);
};

window.agoraWebGetState = function() {
  return window.agoraWebBridge.getState();
};

window.agoraWebRenewToken = async function(newToken) {
  return await window.agoraWebBridge.renewToken(newToken);
};

// ========== RECONNECT HELPER ==========
async function agoraBridgeReconnect() {
  const state = window.agoraBridgeState;
  if (state.reconnecting || !state.currentChannel || !state.appId) return;
  const MAX_ATTEMPTS = 3;
  if (state.reconnectAttempts >= MAX_ATTEMPTS) {
    window.agoraBridgeLog('ERROR', 'Max reconnect attempts reached');
    return;
  }
  state.reconnecting = true;
  state.reconnectAttempts += 1;
  const delay = state.reconnectAttempts * 2000;
  window.agoraBridgeLog('INFO', `Reconnect attempt ${state.reconnectAttempts}/${MAX_ATTEMPTS} in ${delay}ms`);
  await new Promise(r => setTimeout(r, delay));
  if (!state.currentChannel) { state.reconnecting = false; return; }
  try {
    await state.client.join(state.appId, state.currentChannel, state.currentToken || null, state.currentUid);
    window.agoraBridgeLog('SUCCESS', 'Reconnected to channel');
    const tracks = [];
    if (state.localTracks.audio) tracks.push(state.localTracks.audio);
    if (state.localTracks.video) tracks.push(state.localTracks.video);
    if (tracks.length > 0) {
      try { await state.client.publish(tracks); }
      catch (e) { window.agoraBridgeLog('ERROR', 'Re-publish after reconnect failed', e.message); }
    }
    state.reconnecting = false;
    state.reconnectAttempts = 0;
  } catch (err) {
    window.agoraBridgeLog('ERROR', 'Reconnect failed', err.message);
    state.reconnecting = false;
    agoraBridgeReconnect();
  }
}

// ========== BROWSER UNLOAD HANDLING ==========
// Release the Agora slot on tab close / navigation so the server-side
// participant count decrements promptly.
if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', function () {
    const state = window.agoraBridgeState;
    if (state.currentChannel) {
      state.activeAgoraUsers.clear();
      try { if (state.localTracks.audio) { state.localTracks.audio.close(); state.localTracks.audio = null; } } catch (_) {}
      try { if (state.localTracks.video) { state.localTracks.video.stop(); state.localTracks.video.close(); state.localTracks.video = null; } } catch (_) {}
      try { state.client.leave(); } catch (_) {}
      state.currentChannel = null;
    }
  });
}

// ========== READY SIGNAL ==========

window.agoraBridgeReady = true;
window.agoraBridgeLog("SUCCESS", "Agora Bridge loaded and ready");

// ========== TAB VISIBILITY AUTO-MUTE ==========
// When the user hides this browser tab, pause local tracks to conserve
// bandwidth and CPU. Restore when the tab becomes visible again.
// Mirrors the AppLifecycleState.paused handling used on mobile.
if (typeof document !== "undefined") {
  document.addEventListener("visibilitychange", async function () {
    const state = window.agoraBridgeState;
    if (!state.currentChannel) return; // Not in a channel — nothing to do

    if (document.hidden) {
      window.agoraBridgeLog("INFO", "Tab hidden — muting local tracks");
      try {
        if (state.localTracks.audio) await state.localTracks.audio.setMuted(true);
        if (state.localTracks.video) await state.localTracks.video.setMuted(true);
      } catch (e) {
        window.agoraBridgeLog("WARN", "Failed to mute on tab hide: " + e.message);
      }
    } else {
      window.agoraBridgeLog("INFO", "Tab visible — unmuting local tracks");
      try {
        if (state.localTracks.audio) await state.localTracks.audio.setMuted(false);
        if (state.localTracks.video) await state.localTracks.video.setMuted(false);
      } catch (e) {
        window.agoraBridgeLog("WARN", "Failed to unmute on tab show: " + e.message);
      }
    }
  });
}

// Debug helper
window.agoraDebug = function () {
  console.table(window.agoraWebGetState());
};
