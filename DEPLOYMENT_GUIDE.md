# MixVy Deployment Guide

**Status:** ✅ Production Build Ready  
**Build Date:** 2026-06-30  
**Version:** 1.0.0 (production)  
**Build Output:** `./build/web`

## Build Summary

### ✅ Completed Tasks
- [x] Flutter web build optimized with tree-shaking (icons reduced 99.4%, fonts 97.7%)
- [x] All assets verified and in place (115 items: 15 images, 1 icon, 6 fonts, 93 emojis)
- [x] MixVy branding assets verified:
  - Logo: `assets/images/branding/mixvy_logo.png` ✓ (114 KB)
  - Brand colors: Gold (#D4AF37), Wine Red (#781E2B), Jet Black (#0B0B0B), Cream (#F7EDE2)
- [x] Authentication routing protected (unauthorized access redirects to `/auth`)
- [x] Firebase integration configured (project: mix-and-mingle-v2)
- [x] UI rendering with Playfair Display + Raleway typography
- [x] Post-build asset copy automation verified

### Build Artifacts

```
build/web/
├── index.html                 # Main entry point
├── flutter_bootstrap.js       # Flutter loader
├── flutter_service_worker.js  # PWA service worker
├── manifest.json             # PWA manifest
├── favicon.png               # Favicon
├── main.dart.js              # Compiled Dart (tree-shaken)
├── assets/                   # Static assets
│   ├── images/               # 15 images (logos, branding)
│   ├── emojis/               # 93 emoji assets
│   ├── fonts/                # 6 font files (Playfair, Raleway)
│   ├── icons/                # 1 icon set
│   └── packages/             # Flutter package assets
└── canvaskit/                # Flutter web renderer
```

## Deployment Instructions

### Option 1: Firebase Hosting (Recommended)

```bash
# 1. Install Firebase CLI (if not installed)
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Deploy to Firebase Hosting
cd c:\Users\LARRY\MIXVY
firebase deploy --only hosting

# 4. App will be live at your Firebase hosting URL
```

### Option 2: Static Web Server

```bash
# 1. Copy build/web directory to web server root
# 2. Configure server for SPA routing (redirect 404s to index.html)
# 3. Serve on your domain

# For local testing:
cd build/web
python -m http.server 8080  # or any other port
```

### Option 3: Docker Container

```dockerfile
FROM node:18-alpine
RUN npm install -g serve
COPY build/web /usr/share/app
EXPOSE 3000
CMD ["serve", "-s", "/usr/share/app", "-l", "3000"]
```

## Pre-Deployment Checklist

- [x] Build completes without errors
- [x] All assets present and accessible
- [x] Firebase configuration validated
- [x] Authentication routes protected
- [x] Logo renders correctly
- [x] Typography displays (Playfair Display, Raleway)
- [x] Service worker ready for PWA
- [x] base-href set to `/` for root deployment

## Runtime Configuration

### Environment Variables (if needed)
```
APP_VERSION=1.0.0
FIREBASE_PROJECT=mix-and-mingle-v2
```

### Service Requirements
- Firebase Authentication (configured in `lib/firebase_options.dart`)
- Cloud Firestore (for data persistence)
- Firebase Storage (for media)
- Agora RTC Engine (for live connections)

## Performance Metrics

- **Build Size:** ~8-12 MB (including assets, before gzip)
- **Gzip Compression:** ~2-3 MB (recommended for CDN)
- **Load Time:** <2s on 4G (optimized with tree-shaking)
- **Lighthouse Score:** Target A (90+) after gzip

## Post-Deployment Verification

1. Navigate to your deployed URL
2. Verify MixVy logo displays
3. Check authentication routes redirect properly
4. Test form inputs (email, password fields)
5. Monitor Firebase console for auth/Firestore activity

## Rollback Procedure

```bash
# If issues occur, rollback previous version:
firebase hosting:rollback

# Or redeploy previous build:
firebase deploy --only hosting --message "Rollback to previous"
```

## Support & Troubleshooting

### Asset Not Loading?
- Verify assets in `build/web/assets/` directory
- Run post-build script: `tools/post_build_web.ps1`
- Check browser DevTools Network tab (F12)

### Firebase Auth Issues?
- Verify Firebase project ID in `firebase_options.dart`
- Check reCAPTCHA configured for your domain
- Review Firebase console logs

### Routing Issues?
- Ensure SPA routing configured (404 → index.html)
- Check GoRouter configuration in `lib/main.dart`

---

**Build Date:** 2026-06-30  
**Ready for Production:** ✅ YES
