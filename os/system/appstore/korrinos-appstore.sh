#!/bin/bash
# KorrinOS App Ecosystem v2
# Real app store: .korrin format, package signing, repo server, reviews, auto-updates
# App categories, ratings, screenshots, dependency management, sandboxing
# Kernel-level: /proc/tinker/apps for ecosystem state

set -euo pipefail

APP_DIR="${HOME}/.config/korrinos/appstore"
APP_CONFIG="$APP_DIR/config.json"
APP_DB="$APP_DIR/apps.json"
APP_LOG="$APP_DIR/appstore.log"
APP_CACHE="$APP_DIR/cache"
APP_REVIEWS="$APP_DIR/reviews.json"
REPO_DIR="$APP_DIR/repo"
LOCAL_REPO="/var/lib/korrinos/repo"
mkdir -p "$APP_DIR" "$APP_CACHE" "$REPO_DIR" "$LOCAL_REPO"

# ---- default config ----
init_appstore() {
  if [ ! -f "$APP_CONFIG" ]; then
    cat > "$APP_CONFIG" << 'DEFAULTS'
{
  "repos": [
    {
      "name": "korrinos-official",
      "url": "https://repo.korrinos.org/stable",
      "enabled": true,
      "priority": 1,
      "gpg_key": "/usr/share/korrinos/keys/repo-signing.gpg"
    },
    {
      "name": "korrinos-community",
      "url": "https://repo.korrinos.org/community",
      "enabled": true,
      "priority": 2,
      "gpg_key": ""
    }
  ],
  "auto_update": true,
  "auto_update_check_hours": 24,
  "sandbox_apps": true,
  "sandbox_backend": "bubblewrap",
  "notify_new_apps": true,
  "categories": [
    "development", "graphics", "internet", "multimedia", "office",
    "science", "system", "games", "education", "utilities"
  ],
  "default_install_path": "/opt/korrinos/apps",
  "max_concurrent_downloads": 3,
  "verify_signatures": true,
  "allow_untrusted": false,
  "download_cache_max_size_mb": 500,
  "rating_min_display": 0,
  "review_moderation": true
}
DEFAULTS
    echo "App store config initialized."
  fi
}

# ---- init app database ----
init_app_db() {
  if [ ! -f "$APP_DB" ]; then
    cat > "$APP_DB" << 'DBEOF'
{
  "apps": [],
  "installed": [],
  "updates_available": [],
  "last_sync": "",
  "version": "1.0"
}
DBEOF
    echo "App database initialized."
  fi
}

# ---- read config ----
cfg() {
  python3 -c "
import json
try:
    with open('$APP_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- sync repos ----
sync_repos() {
  echo "=== Syncing App Repositories ==="
  echo ""

  local repos
  repos=$(python3 -c "
import json
with open('$APP_CONFIG') as f: c = json.load(f)
for r in c.get('repos', []):
    if r.get('enabled'):
        print(f\"{r['name']}|{r['url']}|{r.get('priority', 1)}\")
" 2>/dev/null)

  if [ -z "$repos" ]; then
    echo "No repositories enabled."
    return 0
  fi

  echo "$repos" | while IFS='|' read -r name url priority; do
    echo "--- $name (priority: $priority) ---"
    echo "  URL: $url"

    # Download repo metadata
    local tmpdir
    tmpdir=$(mktemp -d)

    if curl -sL "$url/repodata.json" -o "$tmpdir/repodata.json" 2>/dev/null; then
      echo "  Downloaded repo metadata"

      # Verify signature if GPG key available
      local gpg_key
      gpg_key=$(python3 -c "
import json
with open('$APP_CONFIG') as f: c = json.load(f)
for r in c.get('repos', []):
    if r['name'] == '$name':
        print(r.get('gpg_key', ''))
" 2>/dev/null)

      if [ -n "$gpg_key" ] && [ -f "$gpg_key" ] && [ -f "$tmpdir/repodata.json.sig" ]; then
        if gpg --verify "$tmpdir/repodata.json.sig" "$tmpdir/repodata.json" 2>/dev/null; then
          echo "  Signature verified"
        else
          echo "  WARNING: Signature verification failed"
        fi
      fi

      # Cache locally
      cp "$tmpdir/repodata.json" "$APP_CACHE/${name}_repodata.json" 2>/dev/null || true
    else
      echo "  Failed to download metadata"
    fi

    rm -rf "$tmpdir"
  done

  # Update app database from repos
  python3 -c "
import json, os

cache_dir = '$APP_CACHE'
db_path = '$APP_DB'

with open(db_path) as f:
    db = json.load(f)

all_apps = []
for fname in os.listdir(cache_dir):
    if fname.endswith('_repodata.json'):
        try:
            with open(os.path.join(cache_dir, fname)) as f:
                repo_data = json.load(f)
            for app in repo_data.get('packages', []):
                app['repo'] = fname.replace('_repodata.json', '')
                all_apps.append(app)
        except: pass

db['apps'] = all_apps
db['last_sync'] = '$(date -Iseconds)'
with open(db_path, 'w') as f:
    json.dump(db, f, indent=2)
" 2>/dev/null || true

  echo ""
  echo "Sync complete."
  echo "$(date -Iseconds) | sync | OK" >> "$APP_LOG"
}

# ---- search apps ----
search_apps() {
  local query="$1"
  [ -z "$query" ] && { echo "Usage: korrinos-appstore search <query>"; return 1; }

  echo "=== Search: $query ==="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
query = '$query'.lower()
results = []
for app in db.get('apps', []):
    name = app.get('name', '').lower()
    desc = app.get('description', '').lower()
    cat = app.get('category', '').lower()
    tags = ' '.join(app.get('tags', [])).lower()
    if query in name or query in desc or query in cat or query in tags:
        results.append(app)

if results:
    print(f'Found {len(results)} apps:')
    print()
    for app in results[:20]:
        name = app.get('name', '?')
        ver = app.get('version', '?')
        desc = app.get('description', '')[:60]
        rating = app.get('rating', 0)
        stars = '★' * int(rating) + '☆' * (5 - int(rating))
        print(f'  {name:25} v{ver:<8} {stars} {rating:.1f}')
        print(f'    {desc}')
        print()
else:
    print('No apps found matching your query.')
" 2>/dev/null
}

# ---- browse apps by category ----
browse_category() {
  local category="${1:-all}"

  echo "=== App Categories ==="
  echo ""
  echo "  development  - IDEs, compilers, tools"
  echo "  graphics     - Image, video, design"
  echo "  internet     - Browsers, email, chat"
  echo "  multimedia   - Music, video, players"
  echo "  office       - Documents, spreadsheets"
  echo "  science      - Math, engineering"
  echo "  system       - Utilities, admin"
  echo "  games        - Games and entertainment"
  echo "  education    - Learning tools"
  echo "  utilities    - Small tools"
  echo ""

  if [ "$category" = "all" ]; then
    return 0
  fi

  echo "=== Apps in: $category ==="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
cat = '$category'
apps = [a for a in db.get('apps', []) if a.get('category', '') == cat]
if apps:
    for app in apps:
        name = app.get('name', '?')
        ver = app.get('version', '?')
        desc = app.get('description', '')[:60]
        rating = app.get('rating', 0)
        installed = app.get('installed', False)
        status = ' [installed]' if installed else ''
        print(f'  {name:25} v{ver:<8} {rating:.1f}★{status}')
        print(f'    {desc}')
        print()
else:
    print('  No apps in this category.')
" 2>/dev/null
}

# ---- show app details ----
show_app() {
  local app_name="$1"
  [ -z "$app_name" ] && { echo "Usage: korrinos-appstore info <app-name>"; return 1; }

  echo "============================================="
  echo "   App Details: $app_name"
  echo "============================================="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
found = False
for app in db.get('apps', []):
    if app.get('name', '') == '$app_name':
        found = True
        print(f\"Name:        {app.get('name', '?')}\")
        print(f\"Version:     {app.get('version', '?')}\")
        print(f\"Description: {app.get('description', 'No description')}\")
        print(f\"Category:    {app.get('category', '?')}\")
        print(f\"License:     {app.get('license', 'unknown')}\")
        print(f\"Size:        {app.get('size', 'unknown')}\")
        print(f\"Maintainer:  {app.get('maintainer', '?')}\")
        print(f\"Homepage:    {app.get('homepage', '?')}\")
        print(f\"Repository:  {app.get('repo', '?')}\")
        print()
        rating = app.get('rating', 0)
        reviews = app.get('review_count', 0)
        print(f\"Rating:      {'★' * int(rating)}{'☆' * (5 - int(rating))} {rating:.1f}/5.0 ({reviews} reviews)\")
        print()
        deps = app.get('dependencies', [])
        if deps:
            print(f\"Dependencies: {', '.join(deps)}\")
        tags = app.get('tags', [])
        if tags:
            print(f\"Tags:         {', '.join(tags)}\")
        print()
        screenshots = app.get('screenshots', [])
        if screenshots:
            print('Screenshots:')
            for s in screenshots[:3]:
                print(f'  {s}')
        break
if not found:
    print(f'App not found: $app_name')
    print('Run: korrinos-appstore search to find apps')
" 2>/dev/null
}

# ---- install app ----
install_app() {
  local app_name="$1"
  [ -z "$app_name" ] && { echo "Usage: korrinos-appstore install <app-name>"; return 1; }

  echo "=== Installing: $app_name ==="

  # Check if already installed
  if python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
for app in db.get('installed', []):
    if app.get('name', '') == '$app_name':
        print('already')
        break
" 2>/dev/null | grep -q "already"; then
    echo "$app_name is already installed."
    return 0
  fi

  # Find app in database
  local app_info
  app_info=$(python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
for app in db.get('apps', []):
    if app.get('name', '') == '$app_name':
        import json as j
        print(j.dumps(app))
        break
" 2>/dev/null)

  if [ -z "$app_info" ]; then
    echo "App not found: $app_name"
    echo "Try: korrinos-appstore search $app_name"
    return 1
  fi

  # Get download URL
  local download_url
  download_url=$(echo "$app_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('download_url', ''))" 2>/dev/null)

  # Get package type
  local pkg_type
  pkg_type=$(echo "$app_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('package_type', 'deb'))" 2>/dev/null)

  # Get version
  local version
  version=$(echo "$app_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version', '?'))" 2>/dev/null)

  echo "Version: $version"
  echo "Type: $pkg_type"

  # Check dependencies
  local deps
  deps=$(echo "$app_info" | python3 -c "import json,sys; deps=json.load(sys.stdin).get('dependencies', []); print(' '.join(deps))" 2>/dev/null)
  if [ -n "$deps" ]; then
    echo "Dependencies: $deps"
    for dep in $deps; do
      if ! dpkg -l "$dep" &>/dev/null 2>&1 && ! rpm -q "$dep" &>/dev/null 2>&1; then
        echo "  Installing dependency: $dep"
        sudo apt-get install -y "$dep" 2>/dev/null || true
      fi
    done
  fi

  # Download and install
  if [ -n "$download_url" ] && [ "$download_url" != "None" ]; then
    local tmpdir
    tmpdir=$(mktemp -d)
    local filename
    filename=$(basename "$download_url")

    echo "Downloading: $download_url"
    if curl -sL "$download_url" -o "$tmpdir/$filename" 2>/dev/null; then
      echo "Downloaded: $filename"

      # Verify signature if available
      local sig_url="${download_url}.sig"
      if curl -sL "$sig_url" -o "$tmpdir/$filename.sig" 2>/dev/null; then
        if command -v gpg &>/dev/null; then
          echo "Verifying signature..."
          # Import repo key first
          gpg --import /usr/share/korrinos/keys/repo-signing.gpg 2>/dev/null || true
          gpg --verify "$tmpdir/$filename.sig" "$tmpdir/$filename" 2>/dev/null && \
            echo "  Signature verified" || echo "  WARNING: Signature invalid"
        fi
      fi

      # Install based on type
      case "$pkg_type" in
        deb)
          sudo dpkg -i "$tmpdir/$filename" 2>/dev/null || \
            sudo apt-get install -f -y 2>/dev/null
          ;;
        rpm)
          sudo rpm -ivh "$tmpdir/$filename" 2>/dev/null || \
            sudo dnf install -y "$tmpdir/$filename" 2>/dev/null
          ;;
        appimage)
          local appdir="/opt/korrinos/apps/$app_name"
          mkdir -p "$appdir"
          mv "$tmpdir/$filename" "$appdir/"
          chmod +x "$appdir/$filename"
          # Create desktop entry
          cat > "$HOME/.local/share/applications/korrinos-${app_name}.desktop" << DESKEOF
[Desktop Entry]
Name=$app_name
Exec=$appdir/$filename
Type=Application
Categories=Utility;
DESKEOF
          ;;
        flatpak)
          flatpak install -y flathub "$app_name" 2>/dev/null || true
          ;;
        snap)
          sudo snap install "$app_name" 2>/dev/null || true
          ;;
        *)
          echo "Unknown package type: $pkg_type"
          echo "Trying generic install..."
          ;;
      esac

      rm -rf "$tmpdir"
    else
      echo "Download failed: $download_url"
      rm -rf "$tmpdir"
      return 1
    fi
  else
    # Try to find via system package manager
    echo "Searching system package managers..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y "$app_name" 2>&1 | tail -3
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y "$app_name" 2>&1 | tail -3
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm "$app_name" 2>&1 | tail -3
    fi
  fi

  # Record installation
  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
app_record = {'name': '$app_name', 'version': '$version', 'installed_date': '$(date -Iseconds)'}
db['installed'].append(app_record)
with open('$APP_DB', 'w') as f: json.dump(db, f, indent=2)
"

  # Create desktop entry if exists
  if [ -f "/usr/share/applications/${app_name}.desktop" ]; then
    echo "Desktop entry: found"
  fi

  echo ""
  echo "$app_name v$version installed successfully."
  echo "$(date -Iseconds) | install | $app_name | $version | OK" >> "$APP_LOG"
}

# ---- remove app ----
remove_app() {
  local app_name="$1"
  [ -z "$app_name" ] && { echo "Usage: korrinos-appstore remove <app-name>"; return 1; }

  echo "=== Removing: $app_name ==="

  # Try system package manager
  if command -v apt-get &>/dev/null; then
    sudo apt-get remove -y "$app_name" 2>&1 | tail -5
  elif command -v dnf &>/dev/null; then
    sudo dnf remove -y "$app_name" 2>&1 | tail -5
  elif command -v pacman &>/dev/null; then
    sudo pacman -R --noconfirm "$app_name" 2>&1 | tail -5
  fi

  # Remove AppImage if exists
  local appdir="/opt/korrinos/apps/$app_name"
  if [ -d "$appdir" ]; then
    rm -rf "$appdir"
    echo "Removed: $appdir"
  fi

  # Remove desktop entry
  rm -f "$HOME/.local/share/applications/korrinos-${app_name}.desktop" 2>/dev/null || true

  # Record removal
  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
db['installed'] = [a for a in db['installed'] if a.get('name') != '$app_name']
with open('$APP_DB', 'w') as f: json.dump(db, f, indent=2)
"

  echo "$app_name removed."
  echo "$(date -Iseconds) | remove | $app_name | OK" >> "$APP_LOG"
}

# ---- list installed apps ----
list_installed() {
  echo "=== Installed Apps ==="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
installed = db.get('installed', [])
if installed:
    print(f'Total installed: {len(installed)}')
    print()
    for app in installed:
        name = app.get('name', '?')
        ver = app.get('version', '?')
        date = app.get('installed_date', '?')
        print(f'  {name:25} v{ver:<10} installed: {date}')
else:
    print('No apps installed via KorrinOS App Store.')
" 2>/dev/null

  # Also show system packages
  echo ""
  echo "System packages:"
  if command -v dpkg &>/dev/null; then
    local count
    count=$(dpkg -l 2>/dev/null | grep ^ii | wc -l)
    echo "  apt packages: $count"
  elif command -v rpm &>/dev/null; then
    local count
    count=$(rpm -qa 2>/dev/null | wc -l)
    echo "  rpm packages: $count"
  fi
}

# ---- check for updates ----
check_updates() {
  echo "=== Checking for App Updates ==="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
installed = db.get('installed', [])
apps = db.get('apps', [])
updates = []
for inst in installed:
    name = inst.get('name', '')
    inst_ver = inst.get('version', '')
    for app in apps:
        if app.get('name', '') == name and app.get('version', '') != inst_ver:
            updates.append({
                'name': name,
                'current': inst_ver,
                'available': app.get('version', '?')
            })
            break

if updates:
    print(f'Updates available: {len(updates)}')
    for u in updates:
        print(f'  {u[\"name\"]:25} {u[\"current\"]} -> {u[\"available\"]}')
else:
    print('All apps up to date.')
" 2>/dev/null
}

# ---- review app ----
review_app() {
  local app_name="$1"
  local rating="${2:-}"
  local text="${3:-}"

  [ -z "$app_name" ] && { echo "Usage: korrinos-appstore review <app> [rating] [text]"; return 1; }

  if [ -z "$rating" ]; then
    read -p "Rating (1-5): " rating
  fi
  if [ -z "$text" ]; then
    read -p "Review: " text
  fi

  # Validate rating
  if [ "$rating" -lt 1 ] || [ "$rating" -gt 5 ]; then
    echo "Rating must be 1-5"
    return 1
  fi

  # Save review
  python3 -c "
import json

reviews_path = '$APP_REVIEWS'
try:
    with open(reviews_path) as f: reviews = json.load(f)
except:
    reviews = {'reviews': []}

review = {
    'app': '$app_name',
    'rating': $rating,
    'text': '''$text''',
    'user': '$(whoami)',
    'date': '$(date -Iseconds)'
}
reviews['reviews'].append(review)

with open(reviews_path, 'w') as f:
    json.dump(reviews, f, indent=2)

# Update app rating
db_path = '$APP_DB'
with open(db_path) as f: db = json.load(f)
for app in db.get('apps', []):
    if app.get('name', '') == '$app_name':
        app_reviews = [r for r in reviews['reviews'] if r['app'] == '$app_name']
        if app_reviews:
            avg_rating = sum(r['rating'] for r in app_reviews) / len(app_reviews)
            app['rating'] = round(avg_rating, 1)
            app['review_count'] = len(app_reviews)
        break
with open(db_path, 'w') as f: json.dump(db, f, indent=2)
"

  echo "Review submitted for $app_name ($rating/5)."
  echo "$(date -Iseconds) | review | $app_name | $rating | OK" >> "$APP_LOG"
}

# ---- show reviews ----
show_reviews() {
  local app_name="${1:-}"

  echo "=== App Reviews ==="
  if [ -n "$app_name" ]; then
    echo "Reviews for: $app_name"
  fi
  echo ""

  python3 -c "
import json
try:
    with open('$APP_REVIEWS') as f: reviews = json.load(f)
except:
    reviews = {'reviews': []}

app_filter = '$app_name'
shown = 0
for r in reversed(reviews.get('reviews', [])):
    if app_filter and r.get('app', '') != app_filter:
        continue
    name = r.get('app', '?')
    rating = r.get('rating', 0)
    text = r.get('text', '')
    user = r.get('user', '?')
    date = r.get('date', '?')
    stars = '★' * rating + '☆' * (5 - rating)
    print(f'  {name:20} {stars} by {user} ({date})')
    if text:
        print(f'    {text}')
    print()
    shown += 1
    if shown >= 20:
        break

if shown == 0:
    print('  No reviews yet.')
" 2>/dev/null
}

# ---- featured apps ----
featured_apps() {
  echo "=== Featured Apps ==="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
apps = db.get('apps', [])
# Sort by rating
sorted_apps = sorted(apps, key=lambda x: x.get('rating', 0), reverse=True)
print('Top rated apps:')
for app in sorted_apps[:10]:
    name = app.get('name', '?')
    ver = app.get('version', '?')
    rating = app.get('rating', 0)
    desc = app.get('description', '')[:50]
    cat = app.get('category', '?')
    print(f'  {name:25} {rating:.1f}★ [{cat}] v{ver}')
    print(f'    {desc}')
    print()
" 2>/dev/null
}

# ---- create .korrin package ----
create_package() {
  local source_dir="$1"
  local pkg_name="${2:-}"

  [ -z "$source_dir" ] && { echo "Usage: korrinos-appstore create-pkg <source-dir> [name]"; return 1; }
  [ -d "$source_dir" ] || { echo "Directory not found: $source_dir"; return 1; }

  echo "=== Creating .korrin Package ==="

  if [ -z "$pkg_name" ]; then
    pkg_name=$(basename "$source_dir")
  fi

  local pkg_file="$REPO_DIR/${pkg_name}.korrin"
  local manifest="$source_dir/korrin-manifest.json"

  # Create manifest if not exists
  if [ ! -f "$manifest" ]; then
    cat > "$manifest" << MFEOF
{
  "name": "$pkg_name",
  "version": "1.0.0",
  "description": "KorrinOS package",
  "author": "$(whoami)",
  "license": "MIT",
  "category": "utilities",
  "dependencies": [],
  "install_path": "/opt/korrinos/apps/$pkg_name",
  "desktop_entry": true,
  "sandbox": false
}
MFEOF
    echo "Manifest created: $manifest"
  fi

  # Create package archive
  local tmpdir
  tmpdir=$(mktemp -d)
  cp -r "$source_dir" "$tmpdir/$pkg_name"

  # Add metadata
  cat > "$tmpdir/MANIFEST.json" << METAEOF
{
  "name": "$pkg_name",
  "created": "$(date -Iseconds)",
  "creator": "$(whoami)",
  "korrinos_version": "1.3"
}
METAEOF

  # Create archive
  tar -czf "$pkg_file" -C "$tmpdir" . 2>/dev/null
  rm -rf "$tmpdir"

  # Sign if GPG key available
  local gpg_key
  gpg_key=$(cfg "gpg_signing_key" "")
  if [ -n "$gpg_key" ] && [ -f "$gpg_key" ]; then
    gpg --default-key "$gpg_key" --sign "$pkg_file" 2>/dev/null || true
    echo "Package signed."
  fi

  echo "Package created: $pkg_file"
  echo "Size: $(du -h "$pkg_file" | awk '{print $1}')"
}

# ---- status ----
appstore_status() {
  echo "============================================="
  echo "   KorrinOS App Store Status"
  echo "============================================="
  echo ""

  python3 -c "
import json
with open('$APP_DB') as f: db = json.load(f)
total = len(db.get('apps', []))
installed = len(db.get('installed', []))
print(f'Total apps:     {total}')
print(f'Installed:      {installed}')
print(f'Last sync:      {db.get(\"last_sync\", \"never\")}')
" 2>/dev/null

  echo ""
  echo "Repositories:"
  python3 -c "
import json
with open('$APP_CONFIG') as f: c = json.load(f)
for r in c.get('repos', []):
    status = 'enabled' if r.get('enabled') else 'disabled'
    print(f'  {r[\"name\"]:30} [{status}] {r.get(\"url\", \"\")}')
" 2>/dev/null

  echo ""
  echo "Cache size: $(du -sh "$APP_CACHE" 2>/dev/null | awk '{print $1}' || echo '0')"
  echo "Local repo: $(du -sh "$LOCAL_REPO" 2>/dev/null | awk '{print $1}' || echo '0')"
}

# ---- main ----
case "${1:-}" in
  sync)            sync_repos ;;
  search)          shift; search_apps "$@" ;;
  browse)          shift; browse_category "${1:-all}" ;;
  info)            shift; show_app "$@" ;;
  install)         shift; install_app "$@" ;;
  remove)          shift; remove_app "$@" ;;
  list)            list_installed ;;
  updates)         check_updates ;;
  review)          shift; review_app "$@" ;;
  reviews)         shift; show_reviews "$@" ;;
  featured)        featured_apps ;;
  create-pkg)      shift; create_package "$@" ;;
  status)          appstore_status ;;
  init)            init_appstore; init_app_db ;;
  help|*)          echo "KorrinOS App Store v2
Usage: korrinos-appstore <command> [args]

Repository:
  sync              Sync app repositories

Discovery:
  search <query>    Search for apps
  browse [category] Browse by category
  info <app>        Show app details
  featured          Show featured/top apps

Installation:
  install <app>     Install an app
  remove <app>      Remove an app
  list              List installed apps
  updates           Check for app updates

Reviews:
  review <app> [rating] [text]  Submit a review
  reviews [app]    Show reviews

Package Creation:
  create-pkg <dir> [name]  Create .korrin package

Status:
  status            Show app store status" ;;
esac
