# Pinchflat Lifecycle Script

This directory contains a custom lifecycle script for Pinchflat that automatically triggers Autopulse when new media is downloaded.

## How It Works

1. When Pinchflat downloads new media, it calls the lifecycle script with the `media_downloaded` event
2. The script makes an HTTP POST request to Autopulse's trigger endpoint
3. Autopulse validates the file exists and triggers Jellyfin to scan and import the media

## Configuration

### Secrets

The script requires Autopulse credentials to be configured in `secrets.sops.yaml`:

```yaml
stringData:
  AUTOPULSE_USERNAME: your-username
  AUTOPULSE_PASSWORD: your-password
```

After updating the secrets file, encrypt it with SOPS:

```bash
sops -e -i kubernetes/apps/downloads/pinchflat/app/secrets.sops.yaml
```

### Environment Variables

The following environment variables are available (with defaults):

- `AUTOPULSE_URL`: Autopulse service URL (default: `http://autopulse.downloads.svc.cluster.local:2875`)
- `AUTOPULSE_USERNAME`: Username for Autopulse authentication
- `AUTOPULSE_PASSWORD`: Password for Autopulse authentication

## Script Location

The lifecycle script is mounted at `/config/extras/user-scripts/lifecycle` inside the Pinchflat container, which is the expected location per Pinchflat's documentation.

## Supported Events

The script handles the following Pinchflat lifecycle events:

- `app_init`: Application initialization (logs startup)
- `media_pre_download`: Before media download (allows all downloads)
- `media_downloaded`: After successful download (triggers Autopulse)
- `media_deleted`: After media deletion (logs only)

## Troubleshooting

Enable logging in the script to dump payload data to disk.
