import React, { useState, useEffect, useRef } from 'react';
import { 
  Search, 
  FileText, 
  CheckSquare, 
  Workflow, 
  BookOpen, 
  ShieldCheck, 
  Lock, 
  Plus, 
  Download,
  ArrowRight,
  Sparkles
} from 'lucide-react';
import { Note, TaskItem, WorkspaceTab, AutomationRule } from '../types';

interface CommandPaletteProps {
  isOpen: boolean;
  onClose: () => void;
  notes: Note[];
  tasks: TaskItem[];
  automations: AutomationRule[];
  onSelectNote: (id: string) => void;
  onNavigateTab: (tab: WorkspaceTab) => void;
  onNewNote: () => void;
  onLockVault: () => void;
  onRunAutomation: (ruleId: string) => void;
}

export const CommandPalette: React.FC<CommandPaletteProps> = ({
  isOpen,
  onClose,
  notes,
  tasks,
  automations,
  onSelectNote,
  onNavigateTab,
  onNewNote,
  onLockVault,
  onRunAutomation,
}) => {
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setQuery('');
      setSelectedIndex(0);
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  // Build command items list
  interface CommandItem {
    id: string;
    category: 'Actions' | 'Documents' | 'Tasks' | 'Automations';
    title: string;
    subtitle?: string;
    icon: React.ReactNode;
    action: () => void;
  }

  const items: CommandItem[] = [];

  // System Actions
  items.push({
    id: 'act_new_note',
    category: 'Actions',
    title: 'Create New Encrypted Note',
    subtitle: 'Opens blank document in sovereign vault',
    icon: <Plus className="w-4 h-4 text-amber-400" />,
    action: () => { onNewNote(); onClose(); },
  });

  items.push({
    id: 'act_lock_vault',
    category: 'Actions',
    title: 'Lock Encrypted Vault',
    subtitle: 'Wipes decrypted materials from active RAM',
    icon: <Lock className="w-4 h-4 text-rose-400" />,
    action: () => { onLockVault(); onClose(); },
  });

  items.push({
    id: 'act_nav_tasks',
    category: 'Actions',
    title: 'Switch to Action Tracker',
    subtitle: 'View daily focus checklist',
    icon: <CheckSquare className="w-4 h-4 text-emerald-400" />,
    action: () => { onNavigateTab('tasks'); onClose(); },
  });

  items.push({
    id: 'act_nav_automations',
    category: 'Actions',
    title: 'Open Local Automator Engine',
    subtitle: 'Inspect offline rule pipelines',
    icon: <Workflow className="w-4 h-4 text-sky-400" />,
    action: () => { onNavigateTab('automations'); onClose(); },
  });

  items.push({
    id: 'act_nav_journal',
    category: 'Actions',
    title: 'Open Daily Journal',
    subtitle: 'Micro-log thoughts and reflections',
    icon: <BookOpen className="w-4 h-4 text-amber-400" />,
    action: () => { onNavigateTab('journal'); onClose(); },
  });

  items.push({
    id: 'act_nav_security',
    category: 'Actions',
    title: 'Inspect Cryptography & Offline Sync',
    subtitle: 'AES-256-GCM status and vault backup',
    icon: <ShieldCheck className="w-4 h-4 text-amber-400" />,
    action: () => { onNavigateTab('vault_security'); onClose(); },
  });

  // Filter notes matching query
  notes.forEach((note) => {
    items.push({
      id: `note_${note.id}`,
      category: 'Documents',
      title: note.title || 'Untitled Document',
      subtitle: `${note.folder} • ${note.tags.map((t) => '#' + t).join(' ')}`,
      icon: <FileText className="w-4 h-4 text-stone-400" />,
      action: () => { onSelectNote(note.id); onNavigateTab('notes'); onClose(); },
    });
  });

  // Automations matching query
  automations.forEach((auto) => {
    items.push({
      id: `auto_${auto.id}`,
      category: 'Automations',
      title: `Run: ${auto.name}`,
      subtitle: auto.description,
      icon: <Sparkles className="w-4 h-4 text-sky-400" />,
      action: () => { onRunAutomation(auto.id); onClose(); },
    });
  });

  // Filter items by query
  const filtered = items.filter((item) => {
    if (!query.trim()) return true;
    const q = query.toLowerCase();
    return (
      item.title.toLowerCase().includes(q) ||
      (item.subtitle && item.subtitle.toLowerCase().includes(q)) ||
      item.category.toLowerCase().includes(q)
    );
  }).slice(0, 10);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev + 1) % (filtered.length || 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev - 1 + filtered.length) % (filtered.length || 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (filtered[selectedIndex]) {
        filtered[selectedIndex].action();
      }
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  return (
    <div 
      className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-start justify-center pt-24 px-4 select-none"
      onClick={onClose}
    >
      <div 
        className="bg-stone-900 border border-stone-800 rounded-2xl w-full max-w-xl shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Search Bar Input */}
        <div className="flex items-center px-4 py-3 border-b border-stone-800 bg-stone-900">
          <Search className="w-4 h-4 text-stone-500 mr-3 shrink-0" />
          <input
            ref={inputRef}
            type="text"
            placeholder="Type a command, search encrypted notes, or run automations..."
            value={query}
            onChange={(e) => { setQuery(e.target.value); setSelectedIndex(0); }}
            onKeyDown={handleKeyDown}
            className="flex-1 bg-transparent text-sm text-stone-100 placeholder-stone-500 focus:outline-none"
          />
          <kbd className="bg-stone-950 border border-stone-800 text-[10px] font-mono text-stone-400 px-1.5 py-0.5 rounded">
            ESC
          </kbd>
        </div>

        {/* Results List */}
        <div className="max-h-80 overflow-y-auto p-2 divide-y divide-stone-800/40">
          {filtered.length === 0 ? (
            <div className="py-8 text-center text-stone-500 text-xs">
              No matching commands or encrypted records found.
            </div>
          ) : (
            filtered.map((item, idx) => {
              const isSelected = idx === selectedIndex;
              return (
                <div
                  key={item.id}
                  onClick={item.action}
                  onMouseEnter={() => setSelectedIndex(idx)}
                  className={`flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer transition-colors text-xs ${
                    isSelected
                      ? 'bg-amber-500/15 text-stone-100 border border-amber-500/30'
                      : 'text-stone-300 hover:bg-stone-800/50'
                  }`}
                >
                  <div className="flex items-center space-x-3 min-w-0">
                    <div className="shrink-0">{item.icon}</div>
                    <div className="truncate">
                      <div className={`font-medium ${isSelected ? 'text-amber-300' : 'text-stone-200'}`}>
                        {item.title}
                      </div>
                      {item.subtitle && (
                        <div className="text-[10px] text-stone-500 truncate">
                          {item.subtitle}
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center space-x-2 shrink-0 ml-2">
                    <span className="text-[9px] uppercase font-mono tracking-wider px-1.5 py-0.5 rounded bg-stone-950 text-stone-500">
                      {item.category}
                    </span>
                    {isSelected && <ArrowRight className="w-3.5 h-3.5 text-amber-400" />}
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Command Palette Footer */}
        <div className="h-8 border-t border-stone-800 bg-stone-950 px-4 flex items-center justify-between text-[10px] font-mono text-stone-500">
          <div className="flex items-center space-x-3">
            <span>↑↓ Navigate</span>
            <span>↵ Select</span>
            <span>esc Dismiss</span>
          </div>
          <span>Aether OS Spotlight</span>
        </div>
      </div>
    </div>
  );
};
