// TinkerOS Password Manager - Popup Script

document.getElementById('generate').addEventListener('click', () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < 20; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    
    navigator.clipboard.writeText(password).then(() => {
        showStatus('Password generated and copied!', 'success');
    });
});

document.getElementById('useExisting').addEventListener('click', () => {
    chrome.tabs.query({active: true, currentWindow: true}, (tabs) => {
        const url = new URL(tabs[0].url);
        const hostname = url.hostname;
        
        chrome.storage.local.get(['passwords'], (result) => {
            const passwords = result.passwords || {};
            const stored = passwords[hostname];
            
            if (stored) {
                navigator.clipboard.writeText(stored.password).then(() => {
                    showStatus(`Password for ${hostname} copied!`, 'success');
                });
            } else {
                showStatus(`No saved password for ${hostname}`, 'error');
            }
        });
    });
});

document.getElementById('viewSaved').addEventListener('click', () => {
    const savedList = document.getElementById('savedList');
    
    if (savedList.style.display === 'none') {
        chrome.storage.local.get(['passwords'], (result) => {
            const passwords = result.passwords || {};
            const entries = Object.entries(passwords);
            
            if (entries.length === 0) {
                savedList.innerHTML = '<div class="saved-item">No saved passwords</div>';
            } else {
                savedList.innerHTML = entries.map(([site, data]) => `
                    <div class="saved-item">
                        <span class="site">${site}</span>
                        <button class="copy-btn" data-site="${site}">Copy</button>
                    </div>
                `).join('');
                
                // Add copy handlers
                savedList.querySelectorAll('.copy-btn').forEach(btn => {
                    btn.addEventListener('click', () => {
                        const site = btn.dataset.site;
                        const password = passwords[site].password;
                        navigator.clipboard.writeText(password);
                        showStatus(`Password for ${site} copied!`, 'success');
                    });
                });
            }
            
            savedList.style.display = 'block';
        });
    } else {
        savedList.style.display = 'none';
    }
});

document.getElementById('clearAll').addEventListener('click', () => {
    if (confirm('Are you sure you want to clear all saved passwords?')) {
        chrome.storage.local.remove(['passwords'], () => {
            showStatus('All data cleared', 'success');
        });
    }
});

function showStatus(message, type) {
    const status = document.getElementById('status');
    status.textContent = message;
    status.className = `status ${type}`;
    status.style.display = 'block';
    
    setTimeout(() => {
        status.style.display = 'none';
    }, 3000);
}
