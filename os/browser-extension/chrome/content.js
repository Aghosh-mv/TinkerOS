// TinkerOS Password Manager - Content Script
// Detects password fields and communicates with native messaging

(function() {
    'use strict';
    
    let lastFocusedPasswordField = null;
    let notificationShown = false;
    
    // Monitor for password fields
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.nodeType === Node.ELEMENT_NODE) {
                    checkForPasswordFields(node);
                }
            });
        });
    });
    
    // Start observing
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    // Check for password fields
    function checkForPasswordFields(element) {
        const passwordFields = element.querySelectorAll
            ? element.querySelectorAll('input[type="password"]')
            : [];
        
        passwordFields.forEach((field) => {
            if (!field.dataset.tinkerMonitored) {
                field.dataset.tinkerMonitored = 'true';
                
                // Add focus listener
                field.addEventListener('focus', () => {
                    lastFocusedPasswordField = field;
                    
                    if (!notificationShown) {
                        showPasswordOffer();
                    }
                });
                
                // Add blur listener
                field.addEventListener('blur', () => {
                    setTimeout(() => {
                        notificationShown = false;
                    }, 5000);
                });
            }
        });
    }
    
    // Show password offer notification
    function showPasswordOffer() {
        notificationShown = true;
        
        // Create notification element
        const notification = document.createElement('div');
        notification.id = 'tinker-password-notification';
        notification.innerHTML = `
            <div style="
                position: fixed;
                top: 20px;
                right: 20px;
                background: #1a1b26;
                color: #c0caf5;
                padding: 20px;
                border-radius: 10px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.3);
                z-index: 999999;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                max-width: 350px;
                border: 1px solid #4c566a;
            ">
                <div style="display: flex; align-items: center; margin-bottom: 15px;">
                    <span style="font-size: 24px; margin-right: 10px;">🔐</span>
                    <strong style="font-size: 16px;">TinkerOS Password Manager</strong>
                </div>
                <p style="margin: 0 0 15px 0; color: #a6accd;">
                    Password field detected on <strong>${window.location.hostname}</strong>
                </p>
                <div style="display: flex; gap: 10px;">
                    <button id="tinker-generate" style="
                        flex: 1;
                        padding: 10px;
                        background: #7aa2f7;
                        color: #1a1b26;
                        border: none;
                        border-radius: 5px;
                        cursor: pointer;
                        font-weight: bold;
                    ">Generate Password</button>
                    <button id="tinker-use-existing" style="
                        flex: 1;
                        padding: 10px;
                        background: #3b4261;
                        color: #c0caf5;
                        border: none;
                        border-radius: 5px;
                        cursor: pointer;
                    ">Use Existing</button>
                </div>
                <button id="tinker-dismiss" style="
                    width: 100%;
                    padding: 8px;
                    background: transparent;
                    color: #565f89;
                    border: none;
                    border-radius: 5px;
                    cursor: pointer;
                    margin-top: 10px;
                ">Dismiss</button>
            </div>
        `;
        
        document.body.appendChild(notification);
        
        // Add event listeners
        document.getElementById('tinker-generate').addEventListener('click', generatePassword);
        document.getElementById('tinker-use-existing').addEventListener('click', useExisting);
        document.getElementById('tinker-dismiss').addEventListener('click', dismissNotification);
    }
    
    // Generate password
    function generatePassword() {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
        let password = '';
        for (let i = 0; i < 20; i++) {
            password += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        // Fill the password field
        if (lastFocusedPasswordField) {
            lastFocusedPasswordField.value = password;
            lastFocusedPasswordField.dispatchEvent(new Event('input', { bubbles: true }));
            
            // Copy to clipboard
            navigator.clipboard.writeText(password).catch(() => {});
            
            // Store locally
            chrome.storage.local.get(['passwords'], (result) => {
                const passwords = result.passwords || {};
                passwords[window.location.hostname] = {
                    username: findUsernameField(),
                    password: password,
                    url: window.location.href,
                    created: new Date().toISOString()
                };
                chrome.storage.local.set({ passwords });
            });
            
            showSuccess('Password generated and filled!');
        }
        
        dismissNotification();
    }
    
    // Find username field
    function findUsernameField() {
        const usernameSelectors = [
            'input[type="email"]',
            'input[name="email"]',
            'input[name="username"]',
            'input[name="user"]',
            'input[name="login"]',
            'input[id*="email"]',
            'input[id*="user"]',
            'input[autocomplete="username"]',
            'input[autocomplete="email"]'
        ];
        
        for (const selector of usernameSelectors) {
            const field = document.querySelector(selector);
            if (field && field.value) {
                return field.value;
            }
        }
        
        return '';
    }
    
    // Use existing password
    function useExisting() {
        chrome.storage.local.get(['passwords'], (result) => {
            const passwords = result.passwords || {};
            const stored = passwords[window.location.hostname];
            
            if (stored) {
                if (lastFocusedPasswordField) {
                    lastFocusedPasswordField.value = stored.password;
                    lastFocusedPasswordField.dispatchEvent(new Event('input', { bubbles: true }));
                    
                    // Fill username if available
                    if (stored.username) {
                        const usernameField = document.querySelector('input[type="email"], input[name="email"], input[name="username"]');
                        if (usernameField) {
                            usernameField.value = stored.username;
                            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                    }
                    
                    showSuccess('Credentials filled!');
                }
            } else {
                showSuccess('No saved password for this site. Use Generate instead.');
            }
        });
        
        dismissNotification();
    }
    
    // Show success message
    function showSuccess(message) {
        const success = document.createElement('div');
        success.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #9ece6a;
            color: #1a1b26;
            padding: 15px 20px;
            border-radius: 8px;
            font-weight: bold;
            z-index: 999999;
            animation: fadeIn 0.3s ease;
        `;
        success.textContent = message;
        document.body.appendChild(success);
        
        setTimeout(() => {
            success.style.animation = 'fadeOut 0.3s ease';
            setTimeout(() => success.remove(), 300);
        }, 2000);
    }
    
    // Dismiss notification
    function dismissNotification() {
        const notification = document.getElementById('tinker-password-notification');
        if (notification) {
            notification.style.animation = 'fadeOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }
    }
    
    // Check existing fields
    checkForPasswordFields(document);
    
    // Add animation styles
    const style = document.createElement('style');
    style.textContent = `
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @keyframes fadeOut {
            from { opacity: 1; transform: translateY(0); }
            to { opacity: 0; transform: translateY(-10px); }
        }
    `;
    document.head.appendChild(style);
})();
