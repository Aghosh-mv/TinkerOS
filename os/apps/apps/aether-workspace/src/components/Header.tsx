import React from 'react';
import { 
  ShieldCheck, 
  Lock, 
  Search, 
  Plus, 
  Cpu, 
  WifiOff, 
  SlidersHorizontal,
  HardDrive
} from 'lucide-react';
import { WorkspaceTab } from '../types';

interface HeaderProps {
  activeTab: WorkspaceTab;
  isLocked: boolean;
  onLockVault: () => void;
  onOpenCommandPalette: () => void;
  onNewNote: () => void;
  vaultName: string;
  notesCount: number;
}

export const Header: React.FC<HeaderProps> = ({
  activeTab,
  isLocked,
  onLockVault,
  onOpenCommandPalette,
  onNewNote,
  vaultName,
  notesCount,
}) => {
  const getTabTitle = () => {
    switch (activeTab) {
      case 'notes': return 'Notes & Documents';
      case 'tasks': return 'Action Tracker';
      case 'journal': return 'Daily Log & Journal';
      case 'automations': return 'Local Automator Engine';
      case 'vault_security': return 'Vault Cryptography & Sync';
      default: return 'Aether';
    }
  };

  return (
    <header className="h-14 border-b border-stone-800/80 bg-stone-900/90 backdrop-blur-md px-4 flex items-center justify-between select-none z-20">
      {/* OS Window Controls & Branding */}
      <div className="flex items-center space-x-3">
        {/* macOS Traffic Lights */}
        <div className="flex items-center space-x-2 mr-2">
          <div className="w-3 h-3 rounded-full bg-rose-500/80 border border-rose-600/50 hover:opacity-80 cursor-pointer transition-opacity" title="Close Workspace" />
          <div className="w-3 h-3 rounded-full bg-amber-500/80 border border-amber-600/50 hover:opacity-80 cursor-pointer transition-opacity" title="Minimize" />
          <div className="w-3 h-3 rounded-full bg-emerald-500/80 border border-emerald-600/50 hover:opacity-80 cursor-pointer transition-opacity" title="Full Screen" />
        </div>

        <div className="h-4 w-px bg-stone-800" />

        <div className="flex items-center space-x-2">
          <span className="font-semibold tracking-tight text-stone-200 text-sm flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
            Aether
          </span>
          <span className="text-stone-600 text-xs font-mono">/</span>
          <span className="text-xs text-stone-400 font-medium">{getTabTitle()}</span>
        </div>
      </div>

      {/* System Sovereign Metrics & Telemetry Indicator */}
      <div className="hidden md:flex items-center space-x-4 text-xs font-mono text-stone-400">
        <div className="flex items-center gap-1.5 bg-stone-950/60 px-2.5 py-1 rounded-md border border-stone-800/60">
          <WifiOff className="w-3 h-3 text-emerald-400" />
          <span className="text-emerald-400 font-medium">Air-gapped</span>
          <span className="text-stone-600">|</span>
          <span className="text-stone-400">0 B egress</span>
        </div>

        <div className="flex items-center gap-1.5 bg-stone-950/60 px-2.5 py-1 rounded-md border border-stone-800/60">
          <ShieldCheck className="w-3.5 h-3.5 text-amber-400" />
          <span className="text-stone-300">AES-256-GCM</span>
        </div>

        <div className="flex items-center gap-1.5 bg-stone-950/60 px-2.5 py-1 rounded-md border border-stone-800/60">
          <HardDrive className="w-3 h-3 text-stone-400" />
          <span className="text-stone-400">{notesCount} local records</span>
        </div>
      </div>

      {/* Action Controls */}
      <div className="flex items-center space-x-2">
        {/* Command Search Bar Trigger */}
        <button
          onClick={onOpenCommandPalette}
          className="flex items-center space-x-2 bg-stone-800/80 hover:bg-stone-750 text-stone-300 hover:text-stone-100 px-3 py-1.5 rounded-lg border border-stone-700/60 text-xs transition-colors shadow-sm"
          title="Spotlight Search (Cmd+K)"
        >
          <Search className="w-3.5 h-3.5 text-stone-400" />
          <span className="hidden sm:inline text-stone-400">Search or run...</span>
          <kbd className="bg-stone-900 border border-stone-700 text-stone-400 px-1.5 py-0.5 rounded text-[10px] font-mono">
            ⌘K
          </kbd>
        </button>

        {/* Quick New Note Button */}
        <button
          onClick={onNewNote}
          className="flex items-center space-x-1.5 bg-amber-500 hover:bg-amber-400 text-stone-950 font-medium px-3 py-1.5 rounded-lg text-xs transition-all shadow-sm active:scale-95"
          title="Create New Note (Cmd+N)"
        >
          <Plus className="w-3.5 h-3.5 stroke-[2.5]" />
          <span className="hidden sm:inline">New Note</span>
        </button>

        {/* Lock Vault Button */}
        <button
          onClick={onLockVault}
          className="flex items-center justify-center p-1.5 rounded-lg bg-stone-800/60 hover:bg-stone-750 text-stone-400 hover:text-amber-300 border border-stone-700/60 transition-colors"
          title={isLocked ? "Vault Locked" : "Lock Encrypted Vault"}
        >
          <Lock className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};
