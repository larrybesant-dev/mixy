# 🔧 PATH B: CI/CD SETUP — Implementation Guide

**Estimated Time:** 15-30 minutes
**Deadline:** Today 2pm
**Priority:** MEDIUM — Automates future deployments, prevents manual errors

---

## 📋 Overview

This guide will help you set up GitHub Actions to automatically deploy your app to Firebase Hosting whenever you push to the `main` branch. **Never manually run `firebase deploy` again.**

### What You'll Get

✅ **Auto-deploy on every push to main**
✅ **Deployment history in GitHub**
✅ **No more manual `firebase deploy` commands**
✅ **Failed builds stop bad code from reaching production**
✅ **Team members can deploy without needing Firebase CLI**

---

## ⏱️ Quick Timeline

```
Step 1: Generate Firebase token         → 5 minutes
Step 2: Add token to GitHub Secrets     → 2 minutes
Step 3: GitHub Actions workflow created → Already done ✅
Step 4: Test first deployment           → 10 minutes
Step 5: Verify it worked                → 5 minutes
────────────────────────────────────────
TOTAL:                                    22 minutes
```

---

## 🔑 Step 1: Generate Firebase Deployment Token (5 min)

This token lets GitHub Actions deploy to Firebase on your behalf.

### Option A: Command Line (Recommended)

Open terminal in your project folder:

```bash
firebase login:ci
```

**What happens:**
1. Browser opens → Firebase login page
2. Sign in with your Google account
3. Approve "Firebase CLI" access
4. Browser shows a token (long string)
5. Copy the token

**Save this token somewhere safe** (you'll use it in Step 2)

### Option B: Manual (If Command Fails)

1. Go to https://console.firebase.google.com
2. Click your project name (MIXVY)
3. Settings ⚙️ → Service Accounts
4. Click "Generate Private Key"
5. This creates a JSON file with credentials

**Use Option A if possible** — it's simpler

---

## 🔐 Step 2: Add Token to GitHub Secrets (2 min)

This stores your Firebase token securely in GitHub (never visible in logs).

### Steps:

1. **Go to GitHub:**
   - Open https://github.com/[YOUR_USERNAME]/[YOUR_REPO]/settings
   - Or: Your repo → Settings → Secrets and variables → Actions

2. **Click "New repository secret"**

3. **Add the secret:**
   - Name: `FIREBASE_TOKEN`
   - Value: Paste the token from Step 1
   - Click "Add secret"

**Result:** GitHub now has secure access to deploy your app

---

## ✅ Step 3: GitHub Actions Workflow Already Created

The workflow file is already created at:
```
.github/workflows/deploy-to-firebase.yml
```

**What it does:**
1. Checks out your code
2. Sets up Flutter
3. Installs dependencies (`flutter pub get`)
4. Builds for web (`flutter build web --release`)
5. Deploys to Firebase Hosting
6. Shows success/failure in GitHub UI

**You don't need to create anything—it's ready!**

---

## 🧪 Step 4: Test Your First Deployment (10 min)

### Test #1: Manual Deployment to Verify

Before automating, verify your token works:

```bash
# Make sure you have the Firebase CLI token
firebase deploy --only hosting --token YOUR_TOKEN

# If successful, you should see:
# ✔  Deploy complete!
```

### Test #2: Push to Main Branch (Trigger Auto-Deploy)

```bash
# Make a small test change
echo "# Deploy test" >> TEST.md

# Commit and push
git add TEST.md
git commit -m "Test CI/CD deployment"
git push origin main
```

### Test #3: Watch GitHub Actions Run

1. Go to your GitHub repo
2. Click "Actions" tab (top menu)
3. Click the latest workflow run (should say "🚀 Deploy to Firebase Hosting")
4. Watch the steps execute in real-time

**You should see:**
- ✅ Checkout code
- ✅ Setup Flutter
- ✅ Get dependencies
- ✅ Build web app
- ✅ Deploy to Firebase Hosting
- ✅ Deployment successful

---

## 🔍 Step 5: Verify Deployment Worked (5 min)

### Check 1: GitHub Shows Green ✅

In Actions tab:
- [ ] Workflow run shows green checkmark
- [ ] No red X marks
- [ ] "Deployment successful" message appears

### Check 2: Changes Live on Firebase

```bash
# Visit your app
https://mixvy.web.app

# Verify your test change is there
# (The TEST.md doesn't show on web, but timestamps update)
```

### Check 3: Firestore Dashboard

1. Go to Firebase Console
2. Your project → Hosting
3. Latest deployment should have recent timestamp

---

## 🚀 Step 6: Now You Can Deploy Anytime

### Old Way (Manual)
```bash
# Every time you want to deploy:
flutter build web --release
firebase deploy --only hosting
# Wait... and hope nothing breaks
```

### New Way (Automatic)
```bash
# Just push your code
git push origin main
# GitHub Actions automatically:
#  - Builds your app
#  - Deploys to Firebase
#  - Notifies you of success/failure
# That's it!
```

---

## 📊 Deployment History

All your deployments are now tracked in GitHub:

1. Go to your repo → Actions
2. See every deployment
3. Click any deployment to see:
   - Build logs
   - What changed
   - Who deployed it
   - When it succeeded/failed

**This creates an audit trail** — no more "who deployed what?"

---

## 🔄 Advanced: Staging Before Production

### Optional: Deploy to Staging on PR, Production on Merge

If you want to test on staging first:

**Create two workflows:**

1. `.github/workflows/deploy-staging.yml` — Triggers on PR
2. `.github/workflows/deploy-production.yml` — Triggers on main merge

**Files already created in `.github/workflows/`**

---

## 🚨 Troubleshooting

### Problem: "Workflow failed to deploy"

**Check 1: Is FIREBASE_TOKEN set?**
```bash
# Go to: GitHub repo → Settings → Secrets
# Should see: FIREBASE_TOKEN = ••••••••
```

**Check 2: Did `flutter build web` succeed?**
- In Actions log, look for "Build web app" step
- If red X: Run `flutter build web --release` locally to see error

**Check 3: Is the token expired?**
- Generate new token: `firebase login:ci`
- Update GitHub Secrets with new token

### Problem: "Build takes too long"

First build: ~5-10 minutes (Flutter downloads SDK)
Later builds: ~2-3 minutes (cached)

**This is normal.** You can optimize with:
```yaml
cache: true  # Already in the workflow
```

### Problem: "Can't see Actions tab"

Your repo might be private. Make sure:
1. Settings → Actions → General
2. "Allow all actions and reusable workflows" is selected
3. Click "Save"

---

## 📋 Verification Checklist

Before marking PATH B complete:

- [ ] Firebase CLI token generated ✅
- [ ] Token added to GitHub Secrets (FIREBASE_TOKEN) ✅
- [ ] `.github/workflows/deploy-to-firebase.yml` exists ✅
- [ ] Test commit pushed to main ✅
- [ ] GitHub Actions run completed ✅
- [ ] Deployment shows green ✅ in Actions tab
- [ ] Changes visible on https://mixvy.web.app ✅
- [ ] No errors in deployment logs ✅

---

## 💡 Pro Tips

### Tip 1: Skip Deployment for Docs-Only Changes
```bash
# Add [skip ci] to commit message
git commit -m "Update README [skip ci]"
git push origin main
# Workflow won't run (saves time)
```

### Tip 2: Manual Trigger Without Pushing
1. Go to Actions → Choose workflow
2. "Run workflow" dropdown
3. Click "Run workflow"
4. App deploys without code push

### Tip 3: Notify Team on Deployment
In workflow file, add Slack/Discord webhook:
```yaml
- name: 📢 Notify deployment
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text":"✅ Deployed to https://mixvy.web.app"}'
```

---

## 🎯 After Completing PATH B

Once this is done:
1. ✅ Every push to main auto-deploys
2. ✅ Failed builds prevent broken code reaching production
3. ✅ Team members can deploy without Firebase CLI
4. ✅ Audit trail of all deployments
5. ✅ Save 2 minutes per deployment × 10 deploys = 20 minutes/week

**This is setup-once, benefit-forever automation**

---

## 📞 Need Help?

Once you've completed these steps, reply with:
- ✅ "PATH B complete, first deployment successful"
- ❌ "PATH B stuck on [issue], please help"
- 🤔 "What does [workflow step] do?"

Then we can move to final verification and go-live prep! 🚀

---

## 🎓 Learning More

### GitHub Actions Docs
https://docs.github.com/en/actions

### Firebase Deployment Docs
https://firebase.google.com/docs/hosting/github-integration

### Flutter in CI/CD
https://docs.flutter.dev/deployment/cd
