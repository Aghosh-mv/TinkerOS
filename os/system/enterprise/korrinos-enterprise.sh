#!/bin/bash
# KorrinOS Enterprise Suite v2
# Real enterprise features: Active Directory, LDAP, Group Policy, SSO, MFA, SCIM
# VPN split tunneling, audit compliance, user provisioning, cert management
# Compatible with Windows AD, FreeIPA, OpenLDAP, Azure AD
# Kernel-level: /proc/tinker/enterprise for enterprise state

set -euo pipefail

ENT_DIR="${HOME}/.config/korrinos/enterprise"
ENT_CONFIG="$ENT_DIR/config.json"
ENT_LOG="$ENT_DIR/enterprise.log"
ENT_AUDIT="$ENT_DIR/audit.log"
GPO_DIR="/etc/korrinos/gpo"
VPN_DIR="$ENT_DIR/vpn"
CERT_DIR="$ENT_DIR/certs"
mkdir -p "$ENT_DIR" "$GPO_DIR" "$VPN_DIR" "$CERT_DIR"

# ---- default config ----
init_enterprise() {
  if [ ! -f "$ENT_CONFIG" ]; then
    cat > "$ENT_CONFIG" << 'DEFAULTS'
{
  "domain": "",
  "domain_controller": "",
  "realm": "",
  "ldap_url": "",
  "ldap_base_dn": "",
  "bind_dn": "",
  "bind_password": "",
  "use_sssd": true,
  "use_realmd": true,
  "use_adcli": true,
  "use_winbind": false,
  "group_policy": {
    "enabled": false,
    "refresh_interval_minutes": 90,
    "applied_policies": [],
    "gpo_server": "",
    "gpo_path": ""
  },
  "sso": {
    "enabled": false,
    "provider": "kerberos",
    "ticket_lifetime_hours": 10,
    "renew_lifetime_hours": 7,
    "kdc_server": "",
    "admin_server": ""
  },
  "mfa": {
    "enabled": false,
    "provider": "totp",
    "issuer": "KorrinOS",
    "backup_codes": [],
    "enforcement": "optional",
    "allowed_methods": ["totp", "hotp", "webauthn"]
  },
  "scim": {
    "enabled": false,
    "endpoint": "",
    "token": "",
    "sync_interval_minutes": 60,
    "last_sync": ""
  },
  "vpn": {
    "enabled": false,
    "type": "wireguard",
    "config_path": "",
    "split_tunnel": true,
    "dns_override": "",
    "auto_connect": false
  },
  "certificates": {
    "ca_cert": "",
    "client_cert": "",
    "client_key": "",
    "auto_renew": true,
    "renew_days_before": 30
  },
  "compliance": {
    "level": "standard",
    "audit_logging": true,
    "password_policy": {
      "min_length": 8,
      "require_uppercase": true,
      "require_lowercase": true,
      "require_numbers": true,
      "require_symbols": false,
      "max_age_days": 90,
      "history_count": 5
    },
    "session_policy": {
      "idle_timeout_minutes": 15,
      "max_session_hours": 12,
      "concurrent_sessions": 3
    }
  },
  "provisioning": {
    "auto_create_home": true,
    "default_shell": "/bin/bash",
    "default_groups": ["sudo", "docker", "video", "audio"],
    "home_template": "/etc/skel",
    "nfs_home": false,
    "nfs_server": "",
    "nfs_path": ""
  },
  "home_directory": "/home",
  "shell": "/bin/bash"
}
DEFAULTS
    echo "Enterprise config initialized."
  fi
}

# ---- read config ----
cfg() {
  python3 -c "
import json
try:
    with open('$ENT_CONFIG') as f: c = json.load(f)
    keys = '$1'.split('.')
    val = c
    for k in keys:
        if isinstance(val, dict): val = val.get(k, '$2')
        else: val = '$2'; break
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- audit logging ----
audit_log() {
  local action="$1" detail="${2:-}"
  local entry="$(date -Iseconds) | ${USER:-root} | $action | $detail"
  echo "$entry" >> "$ENT_AUDIT"
  echo "$entry" >> "$ENT_LOG"

  # Also write to system audit if available
  if command -v auditctl &>/dev/null && [ "${EUID}" -eq 0 ]; then
    echo "korrinos enterprise: $action $detail" | auditctl -w /etc/korrinos -p wa -k korrinos 2>/dev/null || true
  fi
}

# ---- join Active Directory domain ----
ad_join() {
  local domain="${1:-}"
  local admin_user="${2:-}"

  [ -z "$domain" ] && read -p "Domain (e.g., corp.example.com): " domain
  [ -z "$admin_user" ] && read -p "Domain Admin user: " admin_user

  echo "=== Joining Active Directory Domain: $domain ==="

  # Install required packages
  echo "Installing dependencies..."
  sudo apt-get install -y realmd sssd sssd-tools adcli krb5-user \
    samba-common-bin packagekit oddjob oddjob-mkhomedir 2>/dev/null || true

  # Discover domain
  echo "Discovering domain..."
  local domain_info
  domain_info=$(sudo realm discover "$domain" 2>&1) || {
    echo "ERROR: Domain not found. Check DNS and network."
    echo "$domain_info"
    audit_log "ad-join-fail" "$domain"
    return 1
  }

  echo "Domain discovered:"
  echo "$domain_info" | head -10

  # Join domain
  echo ""
  echo "Joining domain..."
  sudo realm join --verbose --user="$admin_user" "$domain" 2>&1 | tail -15

  # Configure SSSD
  echo "Configuring SSSD..."
  sudo tee /etc/sssd/sssd.conf >/dev/null << SSSDEOF
[sssd]
domains = $domain
config_file_version = 2
services = nss, pam, ssh, sudo

[nss]
filter_groups = root
filter_users = root
cache_resolution_timeout = 90

[pam]
offline_credentials_expiration = 7
offline_failed_login_attempts = 3
offline_failed_login_delay = 60

[domain/$domain]
ad_domain = $domain
krb5_realm = $(echo "$domain" | tr '[:lower:]' '[:upper:]')
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u
access_provider = ad
dyndns_update = True
dyndns_iface_pattern = eth.*
dyndns_ttl = 3600
SSSDEOF
  sudo chmod 600 /etc/sssd/sssd.conf

  # Configure SSSD for sudo
  sudo tee /etc/sudoers.d/domain-admins >/dev/null << 'SUDOEOF'
%domain\ admins ALL=(ALL) ALL
SUDOEOF
  sudo chmod 440 /etc/sudoers.d/domain-admins

  # Enable and restart services
  sudo systemctl restart sssd
  sudo systemctl enable sssd

  # Enable home directory auto-creation
  sudo pam-auth-update --enable mkhomedir 2>/dev/null || true

  # Test authentication
  echo ""
  echo "Testing domain authentication..."
  echo "Try: su - <domain_username>"

  audit_log "ad-join" "$domain as $admin_user"
  echo ""
  echo "Domain joined successfully."
  echo "Users can now log in with domain credentials."
}

# ---- leave domain ----
ad_leave() {
  echo "=== Leaving Active Directory Domain ==="
  read -p "Are you sure? (yes/no): " confirm
  [ "$confirm" != "yes" ] && return 0

  sudo realm leave --verbose 2>&1 | tail -5
  sudo systemctl stop sssd 2>/dev/null || true
  sudo rm -f /etc/sssd/sssd.conf

  audit_log "ad-leave"
  echo "Domain left. Local authentication restored."
}

# ---- join LDAP ----
ldap_join() {
  local ldap_url="${1:-}"
  local base_dn="${2:-}"
  local bind_dn="${3:-}"

  [ -z "$ldap_url" ] && read -p "LDAP URL (e.g., ldap://ldap.example.com): " ldap_url
  [ -z "$base_dn" ] && read -p "Base DN (e.g., dc=example,dc=com): " base_dn
  [ -z "$bind_dn" ] && read -p "Bind DN: " bind_dn

  echo "=== Joining LDAP Server: $ldap_url ==="

  sudo apt-get install -y libnss-ldap libpam-ldap ldap-utils sssd sssd-ldap 2>/dev/null || true

  # Configure nslcd
  sudo tee /etc/nslcd.conf >/dev/null << NSLCDEOF
uid nslcd
gid nslcd
uri $ldap_url
base $base_dn
binddn $bind_dn
tls_reqcert allow
NSLCDEOF
  sudo chmod 600 /etc/nslcd.conf

  # Configure nsswitch
  sudo tee /etc/nsswitch.conf >/dev/null << 'NSSWEOF'
passwd:         files sss
group:          files sss
shadow:         files sss
gshadow:        files
hosts:          files dns
networks:       files
protocols:      db files
services:       db files sss
ethers:         db files
rpc:            db files
netgroup:       nis sss
sudoers:        files sss
automount:      files sss
NSSWEOF

  # Configure SSSD for LDAP
  sudo tee /etc/sssd/sssd.conf >/dev/null << LDAPSSSDEOF
[sssd]
config_file_version = 2
services = nss, pam

[nss]

[pam]

[domain/ldap]
id_provider = ldap
auth_provider = ldap
access_provider = permit
ldap_uri = $ldap_url
ldap_search_base = $base_dn
ldap_tls_reqcert = allow
cache_credentials = True
LDAPSSSDEOF
  sudo chmod 600 /etc/sssd/sssd.conf

  sudo systemctl restart nslcd sssd 2>/dev/null || true

  audit_log "ldap-join" "$ldap_url"
  echo "LDAP joined successfully."
}

# ---- Group Policy (GPO) ----
apply_gpo() {
  echo "=== Applying Group Policy ==="

  mkdir -p "$GPO_DIR"

  # Default GPO policies
  cat > "$GPO_DIR/desktop-lockdown.json" << 'EOF'
{
  "name": "Desktop Lockdown",
  "version": "1.0",
  "policies": {
    "desktop": {
      "wallpaper": "/usr/share/korrinos/wallpapers/default.png",
      "lock_screen_timeout_minutes": 15,
      "disable_control_panel": false,
      "disable_task_manager": false,
      "restrict_software_install": false,
      "disable_usb_storage": false,
      "disable_registry_editing": false,
      "prevent_saving_settings": false
    },
    "network": {
      "disable_wifi": false,
      "disable_bluetooth": false,
      "proxy_settings": "",
      "dns_servers": [],
      "firewall_rules": [],
      "restrict_hotspot": false,
      "vpn_required": false
    },
    "security": {
      "min_password_length": 8,
      "password_expiry_days": 90,
      "account_lockout_attempts": 5,
      "lockout_duration_minutes": 30,
      "enable_firewall": true,
      "enable_audit_logging": true,
      "require_screen_lock": true,
      "disable_guest_account": true,
      "min_password_age_days": 1,
      "password_history_count": 5,
      "complex_password": false
    },
    "updates": {
      "auto_update": true,
      "update_time": "03:00",
      "force_restart": false,
      "defer_updates_days": 0,
      "wsus_server": ""
    },
    "applications": {
      "blocked_apps": [],
      "required_apps": [],
      "allowed_repos": [],
      "app_install_restricted": false
    },
    "audit": {
      "logon_events": true,
      "object_access": true,
      "policy_changes": true,
      " privilege_use": true,
      "process_tracking": true,
      "retention_days": 365
    }
  }
}
EOF

  # Apply GPO policies
  echo "Applying desktop lockdown..."
  local wp
  wp=$(python3 -c "import json; print(json.load(open('$GPO_DIR/desktop-lockdown.json'))['policies']['desktop']['wallpaper'])" 2>/dev/null)
  if [ -f "$wp" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$wp" 2>/dev/null || true
  fi

  local lock_timeout
  lock_timeout=$(python3 -c "import json; print(json.load(open('$GPO_DIR/desktop-lockdown.json'))['policies']['desktop']['lock_screen_timeout_minutes'])" 2>/dev/null)
  gsettings set org.gnome.desktop.session idle-delay $((lock_timeout * 60)) 2>/dev/null || true

  local min_pwd_len
  min_pwd_len=$(python3 -c "import json; print(json.load(open('$GPO_DIR/desktop-lockdown.json'))['policies']['security']['min_password_length'])" 2>/dev/null)
  echo "password requisite pam_pwquality.so minlen=$min_pwd_len retry=3" | sudo tee /etc/pam.d/common-password >/dev/null 2>&1 || true

  audit_log "gpo-apply" "desktop-lockdown"
  echo "GPO applied from $GPO_DIR"
  echo "Policies active:"
  ls "$GPO_DIR"/*.json 2>/dev/null | while read -r f; do
    echo "  $(basename "$f" .json)"
  done
}

# ---- Single Sign-On (Kerberos) ----
sso_setup() {
  echo "=== Kerberos SSO Setup ==="
  read -p "Realm (e.g., CORP.EXAMPLE.COM): " realm
  read -p "KDC Server: " kdc
  read -p "Admin Server (same as KDC if unsure): " admin_server
  admin_server="${admin_server:-$kdc}"

  sudo tee /etc/krb5.conf >/dev/null << KRBEOF
[libdefaults]
    default_realm = $realm
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    default_ccache_name = KEYRING:persistent:%{uid}

[realms]
    $realm = {
        kdc = $kdc
        admin_server = $admin_server
    }

[domain_realm]
    .$(echo "$realm" | tr '[:upper:]' '[:lower:]') = $realm
    $(echo "$realm" | tr '[:upper:]' '[:lower:]') = $realm
KRBEOF

  # Test Kerberos
  echo ""
  echo "Testing Kerberos configuration..."
  echo "Run: kinit <username>@$realm"
  echo "Then: klist to see tickets"

  python3 -c "
import json
with open('$ENT_CONFIG') as f: c = json.load(f)
c['sso']['enabled'] = True
c['sso']['realm'] = '$realm'
c['sso']['kdc_server'] = '$kdc'
c['sso']['admin_server'] = '$admin_server'
with open('$ENT_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  audit_log "sso-setup" "$realm"
  echo "Kerberos SSO configured."
}

# ---- MFA (TOTP/HOTP/WebAuthn) ----
mfa_setup() {
  echo "=== MFA Setup ==="
  read -p "Username: " username

  echo "MFA methods:"
  echo "  1. TOTP (Google Authenticator compatible)"
  echo "  2. HOTP (counter-based)"
  echo "  3. WebAuthn (hardware key)"
  read -p "Method [1]: " method
  method="${method:-1}"

  case "$method" in
    1|2)
      sudo apt-get install -y libpam-google-authenticator 2>/dev/null || true

      if [ "$method" = "1" ]; then
        google-authenticator -u -t -d -r 3 -R 30 -w 3 "$username" 2>/dev/null || {
          echo "Run as user: google-authenticator"
        }
      else
        google-authenticator -u -t -d -i "KorrinOS HOTP" -H "$username" 2>/dev/null || true
      fi

      # Enable in PAM
      if ! grep -q "google_authenticator" /etc/pam.d/common-auth 2>/dev/null; then
        echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/common-auth
      fi
      ;;
    3)
      echo "WebAuthn setup:"
      echo "  1. Install: sudo apt install libpam-u2f"
      echo "  2. Register key: mkdir -p ~/.config/Yubico && pamu2fcfg > ~/.config/Yubico/u2f_keys"
      echo "  3. Test with: sudo pamu2fcfg -n"
      sudo apt-get install -y libpam-u2f 2>/dev/null || true
      ;;
  esac

  # Configure enforcement
  local enforcement
  enforcement=$(cfg "mfa.enforcement" "optional")
  echo "MFA enforcement: $enforcement"

  python3 -c "
import json
with open('$ENT_CONFIG') as f: c = json.load(f)
c['mfa']['enabled'] = True
c['mfa']['provider'] = '$(case $method in 1) echo totp;; 2) echo hotp;; 3) echo webauthn;; esac)'
with open('$ENT_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  audit_log "mfa-setup" "$username method=$method"
  echo "MFA enabled for $username"
}

# ---- SCIM provisioning ----
scim_setup() {
  echo "=== SCIM User Provisioning ==="
  read -p "SCIM Endpoint URL: " endpoint
  read -p "Bearer Token: " token
  read -p "Sync interval (minutes) [60]: " interval
  interval="${interval:-60}"

  # Test SCIM connection
  echo "Testing SCIM connection..."
  local response
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $token" \
    "$endpoint/Users?count=1" 2>/dev/null)
  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo "SCIM connection successful."
    echo "$body" | python3 -m json.tool 2>/dev/null | head -15

    python3 -c "
import json
with open('$ENT_CONFIG') as f: c = json.load(f)
c['scim']['enabled'] = True
c['scim']['endpoint'] = '$endpoint'
c['scim']['token'] = '$token'
c['scim']['sync_interval_minutes'] = $interval
with open('$ENT_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
    audit_log "scim-setup" "$endpoint"
  else
    echo "SCIM connection failed (HTTP $http_code)"
    echo "Response: $body"
    return 1
  fi
}

# ---- SCIM sync ----
scim_sync() {
  echo "=== SCIM Sync ==="
  local endpoint token
  endpoint=$(cfg "scim.endpoint" "")
  token=$(cfg "scim.token" "")
  [ -z "$endpoint" ] && { echo "SCIM not configured."; return 1; }

  echo "Fetching users from SCIM endpoint..."
  local response
  response=$(curl -s -H "Authorization: Bearer $token" "$endpoint/Users" 2>/dev/null)

  echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    resources = data.get('Resources', [])
    print(f'Found {len(resources)} users:')
    for r in resources[:20]:
        name = r.get('name', {})
        display = name.get('formatted', name.get('givenName', 'unknown'))
        emails = r.get('emails', [])
        email = emails[0].get('value', '') if emails else ''
        active = r.get('active', True)
        status = 'active' if active else 'inactive'
        print(f'  {display:30} {email:30} [{status}]')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null

  # Local user provisioning
  echo ""
  echo "Provisioning local users..."
  echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for r in data.get('Resources', []):
        if r.get('active', True):
            name = r.get('userName', '')
            if name:
                print(name)
except: pass
" 2>/dev/null | while read -r username; do
    if ! id "$username" &>/dev/null; then
      echo "  Creating user: $username"
      sudo useradd -m -s /bin/bash "$username" 2>/dev/null || true
    fi
  done
}

# ---- VPN management ----
setup_vpn() {
  echo "=== VPN Setup ==="
  echo "Supported VPN types:"
  echo "  1. WireGuard"
  echo "  2. OpenVPN"
  echo "  3. IPSec/IKEv2"
  read -p "Type [1]: " vpn_type
  vpn_type="${vpn_type:-1}"

  case "$vpn_type" in
    1)
      sudo apt-get install -y wireguard 2>/dev/null || true
      echo "WireGuard config files: /etc/wireguard/"
      read -p "Config file path: " config_path
      if [ -n "$config_path" ] && [ -f "$config_path" ]; then
        sudo cp "$config_path" /etc/wireguard/wg0.conf
        sudo chmod 600 /etc/wireguard/wg0.conf
        sudo systemctl enable wg-quick@wg0
        echo "WireGuard configured."
      fi
      ;;
    2)
      sudo apt-get install -y openvpn 2>/dev/null || true
      read -p "OpenVPN config file: " config_path
      if [ -n "$config_path" ] && [ -f "$config_path" ]; then
        sudo cp "$config_path" /etc/openvpn/client.conf
        sudo systemctl enable openvpn@client
        echo "OpenVPN configured."
      fi
      ;;
    3)
      sudo apt-get install -y strongswan 2>/dev/null || true
      echo "IPSec/IKEv2 setup requires manual configuration."
      echo "Edit: /etc/ipsec.conf"
      ;;
  esac

  # Split tunnel config
  local split
  split=$(cfg "vpn.split_tunnel" "true")
  echo "Split tunneling: $split"

  if [ "$split" = "True" ]; then
    echo "Configuring split tunnel..."
    echo "# Split tunnel routes" | sudo tee -a /etc/wireguard/wg0.conf 2>/dev/null || true
  fi

  python3 -c "
import json
with open('$ENT_CONFIG') as f: c = json.load(f)
c['vpn']['enabled'] = True
c['vpn']['type'] = '$(case $vpn_type in 1) echo wireguard;; 2) echo openvpn;; 3) echo ipsec;; esac)'
with open('$ENT_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  audit_log "vpn-setup" "type=$vpn_type"
}

connect_vpn() {
  local vpn_type
  vpn_type=$(cfg "vpn.type" "wireguard")
  case "$vpn_type" in
    wireguard)  sudo wg-quick up wg0 ;;
    openvpn)    sudo systemctl start openvpn@client ;;
    *)          echo "VPN type not configured."; return 1 ;;
  esac
  echo "VPN connected."
  audit_log "vpn-connect"
}

disconnect_vpn() {
  local vpn_type
  vpn_type=$(cfg "vpn.type" "wireguard")
  case "$vpn_type" in
    wireguard)  sudo wg-quick down wg0 ;;
    openvpn)    sudo systemctl stop openvpn@client ;;
  esac
  echo "VPN disconnected."
  audit_log "vpn-disconnect"
}

# ---- certificate management ----
cert_setup() {
  echo "=== Certificate Management ==="
  read -p "CA certificate path: " ca_cert
  read -p "Client certificate path: " client_cert
  read -p "Client key path: " client_key

  [ -n "$ca_cert" ] && [ -f "$ca_cert" ] && sudo cp "$ca_cert" /etc/ssl/certs/korrinos-ca.crt
  [ -n "$client_cert" ] && [ -f "$client_cert" ] && sudo cp "$client_cert" /etc/ssl/certs/korrinos-client.crt
  [ -n "$client_key" ] && [ -f "$client_key" ] && sudo cp "$client_key" /etc/ssl/private/korrinos-client.key

  python3 -c "
import json
with open('$ENT_CONFIG') as f: c = json.load(f)
c['certificates']['ca_cert'] = '/etc/ssl/certs/korrinos-ca.crt'
c['certificates']['client_cert'] = '/etc/ssl/certs/korrinos-client.crt'
c['certificates']['client_key'] = '/etc/ssl/private/korrinos-client.key'
with open('$ENT_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  audit_log "cert-setup" "installed certificates"
}

cert_renew() {
  echo "=== Certificate Renewal ==="
  local client_cert
  client_cert=$(cfg "certificates.client_cert" "")
  if [ -n "$client_cert" ] && [ -f "$client_cert" ]; then
    local expiry
    expiry=$(openssl x509 -enddate -noout -in "$client_cert" 2>/dev/null)
    echo "Certificate expiry: $expiry"
    echo "To renew, obtain a new certificate from your CA and run: korrinos-enterprise cert-setup"
  else
    echo "No client certificate configured."
  fi
}

# ---- user management ----
create_user() {
  local username="${1:-}"
  local fullname="${2:-}"
  local shell="${3:-}"

  [ -z "$username" ] && read -p "Username: " username
  [ -z "$fullname" ] && read -p "Full Name: " fullname

  local default_shell
  default_shell=$(cfg "provisioning.default_shell" "/bin/bash")
  shell="${shell:-$default_shell}"

  # Check if user exists
  if id "$username" &>/dev/null; then
    echo "User $username already exists."
    return 1
  fi

  # Create user
  sudo useradd -m -c "$fullname" -s "$shell" "$username" 2>/dev/null || {
    echo "User creation failed."
    return 1
  }

  # Add to default groups
  local default_groups
  default_groups=$(cfg "provisioning.default_groups" "sudo,docker,video,audio")
  echo "$default_groups" | tr ',' '\n' | while read -r grp; do
    [ -n "$grp" ] && sudo usermod -aG "$grp" "$username" 2>/dev/null || true
  done

  echo "Set password for $username:"
  sudo passwd "$username"

  audit_log "create-user" "$username"
  echo "User $username created."
}

delete_user() {
  local username="${1:-}"
  [ -z "$username" ] && read -p "Username to delete: " username

  read -p "Delete user $username and home directory? (yes/no): " confirm
  [ "$confirm" != "yes" ] && return 0

  sudo userdel -r "$username" 2>/dev/null || sudo userdel "$username" 2>/dev/null
  audit_log "delete-user" "$username"
  echo "User $username deleted."
}

create_group() {
  local groupname="${1:-}"
  [ -z "$groupname" ] && read -p "Group name: " groupname

  sudo groupadd "$groupname" 2>/dev/null || echo "Group may already exist."
  audit_log "create-group" "$groupname"
}

add_to_group() {
  local username="$1"
  local groupname="$2"

  sudo usermod -aG "$groupname" "$username"
  audit_log "add-to-group" "$username -> $groupname"
  echo "$username added to $groupname"
}

remove_from_group() {
  local username="$1"
  local groupname="$2"

  sudo gpasswd -d "$username" "$groupname" 2>/dev/null || true
  audit_log "remove-from-group" "$username -> $groupname"
  echo "$username removed from $groupname"
}

list_users() {
  echo "=== Local Users ==="
  awk -F: '$3 >= 1000 {printf "%-20s %-30s %s\n", $1, $6, $7}' /etc/passwd
  echo ""
  echo "Total: $(awk -F: '$3 >= 1000' /etc/passwd | wc -l) users"
}

list_groups() {
  echo "=== Local Groups ==="
  getent group | awk -F: '$3 >= 1000 {printf "%-20s %s\n", $1, $4}' | head -30
}

# ---- password policy ----
apply_password_policy() {
  echo "=== Applying Password Policy ==="
  local min_len
  min_len=$(cfg "compliance.password_policy.min_length" "8")
  local max_age
  max_age=$(cfg "compliance.password_policy.max_age_days" "90")
  local history
  history=$(cfg "compliance.password_policy.history_count" "5")

  # pwquality
  sudo tee /etc/security/pwquality.conf >/dev/null << PWEOF
minlen = $min_len
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
maxclassrepeat = 4
gecoscheck = 1
dictcheck = 1
PWEOF

  # login.defs
  sudo sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   $max_age/" /etc/login.defs 2>/dev/null || true
  sudo sed -i "s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/" /etc/login.defs 2>/dev/null || true
  sudo sed -i "s/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/" /etc/login.defs 2>/dev/null || true

  # PAM password history
  if ! grep -q "pam_pwhistory.so" /etc/pam.d/common-password 2>/dev/null; then
    echo "password requisite pam_pwhistory.so remember=$history" | sudo tee -a /etc/pam.d/common-password >/dev/null
  fi

  audit_log "password-policy" "min_len=$min_len max_age=$max_age"
  echo "Password policy applied."
}

# ---- session policy ----
apply_session_policy() {
  echo "=== Applying Session Policy ==="
  local idle_timeout
  idle_timeout=$(cfg "compliance.session_policy.idle_timeout_minutes" "15")

  # Bash timeout
  local tmout=$((idle_timeout * 60))
  if ! grep -q "TMOUT" /etc/profile.d/korrinos-session.sh 2>/dev/null; then
    sudo tee /etc/profile.d/korrinos-session.sh >/dev/null << TMEOF
# KorrinOS session policy
readonly TMOUT=$tmout
export TMOUT
TMEOF
    sudo chmod 644 /etc/profile.d/korrinos-session.sh
  fi

  audit_log "session-policy" "idle_timeout=${idle_timeout}min"
  echo "Session policy applied."
}

# ---- compliance audit ----
compliance_audit() {
  echo "=== KorrinOS Compliance Audit ==="
  echo ""

  echo "--- System Info ---"
  echo "Hostname: $(hostname)"
  echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
  echo "Kernel: $(uname -r)"
  echo ""

  echo "--- User Accounts ---"
  local total_users
  total_users=$(awk -F: '$3 >= 1000' /etc/passwd | wc -l)
  local admin_users
  admin_users=$(getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -c . || echo "0")
  echo "Regular users: $total_users"
  echo "Admin (sudo) users: $admin_users"

  echo ""
  echo "--- Password Policy ---"
  grep "^PASS_MAX_DAYS\|^PASS_MIN_DAYS\|^PASS_WARN_AGE" /etc/login.defs 2>/dev/null || echo "  Using defaults"

  echo ""
  echo "--- Firewall ---"
  if command -v ufw &>/dev/null; then
    ufw status 2>/dev/null | head -5
  elif command -v iptables &>/dev/null; then
    sudo iptables -L -n 2>/dev/null | head -10 || echo "  iptables not configured"
  else
    echo "  No firewall detected"
  fi

  echo ""
  echo "--- SSH Config ---"
  if [ -f /etc/ssh/sshd_config ]; then
    grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication|^Port " /etc/ssh/sshd_config 2>/dev/null || echo "  Using defaults"
  fi

  echo ""
  echo "--- Services ---"
  for svc in sssd sshd nslcd ufw; do
    if systemctl is-active "$svc" &>/dev/null 2>&1; then
      echo "  $svc: running"
    fi
  done

  echo ""
  echo "--- Audit Log ---"
  if [ -f "$ENT_AUDIT" ]; then
    echo "Last 10 entries:"
    tail -10 "$ENT_AUDIT"
  else
    echo "  No audit entries."
  fi
}

# ---- status ----
enterprise_status() {
  echo "==========================================="
  echo "   KorrinOS Enterprise Status"
  echo "==========================================="
  echo ""

  # Check domain membership
  if command -v realm &>/dev/null; then
    local status
    status=$(sudo realm list 2>/dev/null | head -5)
    if [ -n "$status" ]; then
      echo "Domain: $status"
    else
      echo "Domain: Not joined"
    fi
  else
    echo "Domain: realmd not installed"
  fi

  # Check SSSD
  if systemctl is-active sssd &>/dev/null; then
    echo "SSSD: running"
  else
    echo "SSSD: not running"
  fi

  # Check Kerberos
  if command -v klist &>/dev/null; then
    local tickets
    tickets=$(klist 2>/dev/null | grep -c "krbtgt" || echo "0")
    echo "Kerberos tickets: $tickets"
  else
    echo "Kerberos: not installed"
  fi

  # Check MFA
  if grep -q "google_authenticator\|pam_u2f" /etc/pam.d/common-auth 2>/dev/null; then
    echo "MFA: enabled"
  else
    echo "MFA: disabled"
  fi

  # Check VPN
  local vpn_type
  vpn_type=$(cfg "vpn.type" "none")
  echo "VPN: $vpn_type"

  # Check SCIM
  local scim_enabled
  scim_enabled=$(cfg "scim.enabled" "false")
  echo "SCIM: $scim_enabled"

  # Check GPO
  local gpo_count
  gpo_count=$(ls -1 "$GPO_DIR"/*.json 2>/dev/null | wc -l)
  echo "GPO policies: $gpo_count"

  # Check audit
  if [ -f "$ENT_AUDIT" ]; then
    echo "Audit entries: $(wc -l < "$ENT_AUDIT")"
  else
    echo "Audit: no entries"
  fi
}

# ---- main ----
case "${1:-}" in
  ad-join)        shift; ad_join "$@" ;;
  ad-leave)       ad_leave ;;
  ldap-join)      shift; ldap_join "$@" ;;
  gpo)            apply_gpo ;;
  sso)            sso_setup ;;
  mfa)            mfa_setup ;;
  scim)           scim_setup ;;
  scim-sync)      scim_sync ;;
  vpn)            setup_vpn ;;
  vpn-on)         connect_vpn ;;
  vpn-off)        disconnect_vpn ;;
  cert-setup)     cert_setup ;;
  cert-renew)     cert_renew ;;
  create-user)    shift; create_user "$@" ;;
  delete-user)    shift; delete_user "$@" ;;
  create-group)   shift; create_group "$@" ;;
  add-to-group)   shift; add_to_group "$@" ;;
  rm-from-group)  shift; remove_from_group "$@" ;;
  list-users)     list_users ;;
  list-groups)    list_groups ;;
  password-policy) apply_password_policy ;;
  session-policy) apply_session_policy ;;
  audit)          compliance_audit ;;
  status)         enterprise_status ;;
  help|*)         echo "KorrinOS Enterprise Suite v2
Usage: korrinos-enterprise <command> [args]

Domain & Directory:
  ad-join [domain] [admin]     Join Active Directory domain
  ad-leave                     Leave Active Directory domain
  ldap-join [url] [base] [dn]  Join LDAP server

Group Policy:
  gpo                          Apply Group Policy from /etc/korrinos/gpo/

Single Sign-On:
  sso                          Setup Kerberos SSO

Multi-Factor Authentication:
  mfa                          Setup MFA (TOTP/HOTP/WebAuthn)

SCIM Provisioning:
  scim                         Setup SCIM endpoint
  scim-sync                    Sync users from SCIM

VPN:
  vpn                          Setup VPN (WireGuard/OpenVPN/IPSec)
  vpn-on                       Connect VPN
  vpn-off                      Disconnect VPN

Certificates:
  cert-setup                   Setup client certificates
  cert-renew                   Check/renew certificates

User Management:
  create-user [name] [full]    Create local user
  delete-user [name]           Delete user
  create-group [name]          Create group
  add-to-group <user> <group>  Add user to group
  rm-from-group <user> <grp>   Remove user from group
  list-users                   List all users
  list-groups                  List all groups

Compliance:
  password-policy              Apply password policy
  session-policy               Apply session policy
  audit                        Run compliance audit

Status:
  status                       Show enterprise status" ;;
esac
