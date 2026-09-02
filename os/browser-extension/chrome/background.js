// TinkerOS Password Manager - Background Script

// Listen for messages from content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'passwordDetected') {
        // Show notification
        chrome.notifications.create({
            type: 'basic',
            iconUrl: 'icon.png',
            title: 'TinkerOS Password Manager',
            message: `Password field detected on ${message.hostname}`,
            buttons: [
                { title: 'Generate Password' },
                { title: 'Dismiss' }
            ],
            priority: 2
        });
    }
});

// Handle notification clicks
chrome.notifications.onClicked.addListener((notificationId) => {
    chrome.action.openPopup();
});

// Handle password generation requests
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'generatePassword') {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
        let password = '';
        for (let i = 0; i < 20; i++) {
            password += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        sendResponse({ password });
    }
    return true;
});

// Auto-lock after 5 minutes of inactivity
let lastActivity = Date.now();
const LOCK_TIMEOUT = 5 * 60 * 1000;

chrome.alarms.create('lockCheck', { periodInMinutes: 1 });

chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === 'lockCheck') {
        if (Date.now() - lastActivity > LOCK_TIMEOUT) {
            // Clear sensitive data from memory
            chrome.storage.local.set({ locked: true });
        }
    }
});

// Update activity timestamp
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    lastActivity = Date.now();
    chrome.storage.local.set({ locked: false });
});
