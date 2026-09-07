import React, { useState } from 'react';
import { ShieldCheck, Lock, Key, ArrowRight, Eye, EyeOff } from 'lucide-react';

interface LockScreenProps {
  onUnlock: (passphrase: string) => boolean | Promise<boolean>;
  vaultName: string;
}

export const LockScreen: React.FC<LockScreenProps> = ({ onUnlock, vaultName }) => {
  const [passphrase, setPassphrase] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState(false);
  const [isVerifying, setIsVerifying] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!passphrase.trim()) return;

    setIsVerifying(true);
    setError(false);

    try {
      const success = await onUnlock(passphrase.trim());
      if (!success) {
        setError(true);
      }
    } catch {
      setError(true);
    } finally {
      setIsVerifying(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-stone-950 flex flex-col items-center justify-center p-4 select-none">
      {/* Subtle Background Glow */}
      <div className="absolute w-96 h-96 bg-amber-500/5 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-sm flex flex-col items-center text-center space-y-6 relative z-10">
        {/* Animated Vault Emblem */}
        <div className="w-16 h-16 rounded-2xl bg-stone-900 border border-stone-800 flex items-center justify-center shadow-xl">
          <Lock className="w-8 h-8 text-amber-400" />
        </div>

        <div>
          <h1 className="text-xl font-bold tracking-tight text-stone-100">
            {vaultName}
          </h1>
          <p className="text-xs text-stone-500 mt-1 font-mono">
            Zero-Knowledge AES-256-GCM Encrypted
          </p>
        </div>

        {/* Unlock Form */}
        <form onSubmit={handleSubmit} className="w-full space-y-3">
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              autoFocus
              placeholder="Enter Master Vault Passphrase..."
              value={passphrase}
              onChange={(e) => {
                setPassphrase(e.target.value);
                setError(false);
              }}
              className={`w-full bg-stone-900 border rounded-xl px-4 py-2.5 text-xs text-stone-100 placeholder-stone-500 focus:outline-none transition-all ${
                error
                  ? 'border-rose-500/80 ring-2 ring-rose-500/20'
                  : 'border-stone-800 focus:border-amber-500/60 focus:ring-2 focus:ring-amber-500/10'
              }`}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-10 top-2.5 text-stone-500 hover:text-stone-300 transition-colors"
            >
              {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
            <button
              type="submit"
              disabled={isVerifying || !passphrase.trim()}
              className="absolute right-2.5 top-2 p-1 bg-amber-500 hover:bg-amber-400 disabled:opacity-40 text-stone-950 rounded-lg transition-colors"
            >
              <ArrowRight className="w-4 h-4 stroke-[2.5]" />
            </button>
          </div>

          {error && (
            <p className="text-[11px] text-rose-400 font-medium">
              Invalid master passphrase. Try again.
            </p>
          )}

          {/* Quick Helper Badge */}
          <div className="bg-stone-900/60 border border-stone-800/80 rounded-lg p-2.5 text-[11px] text-stone-400 space-y-1">
            <div className="flex items-center justify-center gap-1 text-stone-300 font-medium">
              <ShieldCheck className="w-3.5 h-3.5 text-amber-400" />
              <span>Airgapped Cryptographic Key</span>
            </div>
            <p className="text-[10px] text-stone-500">
              Demo vault default passphrase: <span className="text-amber-400 font-mono font-semibold">sovereign</span>
            </p>
          </div>
        </form>
      </div>

      {/* Lockscreen Footer Status */}
      <div className="absolute bottom-6 text-[11px] font-mono text-stone-600 flex items-center space-x-3">
        <span>Hardware PBKDF2</span>
        <span>•</span>
        <span>0 Network Dependencies</span>
        <span>•</span>
        <span>Aether OS</span>
      </div>
    </div>
  );
};
