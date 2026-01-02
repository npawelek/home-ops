# Self-Hosted Renovate Setup

This repository uses self-hosted Renovate via GitHub Actions instead of the Mend Renovate App to avoid manual approval requirements.

## Prerequisites

- GitHub repository with admin access
- Ability to create GitHub Apps

## Setup Instructions

### Step 1: Create a GitHub App

1. Go to: https://github.com/settings/apps/new

2. Fill in the following fields:

   - **GitHub App name**: `bot-reno`
   - **Homepage URL**: `https://github.com/npawelek/home-ops`
   - **Webhook**: Uncheck "Active" (webhooks not needed)

3. Set **Repository permissions**:
   - **Contents**: Read and write
   - **Issues**: Read and write
   - **Metadata**: Read-only (automatic)
   - **Pull requests**: Read and write
   - **Workflows**: Read and write

4. Set **Where can this GitHub App be installed?**: "Only on this account"

5. Click **"Create GitHub App"**

### Step 2: Generate Credentials

1. After creation, note the **App ID** displayed at the top of the page

2. Scroll down and click **"Generate a private key"**
   - This downloads a `.pem` file
   - Save it securely (you'll need the contents)

### Step 3: Install the App

1. In the left sidebar, click **"Install App"**

2. Click **"Install"** next to your username

3. Select **"Only select repositories"**

4. Choose your repository

5. Click **"Install"**

### Step 4: Add Repository Secrets

1. Go to: https://github.com/npawelek/home-ops/settings/secrets/actions

2. Click **"New repository secret"**

3. Add the first secret:
   - **Name**: `BOT_APP_ID`
   - **Secret**: Paste your App ID from Step 2

4. Add the second secret:
   - **Name**: `BOT_APP_PRIVATE_KEY`
   - **Secret**: Open the `.pem` file in a text editor and copy the entire contents (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` lines)

### Step 5: Test the Setup

1. Go to: https://github.com/npawelek/home-ops/actions/workflows/renovate.yaml

2. Click **"Run workflow"**

3. Set options:
   - **Dry-Run**: `true`
   - **Log-Level**: `debug`

4. Click **"Run workflow"** and monitor the logs

5. If successful, run again with **Dry-Run**: `false` to create actual PRs

## How It Works

- The workflow runs every 6 hours (configurable in `.github/workflows/renovate.yaml`)
- Renovate scans for dependency updates across all supported package managers
- PRs are created automatically without manual approval
- The Dependency Dashboard issue tracks all pending updates
- Auto-merge is configured for minor/patch updates on GitHub Actions and Mise tools (after 3-day minimum release age)

## Configuration

- **Renovate config**: `.renovaterc.json5`
- **Workflow file**: `.github/workflows/renovate.yaml`

## Troubleshooting

### PRs Not Being Created

If Renovate creates branches but no PRs appear:

1. Check that the **Workflows** permission is set to "Read and write" in the GitHub App settings
2. Review the workflow logs for permission errors
3. Ensure the app is installed on the correct repository

### Permission Errors

If you see errors like "refusing to allow a GitHub App to create or update workflow":

1. Go to: https://github.com/settings/apps
2. Click on your Renovate app
3. Verify **Workflows** permission is "Read and write"
4. Go to: https://github.com/settings/installations
5. Click **Configure** and accept any pending permission changes

## Migrating from Mend Renovate App

If you previously used the Mend Renovate App:

1. Go to: https://github.com/settings/installations
2. Find "Mend Renovate" and click **"Configure"**
3. Remove this repository from the app's access or uninstall completely
4. Close/delete the old Dependency Dashboard issue
5. Delete any old Renovate branches: `git push origin --delete <branch-name>`
6. Run the self-hosted workflow to create fresh PRs
