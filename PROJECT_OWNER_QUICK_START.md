# PROJECT OWNER: IAM Fix Quick Reference

**Purpose**: Fix the deployment block for Cloud Functions in 5 minutes  
**For**: Project Owner (gcloud CLI access required)  
**Time**: ~5 minutes

---

## What This Does

Grants Firebase service account permission to deploy Cloud Functions for moderation features (block enforcement).

---

## Copy & Paste These Commands

Open your terminal and run:

```bash
gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:service-770164332233@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator
```

Then:

```bash
gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
  --role=roles/run.invoker
```

Then:

```bash
gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
  --role=roles/eventarc.eventReceiver
```

---

## Verify Success

```bash
gcloud projects get-iam-policy mixvy-v2
```

You should see three new entries for the service accounts above.

---

## What Happens Next (DevOps)

After you run these commands:
1. We deploy Cloud Functions: `firebase deploy --only functions`
2. We verify everything is working: `verify_production_deployment.ps1`
3. We soft-launch to 50 users

**Total time**: ~45 minutes

---

## Issues?

- **"gcloud command not found"**: Install Google Cloud CLI https://cloud.google.com/sdk/docs/install
- **"Permission denied"**: Ensure you're logged in as project owner: `gcloud auth login`
- **Other errors**: Share full error message with DevOps lead

---

**Done?** Reply: "IAM fix complete"
