import { ApiResponse, MessageThread } from '../types';
import {
  auth,
  db,
  functions,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  collectionGroup,
  query,
  getDocs,
  orderBy,
  limit,
  where,
  addDoc,
  serverTimestamp,
  increment,
  arrayUnion,
  arrayRemove,
  httpsCallable,
} from './firebase';

const DEV_API_TOKEN = 'mixvy-dev-token';
const API_BASE_URL =
  ((import.meta as any).env?.VITE_API_BASE_URL as string | undefined)?.replace(/\/+$/, '') || '';

function okData<T>(data: T): ApiResponse<T> {
  return { ok: true, data };
}

function failData<T>(message: string): ApiResponse<T> {
  return {
    ok: false,
    error: {
      code: 'INTERNAL_ERROR',
      message,
    },
  };
}

export function getClientId(): string {
  if (typeof localStorage === 'undefined') return 'usr_1';
  let id = localStorage.getItem('mixvy_client_id');
  if (!id) {
    id = 'usr_' + Math.random().toString(36).substring(2, 9);
    localStorage.setItem('mixvy_client_id', id);
  }
  return id;
}

export function getStoredUserName(): string | null {
  if (typeof localStorage === 'undefined') return null;
  return localStorage.getItem('mixvy_user_name');
}

export function setStoredUserName(name: string): void {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('mixvy_user_name', name);
  }
}

export function apiGetToken(): string {
  return DEV_API_TOKEN;
}

function isLocalDevHost(): boolean {
  if (typeof window === 'undefined') {
    return true;
  }

  const { hostname } = window.location;
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '0.0.0.0';
}

function shouldUseLocalApiFallback(): boolean {
  return isLocalDevHost();
}

function resolveApiUrl(endpoint: string): string {
  if (/^https?:\/\//i.test(endpoint)) {
    return endpoint;
  }

  if (!API_BASE_URL) {
    return endpoint;
  }

  return `${API_BASE_URL}/${endpoint.replace(/^\/+/, '')}`;
}

function buildApiHeaders(headersInit?: HeadersInit, hasStringBody?: boolean): Headers {
  const headers = new Headers(headersInit || {});
  if (!headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${DEV_API_TOKEN}`);
  }
  if (!headers.has('x-user-id')) {
    headers.set('x-user-id', getClientId());
  }
  const storedName = getStoredUserName();
  if (storedName && !headers.has('x-user-name')) {
    headers.set('x-user-name', storedName);
  }
  if (!headers.has('Content-Type') && hasStringBody) {
    headers.set('Content-Type', 'application/json');
  }
  return headers;
}

const VEO_FUNCTIONS_BASE_URL =
  ((globalThis as { __MIXVY_VEO_FUNCTIONS_BASE_URL?: string }).__MIXVY_VEO_FUNCTIONS_BASE_URL ||
    ((import.meta as any).env?.VITE_VEO_FUNCTIONS_BASE_URL as string | undefined) ||
    "").replace(/\/+$/, "");

function resolveApiUserNameHeader(): string | undefined {
  const storedName = getStoredUserName();
  if (storedName && storedName.trim()) {
    return storedName.trim();
  }
  const authName = auth.currentUser?.displayName;
  if (authName && authName.trim()) {
    return authName.trim();
  }
  return undefined;
}

async function resolveBearerToken(): Promise<string> {
  try {
    const token = await auth.currentUser?.getIdToken();
    if (token && token.trim()) {
      return token;
    }
  } catch {
    // Fall back to dev token when auth token is unavailable.
  }
  return DEV_API_TOKEN;
}

async function buildApiHeadersAsync(hasStringBody?: boolean): Promise<Headers> {
  const headers = buildApiHeaders(undefined, hasStringBody);
  headers.set("Authorization", `Bearer ${await resolveBearerToken()}`);
  const userName = resolveApiUserNameHeader();
  if (userName) {
    headers.set("x-user-name", userName);
  }
  return headers;
}

function buildFunctionsUrl(pathname: string): string {
  return `${VEO_FUNCTIONS_BASE_URL}/${pathname.replace(/^\/+/, "")}`;
}

async function apiFetch<T>(endpoint: string, options: RequestInit = {}): Promise<ApiResponse<T>> {
  if (!API_BASE_URL && endpoint.startsWith('/api') && !shouldUseLocalApiFallback()) {
    return failData<T>(
      'API is not configured for this environment. Set VITE_API_BASE_URL or run on localhost with the local API server.',
    );
  }

  const headers = buildApiHeaders(options.headers, typeof options.body === 'string');
  const url = resolveApiUrl(endpoint);

  try {
    const res = await fetch(url, {
      ...options,
      headers,
    });

    const contentType = (res.headers.get('content-type') || '').toLowerCase();
    if (!contentType.includes('application/json')) {
      return failData<T>(
        `API returned unsupported response format (${contentType || 'unknown'}). Check API routing/base URL configuration.`,
      );
    }

    const json = (await res.json()) as ApiResponse<T>;
    if (!res.ok) {
      if (!json.ok && 'error' in json && json.error?.message) {
        return failData<T>(json.error.message);
      }
      return failData<T>(`API request failed with HTTP ${res.status}`);
    }

    return json as ApiResponse<T>;
  } catch (err: any) {
    return {
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: err?.message || 'Network error connecting to API',
      },
    };
  }
}

export interface BackendUser {
  id: string;
  name: string;
  handle: string;
  diamonds: number;
  crowns: number;
  avatar: string;
  vipStatus: string;
  bio: string;
  followers?: number;
  following?: number;
  totalLikes?: number;
  speedMatches?: number;
  photos?: string[];
}

type FirestoreDoc = Record<string, any>;

const DEFAULT_DISCOVERY_COMMUNITIES: BackendFeedCommunity[] = [
  { id: 'comm-default-1', name: 'Gaming', activeCount: 'Live Hub', icon: 'sports_esports', isJoined: false },
  { id: 'comm-default-2', name: 'Tech', activeCount: 'Live Hub', icon: 'memory', isJoined: false },
  { id: 'comm-default-3', name: 'Music', activeCount: 'Live Hub', icon: 'music_note', isJoined: false },
  { id: 'comm-default-4', name: 'Chat', activeCount: 'Live Hub', icon: 'forum', isJoined: false },
];

function currentBackendUserId(): string {
  return auth.currentUser?.uid ?? getClientId();
}

function buildHandle(name: string, fallbackId: string): string {
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  if (slug) {
    return `@${slug}`;
  }
  return `@${fallbackId.toLowerCase().replace(/[^a-z0-9]+/g, '')}`;
}

function avatarFallback(): string {
  return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80';
}

function asIsoString(value: any): string {
  if (value?.toDate) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'string') {
    return value;
  }
  return new Date().toISOString();
}

function mapUserDoc(userId: string, data: FirestoreDoc): BackendUser {
  const name = data.displayName || data.name || data.username || 'MixVy Member';
  const handle = data.handle || buildHandle(data.username || name, userId);
  const photos = Array.isArray(data.galleryUrls)
    ? data.galleryUrls.filter((item: unknown) => typeof item === 'string')
    : Array.isArray(data.photos)
    ? data.photos.filter((item: unknown) => typeof item === 'string')
    : [];

  return {
    id: userId,
    name,
    handle,
    diamonds: Number(data.balance ?? data.coinBalance ?? data.diamonds ?? 0),
    crowns: Number(data.crowns ?? data.vipLevel ?? 0),
    followers: Number(Array.isArray(data.followers) ? data.followers.length : data.followersCount ?? data.followers ?? 0),
    following: Number(data.followingCount ?? data.following ?? 0),
    totalLikes: Number(data.totalLikes ?? 0),
    speedMatches: Number(data.speedMatches ?? 0),
    avatar: data.avatarUrl || data.photoUrl || data.avatar || avatarFallback(),
    vipStatus: data.vipStatus || data.membershipLevel || 'basic',
    bio: data.bio || 'MixVy Community Member',
    photos,
  };
}

async function ensureFirebaseUserProfile(): Promise<BackendUser> {
  const userId = currentBackendUserId();
  const userRef = doc(db, 'users', userId);
  const snapshot = await getDoc(userRef);

  if (snapshot.exists()) {
    return mapUserDoc(userId, snapshot.data() as FirestoreDoc);
  }

  const authUser = auth.currentUser;
  const name = authUser?.displayName || getStoredUserName() || 'MixVy Member';
  const username = name;
  const handle = buildHandle(username, userId);
  const newUserDoc = {
    id: userId,
    uid: userId,
    email: authUser?.email || '',
    username,
    displayName: name,
    name,
    handle,
    avatarUrl: authUser?.photoURL || avatarFallback(),
    photoUrl: authUser?.photoURL || avatarFallback(),
    bio: 'MixVy Community Member',
    galleryUrls: [],
    balance: 0,
    coinBalance: 0,
    membershipLevel: 'basic',
    vipLevel: 0,
    followers: [],
    createdAt: serverTimestamp(),
  };

  await setDoc(userRef, newUserDoc, { merge: true });
  return mapUserDoc(userId, { ...newUserDoc, createdAt: new Date().toISOString() });
}

function mapRoomDoc(roomId: string, data: FirestoreDoc): BackendRoom {
  const stageUserIds = Array.isArray(data.stageUserIds) ? data.stageUserIds : [];
  return {
    id: roomId,
    title: data.name || data.title || 'Untitled Room',
    streamerName: data.hostUsername || data.streamerName || data.hostName || 'Host',
    streamerAvatar: data.hostAvatarUrl || data.streamerAvatar || avatarFallback(),
    viewerCount: Number(data.memberCount ?? data.viewerCount ?? 0),
    tag: data.category || data.tag || 'Live Room',
    category: data.category || 'Live Room',
    isVIP: Boolean(data.isVIPOnly || data.isVIP),
    isFeatured: Boolean(data.isFeatured),
    isMultiMic: data.isMultiMic ?? true,
    isVIPOnly: Boolean(data.isVIPOnly),
    thumbnail: data.thumbnailUrl || data.thumbnail || avatarFallback(),
    activeMicCount: Number(data.activeMicCount ?? stageUserIds.length ?? 0),
    maxMics: Number(data.maxBroadcasters ?? data.maxMics ?? 4),
  };
}

function mapPostDoc(postId: string, data: FirestoreDoc): BackendPost {
  const likes = Array.isArray(data.likes) ? data.likes : [];
  return {
    id: postId,
    author: data.authorId || data.userId || 'unknown',
    authorName: data.authorName || data.displayName || data.author || 'MixVy Member',
    authorHandle: data.authorHandle || buildHandle(data.authorName || data.displayName || 'member', postId),
    handle: data.authorHandle || buildHandle(data.authorName || data.displayName || 'member', postId),
    avatar: data.authorAvatarUrl || data.authorAvatar || avatarFallback(),
    authorAvatar: data.authorAvatarUrl || data.authorAvatar || avatarFallback(),
    content: data.content || data.text || '',
    mediaUrl: data.videoUrl || data.imageUrl || data.mediaUrl,
    likes: Number(data.likeCount ?? likes.length ?? 0),
    comments: Number(data.commentCount ?? data.comments ?? 0),
    time: new Date(asIsoString(data.createdAt)).toLocaleString(),
    isLiked: likes.includes(currentBackendUserId()),
  } as BackendPost & Record<string, unknown>;
}

function mapStoryClip(storyId: string, data: FirestoreDoc): BackendFeedClip | null {
  const thumbnail = data.imageUrl || data.videoUrl || data.thumbnailUrl;
  if (!thumbnail) {
    return null;
  }
  return {
    id: storyId,
    handle: data.username ? `@${String(data.username).replace(/^@/, '')}` : '@mixvy_live',
    thumbnail,
    isLive: true,
  };
}

function inferCommunityIcon(name: string): string {
  const normalized = name.toLowerCase();
  if (normalized.includes('music') || normalized.includes('dj')) return 'music_note';
  if (normalized.includes('tech') || normalized.includes('ai')) return 'memory';
  if (normalized.includes('game')) return 'sports_esports';
  if (normalized.includes('date')) return 'favorite';
  return 'forum';
}

function mapSuggestedFriend(userId: string, userData: FirestoreDoc, online: boolean): BackendFeedFriend {
  const displayName = userData.displayName || userData.name || userData.username || 'MixVy Member';
  return {
    id: userId,
    name: displayName,
    avatar: userData.avatarUrl || userData.photoUrl || avatarFallback(),
    reason: userData.membershipLevel || userData.vipStatus || 'Active on MixVy',
    isOnline: online,
    isAdded: false,
  };
}

export interface BackendWallet {
  userId: string;
  balance: number;
  diamonds: number;
  crowns: number;
  currency: string;
  updatedAt: string;
}

export interface BackendWalletHistoryItem {
  id: string;
  action: 'add' | 'spend';
  amount: number;
  balanceAfter: number;
  at: string;
}

export interface BackendCashOutRequest {
  id: string;
  amount: number;
  status: string;
  createdAt: string;
}

function mapWalletDoc(userId: string, walletData: FirestoreDoc | null, userData?: FirestoreDoc | null): BackendWallet {
  const fallbackBalance = Number(userData?.balance ?? userData?.coinBalance ?? userData?.diamonds ?? 0);
  const diamonds = Number(walletData?.coinBalance ?? fallbackBalance);
  return {
    userId,
    balance: Number(walletData?.cashBalance ?? 0),
    diamonds,
    crowns: Number(userData?.crowns ?? userData?.vipLevel ?? 0),
    currency: 'USD',
    updatedAt: asIsoString(walletData?.updatedAt ?? userData?.updatedAt),
  };
}

async function ensureWallet(): Promise<BackendWallet> {
  const profile = await ensureFirebaseUserProfile();
  const userId = profile.id;
  const walletRef = doc(db, 'wallets', userId);
  const walletSnap = await getDoc(walletRef);

  if (walletSnap.exists()) {
    return mapWalletDoc(userId, walletSnap.data() as FirestoreDoc, null);
  }

  const initialWallet = {
    userId,
    coinBalance: profile.diamonds,
    cashBalance: 0,
    referralEarnings: 0,
    roomEarnings: 0,
    giftEarnings: 0,
    pendingCashOut: 0,
    updatedAt: serverTimestamp(),
  };
  await setDoc(walletRef, initialWallet, { merge: true });
  return mapWalletDoc(userId, { ...initialWallet, updatedAt: new Date().toISOString() }, null);
}

function mapWalletHistoryItem(data: FirestoreDoc): BackendWalletHistoryItem {
  const source = String(data.source || '').toLowerCase();
  const amount = Number(data.amount ?? 0);
  const inferredAction: 'add' | 'spend' =
    data.action === 'spend' || data.status === 'sent' || source.includes('gift')
      ? 'spend'
      : 'add';

  return {
    id: data.id || Math.random().toString(36).slice(2),
    action: inferredAction,
    amount,
    balanceAfter: Number(
      data.balanceAfter ??
        data.coinBalanceAfter ??
        data.cashBalanceAfter ??
        amount
    ),
    at: asIsoString(data.timestamp ?? data.createdAt),
  };
}

export interface BackendRoomMessage {
  id: string;
  sender: string;
  text: string;
  timestamp: string;
  isGift?: boolean;
  amount?: number;
  isSeen?: boolean;
  seenAt?: string;
}

export interface BackendConversationMessage {
  id: string;
  sender: string;
  senderType: 'user' | 'partner' | 'system' | 'mod';
  text: string;
  timestamp: string;
  isGift?: boolean;
  amount?: number;
}

export interface BackendNotification {
  id: string;
  type: string;
  content: string;
  actorId?: string;
  roomId?: string;
  isRead: boolean;
  createdAt: string;
}

export type CheckoutPackageId = 'coins_70' | 'coins_350' | 'coins_1400' | 'coins_3500' | 'premium_access';
export const CASH_OUT_MINIMUM_USD = 25;

export interface BackendVeoGenerateRequest {
  imageBase64: string;
  mimeType?: string;
  prompt?: string;
  aspectRatio?: '16:9' | '9:16';
}

export interface BackendVeoGenerateResponse {
  operationName: string;
  status: string;
}

export interface BackendVeoStatusResponse {
  done: boolean;
  error?: { message?: string };
}

type BackendStageSpeaker = {
  id: string;
  name: string;
  avatar: string;
  role: string;
  isMuted: boolean;
  isSpeaking: boolean;
  isCameraOff: boolean;
};

function mapRoomMessageDoc(messageId: string, data: FirestoreDoc): BackendRoomMessage {
  const senderName = data.senderName || data.sender || data.displayName || 'Unknown';
  const content = data.content || data.text || '';
  return {
    id: messageId,
    sender: senderName,
    text: content,
    timestamp: asIsoString(data.createdAt ?? data.sentAt),
    isGift: Boolean(data.isGift),
    amount: typeof data.amount === 'number' ? data.amount : undefined,
    isSeen: Boolean(data.isSeen),
    seenAt: data.seenAt ? asIsoString(data.seenAt) : undefined,
  };
}

function formatUiTime(value: any): string {
  const date = new Date(asIsoString(value));
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function mapConversationMessageDoc(
  messageId: string,
  data: FirestoreDoc,
  currentUserName: string,
  currentUserId: string
): BackendConversationMessage {
  const senderId = String(data.senderId || '');
  const senderName = String(data.senderName || 'Unknown');
  const senderType = senderId === currentUserId
    ? 'user'
    : senderName.toUpperCase() === 'SYSTEM'
    ? 'system'
    : 'partner';

  return {
    id: messageId,
    sender: senderType === 'user' ? currentUserName : senderName,
    senderType,
    text: String(data.content || ''),
    timestamp: formatUiTime(data.createdAt ?? data.clientSentAt),
  };
}

async function fetchUserDoc(userId: string): Promise<FirestoreDoc | null> {
  const snap = await getDoc(doc(db, 'users', userId));
  if (!snap.exists()) {
    return null;
  }
  return snap.data() as FirestoreDoc;
}

function mapNotificationDoc(notificationId: string, data: FirestoreDoc): BackendNotification {
  return {
    id: notificationId,
    type: String(data.type || 'general'),
    content: String(data.content || data.body || ''),
    actorId: data.actorId ? String(data.actorId) : undefined,
    roomId: data.roomId ? String(data.roomId) : undefined,
    isRead: Boolean(data.isRead),
    createdAt: asIsoString(data.createdAt),
  };
}

export async function apiGetMessageThreads(): Promise<ApiResponse<MessageThread[]>> {
  try {
    const currentUserId = currentBackendUserId();
    const conversationQuery = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', currentUserId),
      orderBy('lastMessageAt', 'desc'),
      limit(30)
    );
    const snapshot = await getDocs(conversationQuery);
    const threads = await Promise.all(
      snapshot.docs.map(async (item) => {
        const data = item.data() as FirestoreDoc;
        if (data.isArchived || data.status === 'pending') {
          return null;
        }

        const participantIds = Array.isArray(data.participantIds) ? data.participantIds : [];
        const partnerId = participantIds.find((id: unknown) => typeof id === 'string' && id !== currentUserId);
        const partnerDoc = partnerId ? await fetchUserDoc(String(partnerId)) : null;
        const participantNames = (data.participantNames || {}) as Record<string, string>;
        const partnerName =
          (partnerId && participantNames[String(partnerId)]) ||
          partnerDoc?.displayName ||
          partnerDoc?.name ||
          partnerDoc?.username ||
          data.groupName ||
          'Unknown User';
        const partnerHandle =
          partnerDoc?.handle ||
          buildHandle(partnerDoc?.username || partnerName, String(partnerId || item.id));
        const lastReadAt = data.lastReadAt?.[currentUserId];
        const lastMessageAt = data.lastMessageAt;
        const unreadCount =
          lastMessageAt && (!lastReadAt || new Date(asIsoString(lastReadAt)).getTime() < new Date(asIsoString(lastMessageAt)).getTime())
            ? 1
            : 0;

        const thread: MessageThread = {
          id: item.id,
          partnerName,
          partnerHandle,
          partnerAvatar: partnerDoc?.avatarUrl || partnerDoc?.photoUrl || avatarFallback(),
          partnerRole: partnerDoc?.membershipLevel || partnerDoc?.vipStatus || 'MixVy Member',
          isOnline: Boolean(partnerDoc?.isOnline || String(partnerDoc?.presence || '').toLowerCase() === 'online'),
          lastMessage: String(data.lastMessagePreview || 'No messages yet'),
          lastMessageTime: formatUiTime(lastMessageAt || data.createdAt),
          unreadCount,
          isVIP: Boolean((partnerDoc?.vipLevel ?? 0) > 0 || String(partnerDoc?.membershipLevel || '').toLowerCase() === 'vip'),
          participantUserIds: participantIds.filter((id: unknown) => typeof id === 'string') as string[],
        };
        return thread;
      })
    );

    return okData(threads.filter((thread): thread is MessageThread => thread !== null));
  } catch {
    return failData<MessageThread[]>('Unable to load conversations');
  }
}

export async function apiGetConversationMessages(conversationId: string): Promise<ApiResponse<BackendConversationMessage[]>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const messagesQuery = query(
      collection(db, 'conversations', conversationId, 'messages'),
      orderBy('createdAt', 'asc'),
      limit(100)
    );
    const snapshot = await getDocs(messagesQuery);
    const messages = snapshot.docs.map((item) =>
      mapConversationMessageDoc(item.id, item.data() as FirestoreDoc, profile.name, profile.id)
    );
    return okData(messages);
  } catch {
    return failData<BackendConversationMessage[]>('Unable to load conversation messages');
  }
}

export async function apiPostConversationMessage(
  conversationId: string,
  data: { text: string; isGift?: boolean; amount?: number }
): Promise<ApiResponse<BackendConversationMessage>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const convRef = doc(db, 'conversations', conversationId);
    const convSnap = await getDoc(convRef);
    if (!convSnap.exists()) {
      return failData<BackendConversationMessage>('Conversation not found');
    }

    const messageRef = doc(collection(db, 'conversations', conversationId, 'messages'));
    const payload: FirestoreDoc = {
      conversationId,
      senderId: profile.id,
      senderName: profile.name,
      senderAvatarUrl: profile.avatar,
      content: data.text,
      clientMessageId: `${Date.now()}_${profile.id}`,
      createdAt: serverTimestamp(),
      clientSentAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      isDeleted: false,
      readBy: [profile.id],
      isGift: Boolean(data.isGift),
    };
    if (typeof data.amount === 'number') {
      payload.amount = data.amount;
    }

    await setDoc(messageRef, payload);
    await updateDoc(convRef, {
      lastMessageId: messageRef.id,
      lastMessagePreview: data.text,
      lastMessageSenderId: profile.id,
      lastMessageAt: serverTimestamp(),
      [`lastReadAt.${profile.id}`]: serverTimestamp(),
    });

    const created = await getDoc(messageRef);
    return okData(
      mapConversationMessageDoc(created.id, created.data() as FirestoreDoc, profile.name, profile.id)
    );
  } catch {
    return failData<BackendConversationMessage>('Unable to send conversation message');
  }
}

export async function apiMarkConversationRead(conversationId: string): Promise<ApiResponse<{ success: boolean }>> {
  try {
    const userId = currentBackendUserId();
    await updateDoc(doc(db, 'conversations', conversationId), {
      [`lastReadAt.${userId}`]: serverTimestamp(),
    });
    return okData({ success: true });
  } catch {
    return failData<{ success: boolean }>('Unable to mark conversation as read');
  }
}

export async function apiGetNotifications(): Promise<ApiResponse<BackendNotification[]>> {
  try {
    const userId = currentBackendUserId();
    const snapshot = await getDocs(
      query(
        collection(db, 'notifications'),
        where('userId', '==', userId),
        orderBy('createdAt', 'desc'),
        limit(20)
      )
    );
    return okData(snapshot.docs.map((item) => mapNotificationDoc(item.id, item.data() as FirestoreDoc)));
  } catch {
    return failData<BackendNotification[]>('Unable to load notifications');
  }
}

export async function apiMarkNotificationRead(notificationId: string): Promise<ApiResponse<{ success: boolean }>> {
  try {
    await updateDoc(doc(db, 'notifications', notificationId), {
      isRead: true,
      readAt: serverTimestamp(),
    });
    return okData({ success: true });
  } catch {
    return failData<{ success: boolean }>('Unable to mark notification read');
  }
}

export async function apiMarkAllNotificationsRead(): Promise<ApiResponse<{ success: boolean }>> {
  try {
    const userId = currentBackendUserId();
    const snapshot = await getDocs(
      query(
        collection(db, 'notifications'),
        where('userId', '==', userId),
        where('isRead', '==', false),
        limit(100)
      )
    );
    await Promise.all(
      snapshot.docs.map((item) =>
        updateDoc(item.ref, {
          isRead: true,
          readAt: serverTimestamp(),
        })
      )
    );
    return okData({ success: true });
  } catch {
    return failData<{ success: boolean }>('Unable to mark all notifications read');
  }
}

export async function apiCreateCheckoutSession(
  packageId: CheckoutPackageId
): Promise<ApiResponse<{ url: string }>> {
  try {
    const callable = httpsCallable(functions, 'createCheckoutSessionCallable');
    const result = await callable({ packageId });
    const data = result.data as Record<string, unknown>;
    const url = typeof data.url === 'string' ? data.url : '';
    if (!url) {
      return failData<{ url: string }>('Checkout URL was not returned');
    }
    return okData({ url });
  } catch {
    return failData<{ url: string }>('Unable to start checkout session');
  }
}

export async function apiGetCashOutRequests(): Promise<ApiResponse<{ items: BackendCashOutRequest[]; pendingTotal: number }>> {
  try {
    const userId = currentBackendUserId();
    const snapshot = await getDocs(
      query(
        collection(db, 'cash_out_requests'),
        where('userId', '==', userId),
        limit(25)
      )
    );
    const items = snapshot.docs
      .map((item) => {
        const data = item.data() as FirestoreDoc;
        return {
          id: item.id,
          amount: Number(data.amount ?? 0),
          status: String(data.status || 'pending'),
          createdAt: asIsoString(data.createdAt),
        };
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    const pendingTotal = items
      .filter((item) => item.status === 'pending')
      .reduce((sum, item) => sum + item.amount, 0);
    return okData({ items, pendingTotal });
  } catch {
    return failData<{ items: BackendCashOutRequest[]; pendingTotal: number }>('Unable to load cash-out requests');
  }
}

export async function apiRequestCashOut(amount: number): Promise<ApiResponse<{ success: boolean }>> {
  try {
    const callable = httpsCallable(functions, 'requestCashOut');
    await callable({ amount });
    return okData({ success: true });
  } catch {
    return failData<{ success: boolean }>('Unable to submit cash-out request');
  }
}

async function parseVeoHttpError(response: Response, fallback: string): Promise<string> {
  try {
    const contentType = response.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      const payload = (await response.json()) as ApiResponse<unknown>;
      if (!payload.ok && 'error' in payload && payload.error?.message) {
        return payload.error.message;
      }
    }
  } catch {
    // Ignore parse errors and use fallback.
  }

  return `${fallback} (HTTP ${response.status})`;
}

export async function apiStartVeoVideoGeneration(
  payload: BackendVeoGenerateRequest
): Promise<ApiResponse<BackendVeoGenerateResponse>> {
  if (VEO_FUNCTIONS_BASE_URL) {
    let res: Response;
    try {
      res = await fetch(buildFunctionsUrl("veoGenerateVideo"), {
        method: "POST",
        headers: await buildApiHeadersAsync(true),
        body: JSON.stringify(payload),
      });
    } catch {
      // Network failure: keep local /api fallback for local dev runtimes.
      if (!shouldUseLocalApiFallback()) {
        return failData<BackendVeoGenerateResponse>(
          'Unable to reach Veo Functions endpoint. Verify VITE_VEO_FUNCTIONS_BASE_URL and network access.',
        );
      }
      return apiFetch<BackendVeoGenerateResponse>('/api/generate-video', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
    }

    if (!res.ok) {
      return failData<BackendVeoGenerateResponse>(
        await parseVeoHttpError(res, 'Failed to start Veo generation'),
      );
    }

    try {
      const json = (await res.json()) as ApiResponse<BackendVeoGenerateResponse>;
      if (json.ok) {
        return json;
      }
      return failData<BackendVeoGenerateResponse>(
        ('error' in json && json.error?.message) || 'Failed to start Veo generation',
      );
    } catch {
      return failData<BackendVeoGenerateResponse>(
        'Unexpected non-JSON response from Veo generation service',
      );
    }
  }

  if (!shouldUseLocalApiFallback()) {
    return failData<BackendVeoGenerateResponse>(
      'VEO endpoint is not configured. Set VITE_VEO_FUNCTIONS_BASE_URL for hosted deployments.',
    );
  }

  return apiFetch<BackendVeoGenerateResponse>('/api/generate-video', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function apiGetVeoVideoStatus(
  operationName: string
): Promise<ApiResponse<BackendVeoStatusResponse>> {
  if (VEO_FUNCTIONS_BASE_URL) {
    let res: Response;
    try {
      res = await fetch(buildFunctionsUrl("veoVideoStatus"), {
        method: "POST",
        headers: await buildApiHeadersAsync(true),
        body: JSON.stringify({ operationName }),
      });
    } catch {
      // Network failure: keep local /api fallback for local dev runtimes.
      if (!shouldUseLocalApiFallback()) {
        return failData<BackendVeoStatusResponse>(
          'Unable to reach Veo Functions status endpoint. Verify VITE_VEO_FUNCTIONS_BASE_URL and network access.',
        );
      }
      return apiFetch<BackendVeoStatusResponse>('/api/video-status', {
        method: 'POST',
        body: JSON.stringify({ operationName }),
      });
    }

    if (!res.ok) {
      return failData<BackendVeoStatusResponse>(
        await parseVeoHttpError(res, 'Failed checking Veo generation status'),
      );
    }

    try {
      const json = (await res.json()) as ApiResponse<BackendVeoStatusResponse>;
      if (json.ok) {
        return json;
      }
      return failData<BackendVeoStatusResponse>(
        ('error' in json && json.error?.message) || 'Failed checking Veo generation status',
      );
    } catch {
      return failData<BackendVeoStatusResponse>(
        'Unexpected non-JSON response from Veo status service',
      );
    }
  }

  if (!shouldUseLocalApiFallback()) {
    return failData<BackendVeoStatusResponse>(
      'VEO endpoint is not configured. Set VITE_VEO_FUNCTIONS_BASE_URL for hosted deployments.',
    );
  }

  return apiFetch<BackendVeoStatusResponse>('/api/video-status', {
    method: 'POST',
    body: JSON.stringify({ operationName }),
  });
}

export async function apiDownloadVeoVideo(operationName: string): Promise<ApiResponse<Blob>> {
  if (VEO_FUNCTIONS_BASE_URL) {
    let res: Response;
    try {
      res = await fetch(buildFunctionsUrl("veoVideoDownload"), {
        method: "POST",
        headers: await buildApiHeadersAsync(true),
        body: JSON.stringify({ operationName }),
      });
    } catch {
      // Network failure: keep local /api fallback for local dev runtimes.
      if (!shouldUseLocalApiFallback()) {
        return failData<Blob>(
          'Unable to reach Veo Functions download endpoint. Verify VITE_VEO_FUNCTIONS_BASE_URL and network access.',
        );
      }
      try {
        const localRes = await fetch(resolveApiUrl('/api/video-download'), {
          method: 'POST',
          headers: buildApiHeaders(undefined, true),
          body: JSON.stringify({ operationName }),
        });

        if (!localRes.ok) {
          return failData<Blob>(
            await parseVeoHttpError(localRes, 'Failed to stream generated video'),
          );
        }

        return okData(await localRes.blob());
      } catch (err: any) {
        return failData<Blob>(err?.message || 'Network error while downloading Veo video');
      }
    }

    if (!res.ok) {
      return failData<Blob>(
        await parseVeoHttpError(res, 'Failed to stream generated video'),
      );
    }

    return okData(await res.blob());
  }

  if (!shouldUseLocalApiFallback()) {
    return failData<Blob>(
      'VEO endpoint is not configured. Set VITE_VEO_FUNCTIONS_BASE_URL for hosted deployments.',
    );
  }

  try {
    const res = await fetch(resolveApiUrl('/api/video-download'), {
      method: 'POST',
      headers: buildApiHeaders(undefined, true),
      body: JSON.stringify({ operationName }),
    });

    if (!res.ok) {
      return failData<Blob>(await parseVeoHttpError(res, 'Failed to stream generated video'));
    }

    return okData(await res.blob());
  } catch (err: any) {
    return failData<Blob>(err?.message || 'Network error while downloading Veo video');
  }
}

function mapStageRole(role: string): string {
  switch (role) {
    case 'host':
      return 'ROOM OWNER / MAIN MIC';
    case 'cohost':
      return 'ADMIN KEY 🔑';
    case 'stage':
      return 'GUEST MIC';
    default:
      return 'VIP SPEAKER';
  }
}

function mapParticipantToStageSpeaker(
  participantId: string,
  data: FirestoreDoc,
  room?: BackendRoom | null
): BackendStageSpeaker {
  const role = String(data.role || '').toLowerCase();
  return {
    id: participantId,
    name: data.displayName || data.senderName || data.name || room?.streamerName || 'Host',
    avatar: data.photoUrl || data.avatarUrl || room?.streamerAvatar || avatarFallback(),
    role: mapStageRole(role || 'stage'),
    isMuted: Boolean(data.isMuted),
    isSpeaking: Boolean(data.micOn && !data.isMuted),
    isCameraOff: !Boolean(data.camOn),
  };
}

async function getRoomBackend(roomId: string): Promise<BackendRoom | null> {
  try {
    const roomSnap = await getDoc(doc(db, 'rooms', roomId));
    if (!roomSnap.exists()) {
      return null;
    }
    return mapRoomDoc(roomSnap.id, roomSnap.data() as FirestoreDoc);
  } catch {
    return null;
  }
}

export interface BackendRoom {
  id: string;
  title: string;
  streamerName: string;
  streamerAvatar: string;
  viewerCount: number;
  tag: string;
  category?: string;
  isVIP: boolean;
  isFeatured?: boolean;
  isMultiMic?: boolean;
  isVIPOnly?: boolean;
  thumbnail: string;
  activeMicCount?: number;
  maxMics?: number;
}

export interface BackendPost {
  id: string;
  author: string;
  handle: string;
  avatar: string;
  content: string;
  mediaUrl?: string;
  likes: number;
  comments: number;
  time: string;
  isLiked?: boolean;
}

export interface BackendFeedClip {
  id: string;
  handle: string;
  thumbnail: string;
  isLive?: boolean;
}

export interface BackendFeedCommunity {
  id: string;
  name: string;
  activeCount: string;
  icon: string;
  isJoined?: boolean;
}

export interface BackendFeedFriend {
  id: string;
  name: string;
  avatar: string;
  reason: string;
  isOnline: boolean;
  isAdded?: boolean;
}

export interface BackendSocialFeedDiscovery {
  clips: BackendFeedClip[];
  communities: BackendFeedCommunity[];
  friends: BackendFeedFriend[];
}

export interface BackendSpeedDatingProfile {
  id: string;
  name: string;
  username: string;
  age: number;
  location: string;
  role: string;
  avatar: string;
  videoBg?: string;
  bio: string;
  rank: string;
  lifetimeWins: number;
}

export interface BackendSpeedDatingConnection {
  id: string;
  name: string;
  avatar: string;
  type: 'mutual' | 'missed' | 'super';
  timeAgo: string;
}

export interface BackendSpeedDatingMessage {
  id: string;
  sender: string;
  senderType: 'user' | 'partner' | 'system' | 'mod';
  text: string;
  timestamp: string;
}

export interface BackendSpeedMatch {
  status: 'idle' | 'searching' | 'matched';
  partnerName?: string;
  partnerAvatar?: string;
  partnerBio?: string;
  roundTimerSeconds?: number;
  sessionTimeSeconds?: number;
  currentProfile?: BackendSpeedDatingProfile;
  recentConnections?: BackendSpeedDatingConnection[];
  openingMessages?: BackendSpeedDatingMessage[];
}

// User & Wallet APIs
export async function apiGetUser(): Promise<ApiResponse<BackendUser>> {
  try {
    return okData(await ensureFirebaseUserProfile());
  } catch {
    return apiFetch<BackendUser>('/api/user');
  }
}

export async function apiUpdateUser(updates: Partial<BackendUser>): Promise<ApiResponse<BackendUser>> {
  if (updates.name) {
    setStoredUserName(updates.name);
  }
  try {
    const profile = await ensureFirebaseUserProfile();
    const userId = profile.id;
    const payload: FirestoreDoc = {};

    if (updates.name != null) {
      payload.name = updates.name;
      payload.displayName = updates.name;
      if (!updates.handle) {
        payload.handle = buildHandle(updates.name, userId);
      }
    }
    if (updates.handle != null) {
      payload.handle = updates.handle;
      payload.username = updates.handle.replace(/^@/, '').replace(/_/g, ' ').trim() || profile.name;
    }
    if (updates.avatar != null) {
      payload.avatarUrl = updates.avatar;
      payload.photoUrl = updates.avatar;
      payload.avatar = updates.avatar;
    }
    if (updates.bio != null) {
      payload.bio = updates.bio;
    }
    if (updates.photos != null) {
      payload.galleryUrls = updates.photos;
      payload.photos = updates.photos;
    }
    if (updates.diamonds != null) {
      payload.balance = updates.diamonds;
      payload.coinBalance = updates.diamonds;
      payload.diamonds = updates.diamonds;
    }
    if (updates.crowns != null) {
      payload.crowns = updates.crowns;
      payload.vipLevel = updates.crowns;
    }

    await setDoc(doc(db, 'users', userId), payload, { merge: true });
    const refreshed = await getDoc(doc(db, 'users', userId));
    if (!refreshed.exists()) {
      return failData<BackendUser>('User profile update did not persist');
    }
    return okData(mapUserDoc(userId, refreshed.data() as FirestoreDoc));
  } catch {
    return apiFetch<BackendUser>('/api/user', {
      method: 'PATCH',
      body: JSON.stringify(updates),
    });
  }
}

export async function apiUpdateDiamonds(action: 'add' | 'spend', amount: number): Promise<ApiResponse<{ success: boolean; diamonds: number }>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const wallet = await ensureWallet();
    const userId = profile.id;
    const nextDiamonds = action === 'spend'
      ? Math.max(0, wallet.diamonds - amount)
      : wallet.diamonds + amount;

    await setDoc(
      doc(db, 'wallets', userId),
      {
        userId,
        coinBalance: nextDiamonds,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    await setDoc(
      doc(db, 'users', userId),
      {
        balance: nextDiamonds,
        coinBalance: nextDiamonds,
      },
      { merge: true }
    );

    await addDoc(collection(db, 'transactions'), {
      id: crypto.randomUUID(),
      senderId: userId,
      receiverId: userId,
      participants: [userId],
      amount,
      timestamp: new Date().toISOString(),
      status: action === 'spend' ? 'sent' : 'completed',
      source: action === 'spend' ? 'react_wallet_spend' : 'react_wallet_credit',
      action,
      balanceAfter: nextDiamonds,
    });

    return okData({ success: true, diamonds: nextDiamonds });
  } catch {
    return apiFetch<{ success: boolean; diamonds: number }>('/api/user/diamonds', {
      method: 'POST',
      body: JSON.stringify({ action, amount }),
    });
  }
}

export async function apiGetWallet(): Promise<ApiResponse<BackendWallet>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const userId = profile.id;
    const walletRef = doc(db, 'wallets', userId);
    const walletSnap = await getDoc(walletRef);
    const userSnap = await getDoc(doc(db, 'users', userId));
    return okData(
      mapWalletDoc(
        userId,
        walletSnap.exists() ? (walletSnap.data() as FirestoreDoc) : null,
        userSnap.exists() ? (userSnap.data() as FirestoreDoc) : null
      )
    );
  } catch {
    return apiFetch<BackendWallet>('/api/wallet');
  }
}

export async function apiDepositWallet(amount: number): Promise<ApiResponse<{ success: boolean; balance: number }>> {
  try {
    const wallet = await ensureWallet();
    const userId = wallet.userId;
    const nextBalance = Number(wallet.balance) + amount;

    await setDoc(
      doc(db, 'wallets', userId),
      {
        userId,
        cashBalance: nextBalance,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    await addDoc(collection(db, 'transactions'), {
      id: crypto.randomUUID(),
      senderId: userId,
      receiverId: userId,
      participants: [userId],
      amount,
      timestamp: new Date().toISOString(),
      status: 'completed',
      source: 'react_cash_deposit',
      action: 'add',
      cashBalanceAfter: nextBalance,
      balanceAfter: nextBalance,
      currency: 'usd',
    });

    return okData({ success: true, balance: nextBalance });
  } catch {
    return apiFetch<{ success: boolean; balance: number }>('/api/wallet/deposit', {
      method: 'POST',
      body: JSON.stringify({ amount }),
    });
  }
}

export async function apiGetWalletHistory(): Promise<ApiResponse<{ items: BackendWalletHistoryItem[] }>> {
  try {
    const userId = currentBackendUserId();
    const transactionQuery = query(
      collection(db, 'transactions'),
      where('participants', 'array-contains', userId),
      limit(20)
    );
    const snapshot = await getDocs(transactionQuery);
    const items = snapshot.docs
      .map((item) => mapWalletHistoryItem({ ...(item.data() as FirestoreDoc), id: item.id }))
      .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
    return okData({ items });
  } catch {
    return apiFetch<{ items: BackendWalletHistoryItem[] }>('/api/wallet/history');
  }
}

// Room & Mic Queue APIs
export async function apiGetRooms(): Promise<ApiResponse<BackendRoom[]>> {
  try {
    const snapshot = await getDocs(collection(db, 'rooms'));
    const rooms = snapshot.docs
      .map((item) => mapRoomDoc(item.id, item.data() as FirestoreDoc))
      .filter((item) => item.title.trim().length > 0)
      .sort((a, b) => b.viewerCount - a.viewerCount);
    return okData(rooms);
  } catch {
    return apiFetch<BackendRoom[]>('/api/rooms');
  }
}

export async function apiGetRoomMessages(roomId: string): Promise<ApiResponse<BackendRoomMessage[]>> {
  try {
    const messagesQuery = query(
      collection(db, 'rooms', roomId, 'messages'),
      orderBy('sentAt'),
      limit(100)
    );
    const snapshot = await getDocs(messagesQuery);
    const messages = snapshot.docs.map((item) =>
      mapRoomMessageDoc(item.id, item.data() as FirestoreDoc)
    );
    return okData(messages);
  } catch {
    return apiFetch<BackendRoomMessage[]>(`/api/rooms/${roomId}/messages`);
  }
}

export async function apiPostRoomMessage(
  roomId: string,
  data: { sender: string; text: string; isGift?: boolean; amount?: number }
): Promise<ApiResponse<BackendRoomMessage>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const messageRef = doc(collection(db, 'rooms', roomId, 'messages'));
    const payload: FirestoreDoc = {
      id: messageRef.id,
      senderId: profile.id,
      senderName: data.sender || profile.name,
      roomId,
      content: data.text,
      createdAt: serverTimestamp(),
      sentAt: serverTimestamp(),
      clientSentAt: new Date().toISOString(),
      isGift: Boolean(data.isGift),
    };
    if (typeof data.amount === 'number') {
      payload.amount = data.amount;
    }
    await setDoc(messageRef, payload, { merge: true });
    const created = await getDoc(messageRef);
    if (!created.exists()) {
      return failData<BackendRoomMessage>('Room message was not persisted');
    }
    return okData(mapRoomMessageDoc(created.id, created.data() as FirestoreDoc));
  } catch {
    return apiFetch<BackendRoomMessage>(`/api/rooms/${roomId}/messages`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}

export async function apiMarkRoomMessagesSeen(roomId: string): Promise<ApiResponse<{ success: boolean; updatedCount: number }>> {
  try {
    const snapshot = await getDocs(query(collection(db, 'rooms', roomId, 'messages'), limit(100)));
    return okData({ success: true, updatedCount: snapshot.size });
  } catch {
    return apiFetch<{ success: boolean; updatedCount: number }>(`/api/rooms/${roomId}/messages/seen`, {
      method: 'POST',
    });
  }
}

export async function apiGetMicQueue(roomId: string): Promise<ApiResponse<string[]>> {
  try {
    const snapshot = await getDocs(collection(db, 'rooms', roomId, 'micQueue'));
    const queueItems = snapshot.docs.map(
      (item) => ({ id: item.id, ...(item.data() as FirestoreDoc) }) as FirestoreDoc & { id: string }
    );
    const queue = queueItems
      .filter((item) => item.status === 'pending')
      .sort((a, b) => Number(a.priority ?? 0) - Number(b.priority ?? 0))
      .map((item) => String(item.requesterDisplayName || item.requesterId || item.id));
    return okData(queue);
  } catch {
    return apiFetch<string[]>(`/api/rooms/${roomId}/mic-queue`);
  }
}

export async function apiRaiseHand(roomId: string, userName: string): Promise<ApiResponse<{ success: boolean; queue: string[] }>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const roomSnap = await getDoc(doc(db, 'rooms', roomId));
    const roomData = roomSnap.exists() ? (roomSnap.data() as FirestoreDoc) : {};
    const hostId = String(roomData.hostId || '');
    const requestId = hostId ? `${profile.id}_${hostId}` : profile.id;
    const queueRef = doc(db, 'rooms', roomId, 'micQueue', requestId);
    const existing = await getDocs(collection(db, 'rooms', roomId, 'micQueue'));
    const nextPriority = existing.docs
      .map((item) => Number((item.data() as FirestoreDoc).priority ?? 0))
      .reduce((max, value) => (value > max ? value : max), 0) + 1;

    await setDoc(
      queueRef,
      {
        id: requestId,
        roomId,
        requesterId: profile.id,
        hostId,
        status: 'pending',
        priority: nextPriority,
        requesterDisplayName: userName || profile.name,
        requesterAvatarUrl: profile.avatar,
        requestSource: 'hand_raise',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    const queue = await apiGetMicQueue(roomId);
    if (!queue.ok) {
      return failData<{ success: boolean; queue: string[] }>('Mic queue update did not persist');
    }
    return okData({ success: true, queue: queue.data });
  } catch {
    return apiFetch<{ success: boolean; queue: string[] }>(`/api/rooms/${roomId}/raise-hand`, {
      method: 'POST',
      body: JSON.stringify({ userName }),
    });
  }
}

// Social Feed APIs
export async function apiGetPosts(): Promise<ApiResponse<BackendPost[]>> {
  try {
    const postsQuery = query(collection(db, 'posts'), orderBy('createdAt', 'desc'), limit(50));
    const snapshot = await getDocs(postsQuery);
    const posts = snapshot.docs.map((item) => mapPostDoc(item.id, item.data() as FirestoreDoc));
    return okData(posts);
  } catch {
    return apiFetch<BackendPost[]>('/api/posts');
  }
}

export async function apiCreatePost(content: string, mediaUrl?: string, isVideo?: boolean): Promise<ApiResponse<BackendPost>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const payload: FirestoreDoc = {
      authorId: profile.id,
      authorName: profile.name,
      authorHandle: profile.handle,
      authorAvatarUrl: profile.avatar,
      content,
      text: content,
      createdAt: serverTimestamp(),
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      likes: [],
    };

    if (mediaUrl) {
      if (isVideo) {
        payload.videoUrl = mediaUrl;
      } else {
        payload.imageUrl = mediaUrl;
      }
      payload.mediaUrl = mediaUrl;
    }

    const ref = await addDoc(collection(db, 'posts'), payload);
    const created = await getDoc(ref);
    if (!created.exists()) {
      return failData<BackendPost>('Post creation did not persist');
    }
    return okData(mapPostDoc(created.id, created.data() as FirestoreDoc));
  } catch {
    return apiFetch<BackendPost>('/api/posts', {
      method: 'POST',
      body: JSON.stringify({ content, mediaUrl, isVideo }),
    });
  }
}

export async function apiCreateClip(thumbnail: string): Promise<ApiResponse<BackendFeedClip>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const createdAt = new Date();
    const expiresAt = new Date(createdAt.getTime() + 24 * 60 * 60 * 1000);
    const storyRef = await addDoc(collection(db, 'users', profile.id, 'stories'), {
      userId: profile.id,
      username: profile.name,
      userAvatarUrl: profile.avatar,
      imageUrl: thumbnail,
      content: 'Shared from MixVy upload hub',
      createdAt: serverTimestamp(),
      expiresAt,
      viewedBy: [],
      isDeleted: false,
    });
    return okData({
      id: storyRef.id,
      handle: profile.handle,
      thumbnail,
      isLive: true,
    });
  } catch {
    return apiFetch<BackendFeedClip>('/api/social-feed/clips', {
      method: 'POST',
      body: JSON.stringify({ thumbnail }),
    });
  }
}

export async function apiLikePost(postId: string): Promise<ApiResponse<{ postId: string; likes: number; isLiked: boolean }>> {
  try {
    const userId = currentBackendUserId();
    const postRef = doc(db, 'posts', postId);
    const snapshot = await getDoc(postRef);
    if (!snapshot.exists()) {
      return failData<{ postId: string; likes: number; isLiked: boolean }>('Post not found');
    }

    const data = snapshot.data() as FirestoreDoc;
    const likes = Array.isArray(data.likes) ? data.likes : [];
    const isLiked = likes.includes(userId);

    await updateDoc(postRef, {
      likes: isLiked ? arrayRemove(userId) : arrayUnion(userId),
      likeCount: increment(isLiked ? -1 : 1),
    });

    const refreshed = await getDoc(postRef);
    const refreshedData = (refreshed.data() || {}) as FirestoreDoc;
    const refreshedLikes = Array.isArray(refreshedData.likes) ? refreshedData.likes : [];
    return okData({
      postId,
      likes: Number(refreshedData.likeCount ?? refreshedLikes.length ?? 0),
      isLiked: refreshedLikes.includes(userId),
    });
  } catch {
    return apiFetch<{ postId: string; likes: number; isLiked: boolean }>(`/api/posts/${postId}/like`, {
      method: 'POST',
    });
  }
}

export async function apiGetSocialFeedDiscovery(): Promise<ApiResponse<BackendSocialFeedDiscovery>> {
  try {
    const currentUserId = currentBackendUserId();

    const [storySnapshot, roomSnapshot, userSnapshot, presenceSnapshot] = await Promise.all([
      getDocs(
        query(
          collectionGroup(db, 'stories'),
          where('expiresAt', '>', new Date()),
          orderBy('expiresAt', 'desc'),
          limit(12)
        )
      ),
      getDocs(query(collection(db, 'rooms'), limit(20))),
      getDocs(query(collection(db, 'users'), limit(20))),
      getDocs(query(collection(db, 'presence'), limit(20))),
    ]);

    const clips = storySnapshot.docs
      .map((item) => mapStoryClip(item.id, item.data() as FirestoreDoc))
      .filter((item): item is BackendFeedClip => item !== null)
      .slice(0, 8);

    const communityCounts = new Map<string, number>();
    for (const room of roomSnapshot.docs) {
      const roomData = room.data() as FirestoreDoc;
      const category = String(roomData.category || '').trim();
      if (!category) continue;
      communityCounts.set(category, (communityCounts.get(category) || 0) + 1);
    }

    const communities = Array.from(communityCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map(([name, count], index) => ({
        id: `comm-${index}-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
        name,
        activeCount: `${count} live`,
        icon: inferCommunityIcon(name),
        isJoined: false,
      }));

    const presenceByUserId = new Map<string, FirestoreDoc>();
    for (const presence of presenceSnapshot.docs) {
      const data = presence.data() as FirestoreDoc;
      const userId = String(data.userId || presence.id);
      if (userId) {
        presenceByUserId.set(userId, data);
      }
    }

    const friends = userSnapshot.docs
      .filter((item) => item.id !== currentUserId)
      .slice(0, 8)
      .map((item) => {
        const userData = item.data() as FirestoreDoc;
        const presenceData = presenceByUserId.get(item.id);
        const online = Boolean(presenceData?.isOnline || presenceData?.online);
        return mapSuggestedFriend(item.id, userData, online);
      });

    return okData({
      clips,
      communities: communities.length > 0 ? communities : DEFAULT_DISCOVERY_COMMUNITIES,
      friends,
    });
  } catch {
    return apiFetch<BackendSocialFeedDiscovery>('/api/social-feed/discovery');
  }
}

// Speed Dating APIs
export async function apiGetSpeedDatingStatus(): Promise<ApiResponse<BackendSpeedMatch>> {
  try {
    const userId = currentBackendUserId();
    const queueSnap = await getDoc(doc(db, 'speed_dating_queue', userId));
    const queueData = queueSnap.exists() ? (queueSnap.data() as FirestoreDoc) : null;

    if (!queueData || !queueData.matched || !queueData.sessionId) {
      return okData({
        status: queueData ? 'searching' : 'idle',
        roundTimerSeconds: 180,
        sessionTimeSeconds: 0,
        recentConnections: [],
        openingMessages: [],
      });
    }

    const sessionSnap = await getDoc(doc(db, 'speed_dating_sessions', String(queueData.sessionId)));
    if (!sessionSnap.exists()) {
      return okData({
        status: 'searching',
        roundTimerSeconds: 180,
        sessionTimeSeconds: 0,
        recentConnections: [],
        openingMessages: [],
      });
    }

    const sessionData = sessionSnap.data() as FirestoreDoc;
    const participantIds = Array.isArray(sessionData.participantIds) ? sessionData.participantIds : [];
    const partnerId = participantIds.find((id: unknown) => typeof id === 'string' && id !== userId);

    if (!partnerId) {
      return okData({
        status: 'matched',
        roundTimerSeconds: 180,
        sessionTimeSeconds: 0,
        recentConnections: [],
        openingMessages: [],
      });
    }

    const partnerSnap = await getDoc(doc(db, 'users', String(partnerId)));
    const partnerData = partnerSnap.exists() ? (partnerSnap.data() as FirestoreDoc) : {};
    const createdAt = sessionData.createdAt;
    const createdDate = createdAt?.toDate ? createdAt.toDate() : new Date();
    const elapsed = Math.max(0, Math.floor((Date.now() - createdDate.getTime()) / 1000));
    const roundTimerSeconds = Math.max(0, 90 - elapsed);

    return okData({
      status: 'matched',
      partnerName: partnerData.displayName || partnerData.name || partnerData.username || 'Match',
      partnerAvatar: partnerData.avatarUrl || partnerData.photoUrl || avatarFallback(),
      partnerBio: partnerData.bio || 'MixVy speed date ready.',
      roundTimerSeconds,
      sessionTimeSeconds: elapsed,
      currentProfile: {
        id: String(partnerId),
        name: partnerData.displayName || partnerData.name || partnerData.username || 'Match',
        username: partnerData.username || String(partnerData.handle || '').replace(/^@/, '') || 'mixvy_match',
        age: Number(partnerData.age ?? 25),
        location: partnerData.location || 'MixVy Live',
        role: partnerData.membershipLevel || partnerData.vipStatus || 'VIP Member',
        avatar: partnerData.avatarUrl || partnerData.photoUrl || avatarFallback(),
        videoBg: partnerData.avatarUrl || partnerData.photoUrl || avatarFallback(),
        bio: partnerData.bio || 'Ready to connect live.',
        rank: partnerData.badgeTitle || 'Live Match',
        lifetimeWins: Number(partnerData.speedMatches ?? 0),
      },
      recentConnections: [],
      openingMessages: [
        {
          id: `sd_${String(queueData.sessionId)}`,
          sender: partnerData.displayName || partnerData.name || 'Match',
          senderType: 'partner',
          text: 'Hi! Excited to meet you on MixVy.',
          timestamp: 'Just now',
        },
      ],
    });
  } catch {
    return apiFetch<BackendSpeedMatch>('/api/speed-dating/status');
  }
}

export async function apiJoinSpeedDatingQueue(): Promise<ApiResponse<BackendSpeedMatch>> {
  try {
    const callable = httpsCallable(functions, 'joinSpeedDatingQueue');
    const result = await callable();
    const data = result.data as Record<string, unknown>;
    if (data.matched) {
      return apiGetSpeedDatingStatus();
    }
    return okData({
      status: 'searching',
      roundTimerSeconds: 180,
      sessionTimeSeconds: 0,
      recentConnections: [],
      openingMessages: [],
    });
  } catch {
    return apiFetch<BackendSpeedMatch>('/api/speed-dating/queue', {
      method: 'POST',
    });
  }
}

export async function apiLeaveSpeedDatingQueue(): Promise<ApiResponse<{ success: boolean }>> {
  try {
    const callable = httpsCallable(functions, 'leaveSpeedDatingQueue');
    await callable();
    return okData({ success: true });
  } catch {
    return failData<{ success: boolean }>('Unable to leave speed dating queue');
  }
}

// After Dark APIs
export async function apiGetAfterDarkRooms(): Promise<ApiResponse<BackendRoom[]>> {
  try {
    const snapshot = await getDocs(collection(db, 'rooms'));
    const roomItems = snapshot.docs.map(
      (item) => ({ id: item.id, ...(item.data() as FirestoreDoc) }) as FirestoreDoc & { id: string }
    );
    const rooms = roomItems
      .filter((item) => Boolean(item.isAdult))
      .map((item) => mapRoomDoc(item.id, item))
      .sort((a, b) => b.viewerCount - a.viewerCount);
    return okData(rooms);
  } catch {
    return apiFetch<BackendRoom[]>('/api/after-dark/rooms');
  }
}

export async function apiCreateAfterDarkRoom(data: {
  title: string;
  category: string;
  description: string;
  isDiamondOnly: boolean;
  thumbnail: string;
}): Promise<ApiResponse<BackendRoom>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const roomPayload: FirestoreDoc = {
      name: data.title,
      description: data.description,
      hostId: profile.id,
      ownerId: profile.id,
      hostUsername: profile.name,
      hostAvatarUrl: profile.avatar,
      isLive: true,
      isAdult: true,
      isLocked: Boolean(data.isDiamondOnly),
      allowGuestAccess: !data.isDiamondOnly,
      thumbnailUrl: data.thumbnail,
      category: data.category,
      tags: [data.category.toLowerCase(), 'after-dark', ...(data.isDiamondOnly ? ['vip'] : [])],
      memberCount: 1,
      maxBroadcasters: 4,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      stageUserIds: [profile.id],
      audienceUserIds: [],
    };

    const roomRef = await addDoc(collection(db, 'rooms'), roomPayload);
    await setDoc(
      doc(db, 'rooms', roomRef.id, 'participants', profile.id),
      {
        userId: profile.id,
        role: 'host',
        isMuted: false,
        camOn: true,
        micOn: true,
        displayName: profile.name,
        photoUrl: profile.avatar,
        joinedAt: serverTimestamp(),
        lastActiveAt: serverTimestamp(),
      },
      { merge: true }
    );
    await setDoc(
      doc(db, 'rooms', roomRef.id, 'members', profile.id),
      {
        userId: profile.id,
        displayName: profile.name,
        photoUrl: profile.avatar,
        joinedAt: serverTimestamp(),
        lastActiveAt: serverTimestamp(),
      },
      { merge: true }
    );

    const created = await getDoc(roomRef);
    if (!created.exists()) {
      return failData<BackendRoom>('After Dark room creation did not persist');
    }
    return okData(mapRoomDoc(created.id, created.data() as FirestoreDoc));
  } catch {
    return apiFetch<BackendRoom>('/api/after-dark/rooms', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}

export async function apiGetRoomStage(roomId: string): Promise<ApiResponse<any[]>> {
  try {
    const room = await getRoomBackend(roomId);
    const snapshot = await getDocs(collection(db, 'rooms', roomId, 'participants'));
    const participantItems = snapshot.docs.map(
      (item) => ({ id: item.id, ...(item.data() as FirestoreDoc) }) as FirestoreDoc & { id: string }
    );
    const speakers = participantItems
      .filter((item) => ['host', 'cohost', 'stage'].includes(String(item.role || '').toLowerCase()))
      .map((item) => mapParticipantToStageSpeaker(item.id, item, room));

    if (speakers.length > 0) {
      return okData(speakers);
    }

    if (room) {
      return okData([
        {
          id: room.id,
          name: room.streamerName,
          avatar: room.streamerAvatar,
          role: 'ROOM OWNER / MAIN MIC',
          isMuted: false,
          isSpeaking: true,
          isCameraOff: false,
        },
      ]);
    }

    return okData([]);
  } catch {
    return apiFetch<any[]>(`/api/rooms/${roomId}/stage`);
  }
}

export async function apiJoinRoomStage(
  roomId: string,
  speaker?: { id?: string; name?: string; avatar?: string; role?: string; isMuted?: boolean; isSpeaking?: boolean; isCameraOff?: boolean }
): Promise<ApiResponse<any[]>> {
  try {
    const profile = await ensureFirebaseUserProfile();
    const participantRef = doc(db, 'rooms', roomId, 'participants', profile.id);
    const memberRef = doc(db, 'rooms', roomId, 'members', profile.id);
    const displayName = speaker?.name || profile.name;
    const avatar = speaker?.avatar || profile.avatar;

    await setDoc(
      participantRef,
      {
        userId: profile.id,
        role: speaker ? 'stage' : 'audience',
        isMuted: Boolean(speaker?.isMuted),
        camOn: !Boolean(speaker?.isCameraOff),
        micOn: Boolean(speaker?.isSpeaking),
        displayName,
        photoUrl: avatar,
        joinedAt: serverTimestamp(),
        lastActiveAt: serverTimestamp(),
      },
      { merge: true }
    );

    await setDoc(
      memberRef,
      {
        userId: profile.id,
        displayName,
        photoUrl: avatar,
        joinedAt: serverTimestamp(),
        lastActiveAt: serverTimestamp(),
      },
      { merge: true }
    );

    return apiGetRoomStage(roomId);
  } catch {
    return apiFetch<any[]>(`/api/rooms/${roomId}/stage/join`, {
      method: 'POST',
      body: JSON.stringify({ speaker }),
    });
  }
}

// Admin / Data Reset API
export async function apiClearFakeData(): Promise<
  ApiResponse<{ message: string; postsRemaining: number; roomsReset: number }>
> {
  return apiFetch<{ message: string; postsRemaining: number; roomsReset: number }>(
    '/api/admin/clear-fake-data',
    {
      method: 'POST',
    }
  );
}

