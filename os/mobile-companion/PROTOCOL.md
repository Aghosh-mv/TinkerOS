# TinkerOS Mobile Companion Protocol

## Overview
The TinkerOS Mobile Companion Protocol enables seamless integration between TinkerOS desktop and mobile devices (phone, tablet, watch).

## Features

### 🎮 Remote Control
- Media playback control (play/pause/next/prev)
- Volume control
- System power (lock/sleep/shutdown/reboot)
- Keyboard/mouse input
- Custom commands

### 📱 Notification Mirroring
- Real-time desktop notification mirroring
- Action buttons on notifications
- Notification history sync
- Priority filtering

### 📁 File Transfer
- Bidirectional file transfer
- Progress tracking
- Resume support
- Multiple files

### 🖥️ System Monitoring
- CPU/RAM/Disk usage
- Battery status
- Network status
- Temperature sensors

### 🎨 Second Screen
- Extend desktop to mobile
- Touch input
- Custom layouts

## Protocol

### WebSocket Connection
```
ws://<desktop-ip>:8766/ws?device_id=<id>&token=<token>
```

### Message Format
```json
{
  "type": "command|notification|file|status|heartbeat",
  "id": "unique-message-id",
  "timestamp": "ISO8601",
  "data": {}
}
```

### Command Types

#### Remote Control
```json
{
  "type": "command",
  "data": {
    "action": "media_play|media_pause|volume_up|lock_screen|...",
    "params": {}
  }
}
```

#### File Transfer
```json
{
  "type": "file_start",
  "data": {
    "filename": "photo.jpg",
    "size": 2048576,
    "mime_type": "image/jpeg"
  }
}
```

#### Notification
```json
{
  "type": "notification",
  "data": {
    "app": "Firefox",
    "title": "Download complete",
    "body": "file.zip downloaded",
    "actions": [{"id": "open", "label": "Open"}],
    "priority": "high"
  }
}
```

### Pairing Flow
1. Desktop generates 6-digit code + QR code
2. Mobile app enters code or scans QR
3. WebSocket connection established
4. Device registered and trusted
4. Capabilities exchanged

## Security

- End-to-end encryption (Noise protocol)
- Device pairing with verification
- Capability-based permissions
- Local network only by default
- Tailscale support for remote access

## Mobile App Capabilities

### Required
- `notifications` - Receive notifications
- `remote_control` - Basic media/system control

### Optional
- `file_transfer` - Send/receive files
- `second_screen` - Display mirroring/extension
- `keyboard_mouse` - Full input control
- `shell` - Command execution
- `screenshot` - Capture desktop
- `clipboard` - Sync clipboard
