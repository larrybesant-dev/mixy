import express from 'express';
import path from 'path';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import { createServer as createViteServer } from 'vite';
import { GoogleGenAI, GenerateVideosOperation } from '@google/genai';

const getGenAIClient = () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is required for Veo video generation');
  }
  return new GoogleGenAI({
    apiKey,
    httpOptions: {
      headers: {
        'User-Agent': 'aistudio-build',
      },
    },
  });
};

type ApiErrorCode =
  | 'BAD_REQUEST'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'VALIDATION_ERROR'
  | 'RATE_LIMITED'
  | 'INSUFFICIENT_FUNDS'
  | 'INTERNAL_ERROR';

type ApiError = {
  code: ApiErrorCode;
  message: string;
  details?: Record<string, unknown>;
};

type ApiSuccess<T> = { ok: true; data: T };
type ApiFailure = { ok: false; error: ApiError };
type ApiResponse<T> = ApiSuccess<T> | ApiFailure;

type AuthenticatedRequest = {
  user?: { id: string; handle: string };
  header?: (name: string) => string | undefined;
  body?: any;
  params?: any;
};

const DEV_API_TOKEN = process.env.DEV_API_TOKEN ?? 'mixvy-dev-token';

let userProfile = {
  id: 'usr_1',
  name: 'Larry Besant',
  handle: '@Larrybesant',
  diamonds: 8500,
  crowns: 12,
  followers: 420,
  following: 88,
  totalLikes: 1350,
  speedMatches: 14,
  avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
  vipStatus: 'GREEN KEY ADMIN',
  bio: 'Stage host, music streamer & crypto enthusiast.',
  photos: [] as string[],
};

const userProfiles: Record<string, typeof userProfile> = {
  usr_1: userProfile,
};

function ok<T>(res: any, data: T, status = 200): ApiResponse<T> {
  return res.status(status).json({ ok: true, data });
}

function fail(
  res: any,
  status: number,
  code: ApiErrorCode,
  message: string,
  details?: Record<string, unknown>
): ApiFailure {
  return res.status(status).json({ ok: false, error: { code, message, details } });
}

function requireAuth(req: AuthenticatedRequest, res: any, next: any) {
  const auth = req.header('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length) : '';

  if (!token) {
    return fail(res, 401, 'UNAUTHORIZED', 'Missing bearer token');
  }

  if (token !== DEV_API_TOKEN) {
    return fail(res, 401, 'UNAUTHORIZED', 'Invalid bearer token');
  }

  const userId = req.header('x-user-id') || 'usr_1';
  const userNameHeader = req.header('x-user-name');

  if (!userProfiles[userId]) {
    const defaultName = userNameHeader || (userId === 'usr_1' ? 'Larry Besant' : 'Dcr Curve');
    const handle = '@' + defaultName.toLowerCase().replace(/[^a-z0-9]+/g, '');

    userProfiles[userId] = {
      id: userId,
      name: defaultName,
      handle: handle,
      diamonds: 8500,
      crowns: 12,
      followers: 420,
      following: 88,
      totalLikes: 1350,
      speedMatches: 14,
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      vipStatus: 'GREEN KEY ADMIN',
      bio: 'Stage host, music streamer & crypto enthusiast.',
      photos: [],
    };
  } else if (userNameHeader && userProfiles[userId].name !== userNameHeader) {
    userProfiles[userId].name = userNameHeader;
    userProfiles[userId].handle = '@' + userNameHeader.toLowerCase().replace(/[^a-z0-9]+/g, '');
  }

  req.user = { id: userId, handle: userProfiles[userId].handle };
  next();
}

async function startServer() {
  const app = express();
  const PORT = 3000;

  (app as any).use(express.json({ limit: '50mb' }));

  const httpServer = http.createServer(app);
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  io.on('connection', (socket) => {
    socket.on('room:join', (roomId: string) => {
      if (roomId) socket.join(`room:${roomId}`);
    });

    socket.on('room:leave', (roomId: string) => {
      if (roomId) socket.leave(`room:${roomId}`);
    });
  });

  // In-memory server state
  let fiatBalance = 0;

  const walletHistory: Array<{
    id: string;
    action: 'add' | 'spend';
    amount: number;
    balanceAfter: number;
    at: string;
  }> = [];

  let roomsList: Array<{
    id: string;
    title: string;
    streamerName: string;
    streamerAvatar: string;
    viewerCount: number;
    tag: string;
    isVIP?: boolean;
    category: string;
    isMultiMic?: boolean;
    isVIPOnly?: boolean;
    isFeatured?: boolean;
    thumbnail: string;
  }> = [
    {
      id: 'room-1',
      title: 'VIP Multi-Mic Stage & Beats Jam',
      streamerName: 'Larry Besant',
      streamerAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      viewerCount: 1420,
      tag: 'Multi-Mic Stage',
      category: 'Multi-Mic Stage',
      isMultiMic: true,
      isVIPOnly: false,
      isFeatured: true,
      thumbnail: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    },
    {
      id: 'room-2',
      title: 'Cyberpunk Synthwave & Lofi Station',
      streamerName: 'Neon Pulse',
      streamerAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
      viewerCount: 856,
      tag: 'Music & Audio Jam',
      category: 'Music & Audio Jam',
      isMultiMic: true,
      isVIPOnly: false,
      isFeatured: false,
      thumbnail: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80',
    },
    {
      id: 'room-3',
      title: 'AI & WebRTC Future Debate',
      streamerName: 'Devon Miles',
      streamerAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
      viewerCount: 412,
      tag: 'Debate & Talk',
      category: 'Debate & Talk',
      isMultiMic: true,
      isVIPOnly: true,
      isFeatured: false,
      thumbnail: 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800&auto=format&fit=crop&q=80',
    },
    {
      id: 'room-4',
      title: 'Late Night Speed Dating & Lounge',
      streamerName: 'Aria Rose',
      streamerAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&auto=format&fit=crop&q=80',
      viewerCount: 689,
      tag: 'Speed Dating',
      category: 'Speed Dating',
      isMultiMic: true,
      isVIPOnly: false,
      isFeatured: false,
      thumbnail: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&auto=format&fit=crop&q=80',
    },
  ];

  let socialPostsList: Array<{
    id: string;
    author: string;
    authorName: string;
    authorHandle: string;
    authorAvatar: string;
    content: string;
    mediaUrl?: string;
    likes: number;
    comments: number;
    commentsCount?: number;
    sharesCount?: number;
    time: string;
    timestamp: string;
    isLiked?: boolean;
    authorLevel?: string;
    authorClan?: string;
  }> = [];

  let socialFeedDiscovery = {
    clips: [] as Array<{ id: string; handle: string; thumbnail: string; isLive?: boolean }>,
    communities: [
      { id: 'comm-1', name: 'Gaming', activeCount: 'Live Hub', icon: 'sports_esports', isJoined: true },
      { id: 'comm-2', name: 'Tech', activeCount: 'Live Hub', icon: 'memory' },
      { id: 'comm-3', name: 'Music', activeCount: 'Live Hub', icon: 'music_note' },
      { id: 'comm-4', name: 'Chat', activeCount: 'Live Hub', icon: 'forum' },
    ],
    friends: [] as Array<{ id: string; name: string; avatar: string; reason: string; isOnline: boolean }>,
  };

  let speedDatingProfilePool: Array<{
    id: string;
    name: string;
    username: string;
    age: number;
    location: string;
    role: string;
    avatar: string;
    videoBg: string;
    bio: string;
    rank: string;
    lifetimeWins: number;
  }> = [];

  let speedDatingRecentConnections: Array<{
    id: string;
    name: string;
    avatar: string;
    type: 'mutual' | 'missed' | 'super';
    timeAgo: string;
  }> = [];

  let afterDarkRoomsList: Array<{
    id: string;
    title: string;
    streamerName: string;
    streamerHandle: string;
    streamerAvatar: string;
    viewers: number;
    description: string;
    isDiamondOnly?: boolean;
    thumbnail: string;
  }> = [];

  let roomChatMessages: Record<string, Array<{ id: string; sender: string; text: string; timestamp: string; isGift?: boolean; amount?: number; isSeen?: boolean }>> = {};

  let micQueues: Record<string, string[]> = {};

  // Admin Data Management
  app.post('/api/admin/clear-fake-data', requireAuth, (_req, res) => {
    socialPostsList = [];
    roomsList = [];
    afterDarkRoomsList = [];
    speedDatingProfilePool = [];
    speedDatingRecentConnections = [];
    socialFeedDiscovery.clips = [];
    socialFeedDiscovery.friends = [];
    roomChatMessages = {};
    micQueues = {};
    walletHistory.length = 0;

    io.emit('data:reset', { at: new Date().toISOString() });

    return ok(res, {
      message: 'All fake posts, placeholder accounts, message logs, and sample data cleared for live real user tracking.',
      postsRemaining: socialPostsList.length,
      roomsReset: roomsList.length,
    });
  });

  // Public routes
  app.get('/api/health', (_req, res) => {
    return ok(res, {
      status: 'ok',
      serverTime: new Date().toISOString(),
      uptime: process.uptime(),
      realtime: true,
    });
  });

  const enableLegacyVeoRoutes = process.env.ENABLE_LEGACY_VEO_ROUTES === 'true';

  if (enableLegacyVeoRoutes) {
    // Legacy local Veo routes retained for explicit local dev fallback only.
    app.post('/api/generate-video', requireAuth, async (req, res) => {
      try {
        const { imageBase64, mimeType, prompt, aspectRatio } = req.body as {
          imageBase64: string;
          mimeType?: string;
          prompt?: string;
          aspectRatio?: '16:9' | '9:16';
        };

        if (!imageBase64) {
          return fail(res, 400, 'BAD_REQUEST', 'Image base64 data is required for video animation');
        }

        const cleanBase64 = imageBase64.includes(',')
          ? imageBase64.split(',')[1]
          : imageBase64;

        const ai = getGenAIClient();
        const targetAspectRatio = aspectRatio === '9:16' ? '9:16' : '16:9';

        const operation = await ai.models.generateVideos({
          model: 'veo-3.1-fast-generate-preview',
          prompt: prompt || 'Animate this image with cinematic motion and realistic lighting',
          image: {
            imageBytes: cleanBase64,
            mimeType: mimeType || 'image/png',
          },
          config: {
            numberOfVideos: 1,
            aspectRatio: targetAspectRatio,
            resolution: '720p',
          },
        });

        return ok(res, { operationName: operation.name, status: 'processing' });
      } catch (err: any) {
        console.error('[Veo Video Generation Error]:', err);
        return fail(res, 500, 'INTERNAL_ERROR', err?.message || 'Failed to start video generation');
      }
    });

    app.post('/api/video-status', requireAuth, async (req, res) => {
      try {
        const { operationName } = req.body as { operationName: string };
        if (!operationName) {
          return fail(res, 400, 'BAD_REQUEST', 'operationName is required');
        }

        const ai = getGenAIClient();
        const op = new GenerateVideosOperation();
        op.name = operationName;

        const updated = await ai.operations.getVideosOperation({ operation: op });
        return ok(res, {
          done: updated.done,
          error: updated.error,
        });
      } catch (err: any) {
        console.error('[Veo Status Check Error]:', err);
        return fail(res, 500, 'INTERNAL_ERROR', err?.message || 'Failed to check video status');
      }
    });

    app.post('/api/video-download', requireAuth, async (req, res) => {
      try {
        const { operationName } = req.body as { operationName: string };
        if (!operationName) {
          return fail(res, 400, 'BAD_REQUEST', 'operationName is required');
        }

        const ai = getGenAIClient();
        const op = new GenerateVideosOperation();
        op.name = operationName;

        const updated = await ai.operations.getVideosOperation({ operation: op });
        const uri = updated.response?.generatedVideos?.[0]?.video?.uri;

        if (!uri) {
          return fail(res, 404, 'NOT_FOUND', 'Generated video URI not ready or available');
        }

        const apiKey = process.env.GEMINI_API_KEY || '';
        const videoRes = await fetch(uri, {
          headers: { 'x-goog-api-key': apiKey },
        });

        if (!videoRes.ok) {
          return fail(res, 500, 'INTERNAL_ERROR', 'Failed to fetch video stream from storage provider');
        }

        res.setHeader('Content-Type', 'video/mp4');
        const arrayBuffer = await videoRes.arrayBuffer();
        res.send(Buffer.from(arrayBuffer));
      } catch (err: any) {
        console.error('[Veo Download Error]:', err);
        return fail(res, 500, 'INTERNAL_ERROR', err?.message || 'Failed to stream video file');
      }
    });
  } else {
    const legacyDisabledMessage =
      'Legacy Veo /api routes are disabled. Use Firebase Functions Veo endpoints via VITE_VEO_FUNCTIONS_BASE_URL or set ENABLE_LEGACY_VEO_ROUTES=true for local fallback.';

    app.post('/api/generate-video', requireAuth, (_req, res) =>
      fail(res, 410, 'BAD_REQUEST', legacyDisabledMessage),
    );

    app.post('/api/video-status', requireAuth, (_req, res) =>
      fail(res, 410, 'BAD_REQUEST', legacyDisabledMessage),
    );

    app.post('/api/video-download', requireAuth, (_req, res) =>
      fail(res, 410, 'BAD_REQUEST', legacyDisabledMessage),
    );
  }

  // Protected API routes
  app.get('/api/user', requireAuth, (req, res) => {
    const userId = req.user?.id || 'usr_1';
    return ok(res, userProfiles[userId] || userProfile);
  });

  app.patch('/api/user', requireAuth, (req, res) => {
    const userId = req.user?.id || 'usr_1';
    const profile = userProfiles[userId] || userProfile;
    const updates = req.body as Partial<typeof userProfile>;
    if (updates.name) profile.name = updates.name;
    if (updates.bio) profile.bio = updates.bio;
    if (updates.handle) profile.handle = updates.handle;
    if (updates.avatar) profile.avatar = updates.avatar;
    if (updates.photos) profile.photos = updates.photos;
    if (updates.diamonds !== undefined) profile.diamonds = updates.diamonds;
    return ok(res, profile);
  });

  // Rooms API
  app.get('/api/rooms', requireAuth, (_req, res) => {
    return ok(res, roomsList);
  });

  app.post('/api/rooms', requireAuth, (req, res) => {
    const { title, category, isMultiMic } = req.body as { title?: string; category?: string; isMultiMic?: boolean };
    const newRoom = {
      id: `room-${Date.now()}`,
      title: title || 'New Live Stage',
      streamerName: userProfile.name,
      streamerAvatar: userProfile.avatar,
      viewerCount: 1,
      tag: category || 'General',
      isVIP: false,
      category: category || 'Multi-Mic Stage',
      isMultiMic: !!isMultiMic,
      isVIPOnly: false,
      isFeatured: false,
      thumbnail: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    };
    roomsList.unshift(newRoom);
    return ok(res, newRoom, 201);
  });

  // Social Feed Posts API
  app.get('/api/posts', requireAuth, (_req, res) => {
    return ok(res, socialPostsList);
  });

  app.post('/api/posts', requireAuth, (req, res) => {
    const { content, mediaUrl, isVideo } = req.body as { content?: string; mediaUrl?: string; isVideo?: boolean };
    if ((!content || !content.trim()) && !mediaUrl) {
      return fail(res, 400, 'BAD_REQUEST', 'Content or media file is required');
    }
    const newPost = {
      id: `p_${Date.now()}`,
      author: userProfile.name,
      authorName: userProfile.name,
      authorHandle: userProfile.handle,
      authorAvatar: userProfile.avatar,
      content: content ? content.trim() : '',
      mediaUrl: mediaUrl || undefined,
      isVideo: Boolean(isVideo),
      likes: 1,
      comments: 0,
      commentsCount: 0,
      sharesCount: 0,
      time: 'Just now',
      timestamp: 'Just now',
      isLiked: true,
      authorLevel: 'LEVEL 14',
      authorClan: 'GREEN KEY',
    };
    socialPostsList.unshift(newPost);
    return ok(res, newPost, 201);
  });

  app.post('/api/posts/:postId/like', requireAuth, (req, res) => {
    const { postId } = req.params;
    const post = socialPostsList.find((p) => p.id === postId);
    if (!post) {
      return fail(res, 404, 'NOT_FOUND', 'Post not found');
    }
    post.isLiked = !post.isLiked;
    post.likes += post.isLiked ? 1 : -1;
    return ok(res, { postId: post.id, likes: post.likes, isLiked: post.isLiked });
  });

  app.get('/api/social-feed/discovery', requireAuth, (_req, res) => {
    return ok(res, socialFeedDiscovery);
  });

  app.post('/api/social-feed/clips', requireAuth, (req, res) => {
    const { thumbnail, handle } = req.body as { thumbnail?: string; handle?: string };
    if (!thumbnail) {
      return fail(res, 400, 'BAD_REQUEST', 'Thumbnail / video URL is required');
    }
    const newClip = {
      id: `clip_${Date.now()}`,
      handle: handle || userProfile.handle,
      thumbnail,
      isLive: false,
    };
    socialFeedDiscovery.clips.unshift(newClip);
    return ok(res, newClip, 201);
  });

  // Speed Dating API
  app.get('/api/speed-dating/status', requireAuth, (_req, res) => {
    const currentMatch = speedDatingProfilePool[0];
    if (!currentMatch) {
      return ok(res, {
        status: 'idle',
        partnerName: null,
        partnerAvatar: null,
        partnerBio: null,
        roundTimerSeconds: 0,
        sessionTimeSeconds: 0,
        currentProfile: null,
        recentConnections: speedDatingRecentConnections,
        openingMessages: [],
      });
    }
    return ok(res, {
      status: 'matched',
      partnerName: currentMatch.name,
      partnerAvatar: currentMatch.avatar,
      partnerBio: currentMatch.bio,
      roundTimerSeconds: 180,
      sessionTimeSeconds: 0,
      currentProfile: currentMatch,
      recentConnections: speedDatingRecentConnections,
      openingMessages: [
        {
          id: 'm1',
          sender: currentMatch.name,
          senderType: 'partner',
          text: '"Hi! Nice to meet you in speed dating."',
          timestamp: 'Just now',
        },
      ],
    });
  });

  app.post('/api/speed-dating/queue', requireAuth, (_req, res) => {
    return ok(res, {
      status: 'searching',
      roundTimerSeconds: 180,
    });
  });

  // After Dark API
  app.get('/api/after-dark/rooms', requireAuth, (_req, res) => {
    return ok(res, afterDarkRoomsList);
  });

  app.post('/api/after-dark/rooms', requireAuth, (req, res) => {
    const { title, category, description, isDiamondOnly, thumbnail } = req.body as {
      title?: string;
      category?: string;
      description?: string;
      isDiamondOnly?: boolean;
      thumbnail?: string;
    };

    if (!title || !title.trim()) {
      return fail(res, 400, 'BAD_REQUEST', 'title is required');
    }

    const newRoom = {
      id: `ad_${Date.now()}`,
      title: title.trim(),
      streamerName: userProfile.name,
      streamerHandle: userProfile.handle,
      streamerAvatar: userProfile.avatar,
      viewers: 1,
      isLive: true,
      description: description?.trim() || 'Exclusive private room stage.',
      category: category || 'VIP Lounges',
      isDiamondOnly: !!isDiamondOnly,
      thumbnail:
        thumbnail ||
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&auto=format&fit=crop&q=80',
    };

    afterDarkRoomsList.unshift(newRoom);

    io.emit('after-dark:room:created', newRoom);

    return ok(res, newRoom, 201);
  });

  app.post('/api/user/diamonds', requireAuth, (req, res) => {
    const { amount, action } = req.body as { amount?: number; action?: 'add' | 'spend' };
    const normalized = Number(amount) || 0;

    if (!action || normalized <= 0) {
      return fail(res, 400, 'BAD_REQUEST', 'action and positive amount are required');
    }

    if (action === 'add') {
      userProfile.diamonds += normalized;
    }

    if (action === 'spend') {
      if (userProfile.diamonds < normalized) {
        return fail(res, 400, 'INSUFFICIENT_FUNDS', 'Insufficient diamonds balance');
      }
      userProfile.diamonds -= normalized;
    }

    walletHistory.unshift({
      id: `txn_${Date.now()}`,
      action,
      amount: normalized,
      balanceAfter: userProfile.diamonds,
      at: new Date().toISOString(),
    });

    io.emit('wallet:balance:updated', {
      userId: userProfile.id,
      diamonds: userProfile.diamonds,
      crowns: userProfile.crowns,
      at: new Date().toISOString(),
    });

    return ok(res, { success: true, diamonds: userProfile.diamonds });
  });

  app.get('/api/wallet', requireAuth, (_req, res) => {
    return ok(res, {
      userId: userProfile.id,
      balance: fiatBalance,
      diamonds: userProfile.diamonds,
      crowns: userProfile.crowns,
      currency: 'USD',
      updatedAt: new Date().toISOString(),
    });
  });

  app.post('/api/wallet/deposit', requireAuth, (req, res) => {
    const { amount } = req.body as { amount?: number };
    const normalized = Number(amount) || 0;

    if (normalized <= 0) {
      return fail(res, 400, 'BAD_REQUEST', 'Positive amount is required');
    }

    fiatBalance += normalized;
    walletHistory.unshift({
      id: `dep_${Date.now()}`,
      action: 'add',
      amount: normalized,
      balanceAfter: fiatBalance,
      at: new Date().toISOString(),
    });

    return ok(res, { success: true, balance: fiatBalance });
  });

  app.get('/api/wallet/history', requireAuth, (_req, res) => {
    return ok(res, { items: walletHistory.slice(0, 100) });
  });

  app.get('/api/rooms/:roomId/messages', requireAuth, (req, res) => {
    const { roomId } = req.params;
    return ok(res, roomChatMessages[roomId] || []);
  });

  app.post('/api/rooms/:roomId/messages/seen', requireAuth, (req, res) => {
    const { roomId } = req.params;
    const msgs = roomChatMessages[roomId] || [];
    let updatedCount = 0;
    msgs.forEach((m) => {
      if (!m.isSeen) {
        m.isSeen = true;
        (m as any).seenAt = new Date().toISOString();
        updatedCount++;
      }
    });

    if (updatedCount > 0) {
      io.to(`room:${roomId}`).emit('room:messages:seen', {
        roomId,
        seenAt: new Date().toISOString(),
      });
    }

    return ok(res, { success: true, updatedCount });
  });

  app.post('/api/rooms/:roomId/messages', requireAuth, (req, res) => {
    const { roomId } = req.params;
    const { sender, text, isGift, amount } = req.body as {
      sender?: string;
      text?: string;
      isGift?: boolean;
      amount?: number;
    };

    if (!text || !text.trim()) {
      return fail(res, 400, 'BAD_REQUEST', 'text is required');
    }

    if (!roomChatMessages[roomId]) {
      roomChatMessages[roomId] = [];
    }

    const newMessage = {
      id: `msg_${Date.now()}`,
      sender: sender || userProfile.name,
      text: text.trim(),
      isGift: !!isGift,
      amount,
      isSeen: false,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    roomChatMessages[roomId].push(newMessage);

    io.to(`room:${roomId}`).emit('room:message:new', {
      roomId,
      message: newMessage,
    });

    return ok(res, newMessage, 201);
  });

  app.get('/api/rooms/:roomId/mic-queue', requireAuth, (req, res) => {
    const { roomId } = req.params;
    return ok(res, micQueues[roomId] || []);
  });

  app.post('/api/rooms/:roomId/raise-hand', requireAuth, (req, res) => {
    const { roomId } = req.params;
    const { userName } = req.body as { userName?: string };

    if (!micQueues[roomId]) {
      micQueues[roomId] = [];
    }

    const user = userName || userProfile.name;
    if (!micQueues[roomId].includes(user)) {
      micQueues[roomId].push(user);
    }

    io.to(`room:${roomId}`).emit('room:queue:updated', {
      roomId,
      queue: micQueues[roomId],
      at: new Date().toISOString(),
    });

    return ok(res, { success: true, queue: micQueues[roomId] });
  });

  let roomStageSpeakers: Record<string, Array<{ id: string; name: string; avatar: string; role: string; isMuted: boolean; isSpeaking: boolean; isCameraOff: boolean }>> = {};

  app.get('/api/rooms/:roomId/stage', requireAuth, (req, res) => {
    const { roomId } = req.params;
    const stage = roomStageSpeakers[roomId] || [];
    return ok(res, stage);
  });

  app.post('/api/rooms/:roomId/stage/join', requireAuth, (req, res) => {
    const { roomId } = req.params;
    const userId = req.user?.id || 'usr_1';
    const currentUser = userProfiles[userId] || userProfile;
    const room = roomsList.find((r) => r.id === roomId);
    const streamerName = room?.streamerName || 'Larry Besant';

    if (!roomStageSpeakers[roomId]) {
      roomStageSpeakers[roomId] = [
        { id: 'm1', name: streamerName, avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80', role: 'ROOM OWNER / MAIN MIC', isMuted: false, isSpeaking: true, isCameraOff: false },
        { id: 'm3', name: 'Hiroshi_Beat', avatar: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDDBc_mBoaMZD_7ZQuS8KtK7H2rJle_lYi_nNr8RUSgdcRrq-S_2XlXzk24-rZ4diNMCDNNMaNmTOvlYxxo6SI1sNNUPhTKc9OxPz1aiOwHtBgoCNW2SwYkI5GzJJU9ZKxrC3OLFAJLVUR5YKKf78Txw4l811QE3oIRtrDl_aMRxv9wr_SCEfd5EYdCpWPUQwmawY_hVcqZlNL3n9Ei6TGkpMKSfaKGCDsEWBsE2_Q5OVWEdXFgGCRLdw', role: 'ADMIN KEY 🔑', isMuted: false, isSpeaking: false, isCameraOff: false },
        { id: 'm4', name: 'CyberNova', avatar: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC4dh12YKLlH4Q0BJ7XVVfViY2Bsh2EhAXxFRuCjRk05DsMF7YCdyOgX-Y5Blu-XWezlEsIr7plbz44xf-7RzIHJ9jqqZE3Zycm3zfyY9ZQ37bHs-bum1J880X443g1Q2Clucxmxjaa3_EAeXj7KQ4Bb8h_Ht01LEsNLMPDmMetNwiqC6TXOdb6TLSpTEFOFQMeC2L6HoU9Es5hOIdp1-jqfSh4E4F1rAtKsyGVZNN6qr-mEupAcDPKZA', role: 'VIP SPEAKER', isMuted: true, isSpeaking: false, isCameraOff: true },
      ];
    }

    const stage = roomStageSpeakers[roomId];
    const existingIdx = stage.findIndex((s) => s.name === currentUser.name || s.id === userId);

    if (existingIdx >= 0) {
      stage[existingIdx].avatar = currentUser.avatar || stage[existingIdx].avatar;
    } else {
      if (currentUser.name === streamerName) {
        stage[0].name = currentUser.name;
        stage[0].avatar = currentUser.avatar || stage[0].avatar;
      } else {
        stage.splice(1, 0, {
          id: `m2_${userId}`,
          name: currentUser.name,
          avatar: currentUser.avatar || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
          role: 'GUEST MIC',
          isMuted: false,
          isSpeaking: true,
          isCameraOff: false,
        });
      }
    }

    return ok(res, stage);
  });

  // Vite middleware for development vs production
  if (process.env.NODE_ENV !== 'production') {
    const appUrl = process.env.APP_URL || '';
    const disableHmrInPreview =
      process.env.DISABLE_HMR === 'true' ||
      appUrl.includes('.run.app') ||
      appUrl.includes('aistudio');

    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        hmr: disableHmrInPreview ? false : undefined,
        watch: disableHmrInPreview ? null : undefined,
      },
      appType: 'spa',
    });

    if (disableHmrInPreview) {
      console.log('[Vite] HMR disabled for preview runtime.');
    }

    (app as any).use(vite.middlewares as any);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    (app as any).use(express.static(distPath));
    (app as any).get('*', (_req: any, res: any) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  (app as any).use((err: unknown, _req: any, res: any, _next: any) => {
    console.error('[api-error]', err);
    return fail(res, 500, 'INTERNAL_ERROR', 'Unexpected server error');
  });

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`[Express Backend Server] Running on http://0.0.0.0:${PORT}`);
    console.log('[Auth] Use Bearer token:', DEV_API_TOKEN);
  });
}

startServer();
