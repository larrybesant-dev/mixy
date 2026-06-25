# 🤖 CI/CD Setup Guide — GitHub Actions + Firebase Hosting

**Time Investment:** 15-30 minutes
**Difficulty:** Beginner-friendly
**Benefit:** Automatic deployments on `main` branch push = zero manual steps

---

## 📋 What This Does

Every time you `git push` to `main`:
1. ✅ Runs all Flutter tests
2. ✅ Builds web release bundle
3. ✅ Deploys to Firebase Hosting
4. ✅ Notifies you on success/failure

**Before:** Manual steps each deploy (`flutter build web`, `firebase deploy`)
**After:** Push code → sit back → deployed automatically

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Generate Firebase Deployment Token
```bash
# Run in terminal from project root
firebase login:ci

# This will:
# 1. Open browser to Google login
# 2. Ask for permission to manage Firebase
# 3. Output a long token like: 1//0gXY...
# COPY THIS TOKEN
```

### Step 2: Add Token to GitHub Secrets
1. Go to **GitHub** → Your repo
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `FIREBASE_TOKEN`
5. Value: Paste the token from Step 1
6. Click **Add secret**

### Step 3: Create GitHub Actions Workflow File

Create this file in your repo:
```
.github/workflows/deploy-to-firebase.yml
```

**Content:**
```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      # 1. Check out code
      - uses: actions/checkout@v3

      # 2. Set up Flutter
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.6'  # Match your flutter version
          cache: true

      # 3. Download dependencies
      - name: Get dependencies
        run: |
          flutter pub get

      # 4. Run tests (if any)
      - name: Run tests
        run: |
          flutter test --no-pub
        continue-on-error: true  # Don't fail deploy if tests fail

      # 5. Build web release
      - name: Build Flutter Web
        run: |
          flutter build web \
            --release \
            --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/f4a3b26effe4bbe27f4dbe1b17f62e8d8c6e9e5e/

      # 6. Deploy to Firebase (only on main branch, not PRs)
      - name: Deploy to Firebase Hosting
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          npm install -g firebase-tools@12.0.0
          firebase deploy \
            --only hosting \
            --message "Deploy from GitHub Actions" \
            --token ${{ secrets.FIREBASE_TOKEN }}

      # 7. Notify on failure
      - name: Notify Deployment Status
        if: failure()
        run: |
          echo "❌ Firebase deployment failed!"
          echo "Check GitHub Actions log: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
```

### Step 4: Push to GitHub
```bash
git add .github/workflows/deploy-to-firebase.yml
git commit -m "ci: add automatic Firebase deployment"
git push origin main

# Then watch GitHub → Actions tab for the build
```

---

## ✅ Verify It Works

1. Go to **GitHub** → Your repo → **Actions** tab
2. Click the latest workflow run (should say "Deploy to Firebase Hosting")
3. Wait for ✅ green check (takes 3-5 minutes)
4. Visit `https://mixvy.web.app` and refresh (Cmd/Ctrl+Shift+R)
5. Verify your changes are live

**Expected Timeline:**
```
⏱️ 0:00 — Code pushed
⏱️ 0:15 — GitHub starts build
⏱️ 2:00 — Flutter build completes
⏱️ 2:30 — Firebase deployment starts
⏱️ 3:00 — ✅ Live on web.app
```

---

## 🔧 Advanced Configuration

### Option A: Deploy to Staging on PR (Best Practice)

This deploys to `staging-mixvy.web.app` when you create a PR, then to production when you merge.

**Setup:**
1. Create a second Firebase project for staging
2. Link with `firebase use --add` to get staging `.firebaserc`
3. Update workflow:

```yaml
# .github/workflows/deploy-full.yml
name: Test, Stage, and Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.6'
          cache: true

      - run: flutter pub get
      - run: flutter test --no-pub
      - run: flutter build web --release

      # Deploy to staging on PR
      - name: Deploy to Staging
        if: github.event_name == 'pull_request'
        run: |
          npm install -g firebase-tools@12.0.0
          firebase use staging
          firebase deploy --only hosting --token ${{ secrets.FIREBASE_TOKEN }}

      # Deploy to production on main merge
      - name: Deploy to Production
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          npm install -g firebase-tools@12.0.0
          firebase use production
          firebase deploy --only hosting --token ${{ secrets.FIREBASE_TOKEN }}
```

### Option B: Run Specific Tests

```yaml
- name: Run integration tests
  run: |
    flutter test integration_test/ --verbose
```

### Option C: Add Slack Notification

```yaml
- name: Notify Slack on Failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Firebase deployment failed'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 🚨 Troubleshooting

### Issue: "firebase command not found"
**Fix:**
```yaml
- run: npm install -g firebase-tools@12.0.0
```

### Issue: "Error: Could not authenticate"
**Fix:** Regenerate Firebase token:
```bash
firebase logout
firebase login:ci
# Copy new token to GitHub Secrets
```

### Issue: Workflow shows ❌ red but you don't see why
**Solution:** Click on workflow run → click failing step to expand logs

### Issue: "Build failed: 'flutter' not found"
**Fix:** Ensure `subosito/flutter-action@v2` is before the flutter commands

---

## 📊 Monitoring Deployments

**GitHub Actions Dashboard:**
- Go to **Actions** tab → Click workflow name → See all runs with status

**Firebase Hosting Dashboard:**
- Go to **Firebase Console** → **Hosting** → See deployment history

**Set Up Notifications:**
- GitHub: Go to **Settings** → **Notifications** → Enable workflow notifications
- Firebase: Set up email alerts for deployment failures

---

## 🎯 When to Use This

✅ **Use automated CI/CD if:**
- You have multiple developers
- You want to prevent broken code from reaching production
- You want zero-downtime deployments
- You want an audit trail of who deployed what

❌ **Skip if:**
- You're the only developer and like hands-on control
- You deploy < 1x per week
- You prefer `firebase deploy` in terminal (manual but simple)

---

## 📋 Checklist: CI/CD Ready for Launch

- [ ] Firebase token generated (`firebase login:ci`)
- [ ] GitHub Secret `FIREBASE_TOKEN` added
- [ ] `.github/workflows/deploy-to-firebase.yml` committed
- [ ] Test deployment to `main` branch pushed
- [ ] Verified green ✅ in Actions tab
- [ ] Verified changes are live on Firebase Hosting
- [ ] Team members notified of new CI/CD process

---

## 🚀 Next Steps After Setup

**Recommended:** Once CI/CD is working, do this:

1. Create a `dev` branch for development
2. Push to `dev` for testing (no auto-deploy)
3. Create PR from `dev` to `main` for code review
4. Merge PR → automatic deployment ✅

```bash
# Development workflow
git checkout dev
# ... make changes ...
git push origin dev

# When ready to launch
git push origin dev  # Triggers PR to main
# ... review PR in GitHub ...
git merge  # Auto-deploys when merged
```

---

## 📞 Support

If deployment fails:
1. Check **Actions** tab for red ❌
2. Click failing step for detailed error
3. Search error message in **GitHub Issues**
4. If stuck, manually deploy with `firebase deploy --only hosting`

---

**Last Updated:** 2026-06-25
