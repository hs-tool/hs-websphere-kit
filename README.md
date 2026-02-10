# HS WebSphere Build Toolkit

Interactive CLI toolkit for managing WebSphere Application Server, IBM MQ, and BeanStore deployments. Wraps common operational tasks into a single menu-driven interface accessible via the `toolkit` command.

## What's Included

**23 scripts** organized into four categories:

| Category | Scripts |
|----------|---------|
| **Services** | Start/stop MQ, WebSphere (manager + node), App Server, restart cycle, status check |
| **Build & Deploy** | Set build version, download builds (FTP), deploy from cache, full upgrade, teardown/build WAS apps, configure Java 8 SDK, run Ant targets, end-to-end build pipeline |
| **Maintenance** | Clear logs, remove temp files, check disk space, audit/fix permissions |
| **Diagnostics** | Tail logs (live follow), kill stale processes |

All paths and identifiers are auto-detected from the server hostname via `config.sh` — no per-server editing required.

## Deploy to GCP Servers

From PowerShell on your dev machine:

```powershell
# Single server
.\deploy.ps1 JLUKCNDWASBS01

# Multiple servers at once
.\deploy.ps1 JLUKCNDWASBS01,JLUKCNDWASBS02

# With explicit zone/project
.\deploy.ps1 JLUKCNDWASBS01 -Zone europe-west2-a -Project my-gcp-project
```

This builds the tarball, copies it via `gcloud compute scp`, runs the installer over SSH, and cleans up.

### Install on servers with internet access

```bash
curl -fsSL https://raw.githubusercontent.com/hs-tool/hs-websphere-kit/main/get-toolkit.sh | bash
```

### Default install path

```
/home/wasadmin/toolkit
```

The installer:
- Verifies `wasadmin` user exists
- Backs up any existing installation before overwriting
- Locks permissions to 700 dirs/scripts, 600 data
- Creates `/usr/local/bin/toolkit` symlink (if writable)

## Usage

```bash
toolkit
```

Launches the interactive menu. Requires `wasadmin` access.

## Uninstall

```bash
/home/wasadmin/toolkit/uninstall.sh
```

Removes the install directory and `/usr/local/bin/toolkit` symlink with confirmation.

## Project Structure

```
config.sh           # Server config — auto-detects hostname, derives all paths
menu.sh             # Interactive menu (entry point)
banner.txt          # ASCII banner
VERSION             # Semver version string
install.sh          # Production installer
uninstall.sh        # Clean removal
deploy.ps1          # GCP deploy (gcloud scp + ssh)
Makefile            # dist / release / clean targets
scripts/
  services/         # MQ, WebSphere, App Server start/stop/restart/status
  deploy/           # Build version, FTP download, deploy, upgrade, Ant
  maintenance/      # Logs, temp files, disk, permissions
  diagnostics/      # Log tailing, stale process cleanup
.github/
  workflows/
    release.yml     # Auto-release on v* tag push
```

## Release Workflow

```bash
# 1. Bump version
echo "1.1.0" > VERSION

# 2. Commit
git add VERSION && git commit -m "Bump version to 1.1.0"

# 3. Tag and push — GitHub Actions handles the rest
git tag v1.1.0 && git push && git push --tags
```

GitHub Actions automatically builds the tarball and publishes a release with auto-generated notes.

### Manual release (without CI)

```bash
make release   # requires gh CLI authenticated
```

## Security

- All installed files are owned by `wasadmin:wasadmin` with `chmod 700` (no access for other users)
- No secrets stored in the repository — paths resolved at runtime from hostname
- Scripts are operational wrappers around standard WAS/MQ commands

## Author

Hafiz Syed Muhammad Usman
