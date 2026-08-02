import React, { Suspense, lazy, useState } from 'react';
import { TabType, StreamRoom } from './types';
import { Header } from './components/Header.tsx';
import { Sidebar } from './components/Sidebar.tsx';
import { MobileNav } from './components/MobileNav.tsx';

// Views
import { SocialFeedView } from './components/SocialFeedView.tsx';

const MessagesView = lazy(() =>
  import('./components/MessagesView.tsx').then((module) => ({
    default: module.MessagesView,
  })),
);
const StreamingHubView = lazy(() =>
  import('./components/StreamingHubView.tsx').then((module) => ({
    default: module.StreamingHubView,
  })),
);
const SpeedDatingView = lazy(() =>
  import('./components/SpeedDatingView.tsx').then((module) => ({
    default: module.SpeedDatingView,
  })),
);
const ProfileView = lazy(() =>
  import('./components/ProfileView.tsx').then((module) => ({
    default: module.ProfileView,
  })),
);
const AfterDarkView = lazy(() =>
  import('./components/AfterDarkView.tsx').then((module) => ({
    default: module.AfterDarkView,
  })),
);
const CommandCenterView = lazy(() =>
  import('./components/CommandCenterView.tsx').then((module) => ({
    default: module.CommandCenterView,
  })),
);

const LiveStreamModal = lazy(() =>
  import('./components/LiveStreamModal.tsx').then((module) => ({
    default: module.LiveStreamModal,
  })),
);
const GoLiveModal = lazy(() =>
  import('./components/GoLiveModal.tsx').then((module) => ({
    default: module.GoLiveModal,
  })),
);
const WalletModal = lazy(() =>
  import('./components/WalletModal.tsx').then((module) => ({
    default: module.WalletModal,
  })),
);
const DiamondsModal = lazy(() =>
  import('./components/DiamondsModal.tsx').then((module) => ({
    default: module.DiamondsModal,
  })),
);
const SettingsModal = lazy(() =>
  import('./components/SettingsModal.tsx').then((module) => ({
    default: module.SettingsModal,
  })),
);
const SupportModal = lazy(() =>
  import('./components/SupportModal.tsx').then((module) => ({
    default: module.SupportModal,
  })),
);
const AuthModal = lazy(() =>
  import('./components/AuthModal.tsx').then((module) => ({
    default: module.AuthModal,
  })),
);
const VeoAnimatorModal = lazy(() =>
  import('./components/VeoAnimatorModal.tsx').then((module) => ({
    default: module.VeoAnimatorModal,
  })),
);
const MediaUploadModal = lazy(() =>
  import('./components/MediaUploadModal.tsx').then((module) => ({
    default: module.MediaUploadModal,
  })),
);

const tabFallback = (
  <div className="mx-auto mt-24 w-full max-w-3xl px-6 text-center text-[#f7ede2]/75">
    Loading view...
  </div>
);

export default function App() {
  const [currentTab, setCurrentTab] = useState<TabType>('home');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Active Modal States
  const [activeRoom, setActiveRoom] = useState<StreamRoom | null>(null);
  const [isGoLiveOpen, setIsGoLiveOpen] = useState<boolean>(false);
  const [isVeoOpen, setIsVeoOpen] = useState<boolean>(false);
  const [isUploadMediaOpen, setIsUploadMediaOpen] = useState<boolean>(false);
  const [isWalletOpen, setIsWalletOpen] = useState<boolean>(false);
  const [isDiamondsOpen, setIsDiamondsOpen] = useState<boolean>(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState<boolean>(false);
  const [isSupportOpen, setIsSupportOpen] = useState<boolean>(false);
  const [supportTab, setSupportTab] = useState<'ticket' | 'rules' | 'terms'>('ticket');
  const [isAuthOpen, setIsAuthOpen] = useState<boolean>(false);
  const [authRefreshKey, setAuthRefreshKey] = useState(0);

  return (
    <div className="min-h-screen bg-[#0b0b0b] text-[#f7ede2] font-sans selection:bg-[#d4af37] selection:text-[#0b0b0b] antialiased">
      {/* Top Header */}
      <Header
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        onOpenWallet={() => setIsWalletOpen(true)}
        onOpenDiamonds={() => setIsDiamondsOpen(true)}
        onGoLive={() => setIsGoLiveOpen(true)}
        onOpenVeo={() => setIsVeoOpen(true)}
        onOpenMediaUpload={() => setIsUploadMediaOpen(true)}
        onOpenSettings={() => setIsSettingsOpen(true)}
        onOpenAuth={() => setIsAuthOpen(true)}
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
        refreshKey={authRefreshKey}
      />

      {/* Persistent Left Desktop Sidebar */}
      <Sidebar
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        onGoLive={() => setIsGoLiveOpen(true)}
        onOpenSettings={() => setIsSettingsOpen(true)}
        onOpenSupport={() => {
          setSupportTab('ticket');
          setIsSupportOpen(true);
        }}
      />

      {/* Main Content Area based on selected tab */}
      {currentTab === 'home' && (
        <SocialFeedView
          onGoLive={() => setIsGoLiveOpen(true)}
          onOpenVeo={() => setIsVeoOpen(true)}
          onOpenMediaUpload={() => setIsUploadMediaOpen(true)}
          onOpenMatchmaking={() => setCurrentTab('speed-dating')}
          refreshKey={authRefreshKey}
          onOpenSupportTab={(tab) => {
            setSupportTab(tab);
            setIsSupportOpen(true);
          }}
        />
      )}

      {currentTab === 'messages' && (
        <Suspense fallback={tabFallback}>
          <MessagesView
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
            onOpenMatchmaking={() => setCurrentTab('speed-dating')}
          />
        </Suspense>
      )}

      {currentTab === 'streaming-hub' && (
        <Suspense fallback={tabFallback}>
          <StreamingHubView
            onSelectRoom={(room) => setActiveRoom(room)}
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
            onGoLive={() => setIsGoLiveOpen(true)}
            searchQuery={searchQuery}
          />
        </Suspense>
      )}

      {currentTab === 'speed-dating' && (
        <Suspense fallback={tabFallback}>
          <SpeedDatingView onOpenWallet={() => setIsWalletOpen(true)} />
        </Suspense>
      )}

      {currentTab === 'profile' && (
        <Suspense fallback={tabFallback}>
          <ProfileView
            onOpenWallet={() => setIsWalletOpen(true)}
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
            onGoLive={() => setIsGoLiveOpen(true)}
            onOpenSettings={() => setIsSettingsOpen(true)}
            refreshKey={authRefreshKey}
          />
        </Suspense>
      )}

      {currentTab === 'after-dark' && (
        <Suspense fallback={tabFallback}>
          <AfterDarkView
            onSelectRoom={(room) => setActiveRoom(room)}
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
            searchQuery={searchQuery}
          />
        </Suspense>
      )}

      {currentTab === 'command-center' && (
        <Suspense fallback={tabFallback}>
          <CommandCenterView
            onSelectRoom={(room) => setActiveRoom(room)}
            onGoLive={() => setIsGoLiveOpen(true)}
          />
        </Suspense>
      )}

      {/* Mobile Bottom Bar Navigation */}
      <MobileNav
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        onGoLive={() => setIsGoLiveOpen(true)}
      />

      {/* Interactive Modals */}
      {activeRoom && (
        <Suspense fallback={null}>
          <LiveStreamModal
            room={activeRoom}
            onClose={() => setActiveRoom(null)}
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
          />
        </Suspense>
      )}

      {isGoLiveOpen && (
        <Suspense fallback={null}>
          <GoLiveModal
            onClose={() => setIsGoLiveOpen(false)}
            onStartStream={(room) => {
              setIsGoLiveOpen(false);
              setActiveRoom(room);
            }}
          />
        </Suspense>
      )}

      {isVeoOpen && (
        <Suspense fallback={null}>
          <VeoAnimatorModal
            onClose={() => setIsVeoOpen(false)}
            onPostCreated={() => {
              setAuthRefreshKey((v) => v + 1);
            }}
          />
        </Suspense>
      )}

      {isUploadMediaOpen && (
        <Suspense fallback={null}>
          <MediaUploadModal
            onClose={() => setIsUploadMediaOpen(false)}
            onSuccess={() => {
              setAuthRefreshKey((v) => v + 1);
            }}
            onOpenVeo={() => setIsVeoOpen(true)}
          />
        </Suspense>
      )}

      {isWalletOpen && (
        <Suspense fallback={null}>
          <WalletModal
            onClose={() => setIsWalletOpen(false)}
            onOpenDiamonds={() => setIsDiamondsOpen(true)}
          />
        </Suspense>
      )}

      {isDiamondsOpen && (
        <Suspense fallback={null}>
          <DiamondsModal onClose={() => setIsDiamondsOpen(false)} />
        </Suspense>
      )}

      {isSettingsOpen && (
        <Suspense fallback={null}>
          <SettingsModal onClose={() => setIsSettingsOpen(false)} />
        </Suspense>
      )}

      {isSupportOpen && (
        <Suspense fallback={null}>
          <SupportModal
            initialTab={supportTab}
            onClose={() => setIsSupportOpen(false)}
          />
        </Suspense>
      )}

      {isAuthOpen && (
        <Suspense fallback={null}>
          <AuthModal
            onClose={() => setIsAuthOpen(false)}
            onLoginSuccess={() => {
              setIsAuthOpen(false);
              setAuthRefreshKey((value) => value + 1);
              setCurrentTab('profile');
            }}
          />
        </Suspense>
      )}
    </div>
  );
}
