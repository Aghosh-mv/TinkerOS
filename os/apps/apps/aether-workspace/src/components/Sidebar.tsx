import React, { useState } from 'react';
import { 
  FileText, 
  CheckSquare, 
  Workflow, 
  BookOpen, 
  ShieldCheck, 
  Folder, 
  Tag, 
  Lock, 
  Plus, 
  HardDrive,
  Activity,
  ChevronRight,
  FolderPlus
} from 'lucide-react';
import { WorkspaceTab } from '../types';

interface SidebarProps {
  activeTab: WorkspaceTab;
  setActiveTab: (tab: WorkspaceTab) => void;
  folders: string[];
  selectedFolder: string | null;
  setSelectedFolder: (folder: string | null) => void;
  tags: string[];
  selectedTag: string | null;
  setSelectedTag: (tag: string | null) => void;
  notesCount: number;
  tasksCount: number;
  activeAutomationsCount: number;
  onAddFolder: (folderName: string) => void;
  onLockVault: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  folders,
  selectedFolder,
  setSelectedFolder,
  tags,
  selectedTag,
  setSelectedTag,
  notesCount,
  tasksCount,
  activeAutomationsCount,
  onAddFolder,
  onLockVault,
}) => {
  const [isAddingFolder, setIsAddingFolder] = useState(false);
  const [newFolderName, setNewFolderName] = useState('');

  const handleCreateFolder = (e: React.FormEvent) => {
    e.preventDefault();
    if (newFolderName.trim()) {
      onAddFolder(newFolderName.trim());
      setNewFolderName('');
      setIsAddingFolder(false);
    }
  };

  return (
    <aside className="w-64 bg-stone-900/95 border-r border-stone-800/80 flex flex-col h-full select-none text-stone-300">
      {/* Primary Workspace Navigation */}
      <div className="p-3 space-y-1">
        <button
          onClick={() => { setActiveTab('notes'); setSelectedFolder(null); setSelectedTag(null); }}
          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all ${
            activeTab === 'notes' && !selectedFolder && !selectedTag
              ? 'bg-amber-500/15 text-amber-300 font-semibold border border-amber-500/30'
              : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/60'
          }`}
        >
          <div className="flex items-center space-x-2.5">
            <FileText className="w-4 h-4" />
            <span>All Documents</span>
          </div>
          <span className="text-[11px] font-mono px-1.5 py-0.2 rounded bg-stone-800 text-stone-400">
            {notesCount}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('tasks')}
          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all ${
            activeTab === 'tasks'
              ? 'bg-amber-500/15 text-amber-300 font-semibold border border-amber-500/30'
              : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/60'
          }`}
        >
          <div className="flex items-center space-x-2.5">
            <CheckSquare className="w-4 h-4" />
            <span>Action Tracker</span>
          </div>
          <span className="text-[11px] font-mono px-1.5 py-0.2 rounded bg-stone-800 text-stone-400">
            {tasksCount}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('automations')}
          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all ${
            activeTab === 'automations'
              ? 'bg-amber-500/15 text-amber-300 font-semibold border border-amber-500/30'
              : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/60'
          }`}
        >
          <div className="flex items-center space-x-2.5">
            <Workflow className="w-4 h-4 text-sky-400" />
            <span>Local Automator</span>
          </div>
          <span className="text-[11px] font-mono px-1.5 py-0.2 rounded bg-sky-950/60 border border-sky-800/40 text-sky-400">
            {activeAutomationsCount} active
          </span>
        </button>

        <button
          onClick={() => setActiveTab('journal')}
          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all ${
            activeTab === 'journal'
              ? 'bg-amber-500/15 text-amber-300 font-semibold border border-amber-500/30'
              : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/60'
          }`}
        >
          <div className="flex items-center space-x-2.5">
            <BookOpen className="w-4 h-4" />
            <span>Daily Journal</span>
          </div>
        </button>

        <button
          onClick={() => setActiveTab('vault_security')}
          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all ${
            activeTab === 'vault_security'
              ? 'bg-amber-500/15 text-amber-300 font-semibold border border-amber-500/30'
              : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/60'
          }`}
        >
          <div className="flex items-center space-x-2.5">
            <ShieldCheck className="w-4 h-4 text-amber-400" />
            <span>Security & Sync</span>
          </div>
          <span className="text-[10px] font-mono uppercase tracking-wider text-amber-400 font-semibold">
            E2EE
          </span>
        </button>
      </div>

      <div className="px-4 py-2">
        <div className="h-px bg-stone-800/70" />
      </div>

      {/* Folders Section */}
      <div className="flex-1 overflow-y-auto px-3 space-y-4">
        <div>
          <div className="flex items-center justify-between px-2 mb-1.5">
            <span className="text-[11px] font-semibold tracking-wider uppercase text-stone-500">Folders</span>
            <button
              onClick={() => setIsAddingFolder(!isAddingFolder)}
              className="text-stone-500 hover:text-stone-300 p-0.5 rounded transition-colors"
              title="Add New Folder"
            >
              <FolderPlus className="w-3.5 h-3.5" />
            </button>
          </div>

          {isAddingFolder && (
            <form onSubmit={handleCreateFolder} className="mb-2 px-1">
              <input
                type="text"
                autoFocus
                placeholder="Folder name..."
                value={newFolderName}
                onChange={(e) => setNewFolderName(e.target.value)}
                className="w-full bg-stone-950 border border-stone-700 rounded px-2 py-1 text-xs text-stone-200 focus:outline-none focus:border-amber-500"
              />
            </form>
          )}

          <div className="space-y-0.5">
            {folders.map((folder) => {
              const isSelected = selectedFolder === folder && activeTab === 'notes';
              return (
                <button
                  key={folder}
                  onClick={() => {
                    setActiveTab('notes');
                    setSelectedFolder(isSelected ? null : folder);
                    setSelectedTag(null);
                  }}
                  className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-md text-xs transition-colors ${
                    isSelected
                      ? 'bg-stone-800 text-stone-100 font-medium'
                      : 'text-stone-400 hover:text-stone-200 hover:bg-stone-800/40'
                  }`}
                >
                  <div className="flex items-center space-x-2 truncate">
                    <Folder className={`w-3.5 h-3.5 ${isSelected ? 'text-amber-400' : 'text-stone-500'}`} />
                    <span className="truncate">{folder}</span>
                  </div>
                  {isSelected && <ChevronRight className="w-3 h-3 text-amber-400" />}
                </button>
              );
            })}
          </div>
        </div>

        {/* Tags Section */}
        {tags.length > 0 && (
          <div>
            <div className="px-2 mb-1.5 flex items-center justify-between">
              <span className="text-[11px] font-semibold tracking-wider uppercase text-stone-500">Tags</span>
            </div>
            <div className="flex flex-wrap gap-1 px-1">
              {tags.map((tag) => {
                const isSelected = selectedTag === tag && activeTab === 'notes';
                return (
                  <button
                    key={tag}
                    onClick={() => {
                      setActiveTab('notes');
                      setSelectedTag(isSelected ? null : tag);
                      setSelectedFolder(null);
                    }}
                    className={`inline-flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full transition-all ${
                      isSelected
                        ? 'bg-amber-500 text-stone-950 font-medium shadow-sm'
                        : 'bg-stone-800/80 text-stone-400 hover:text-stone-200 hover:bg-stone-750'
                    }`}
                  >
                    <span>#{tag}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* Sovereign Hardware & OS Diagnostic Footprint Footer */}
      <div className="p-3 border-t border-stone-800/80 bg-stone-950/60 space-y-2 text-xs">
        <div className="flex items-center justify-between text-stone-500 text-[11px]">
          <span className="flex items-center gap-1">
            <Activity className="w-3 h-3 text-emerald-400" />
            Zero-Cloud Airgap
          </span>
          <span className="text-emerald-400 font-mono">100% OK</span>
        </div>

        <div className="w-full bg-stone-800/60 rounded-full h-1 overflow-hidden">
          <div className="bg-amber-500 h-full w-[14%]" />
        </div>

        <div className="flex items-center justify-between text-[10px] text-stone-400 font-mono">
          <span>AES-GCM-256 Vault</span>
          <span>Zero Telemetry</span>
        </div>
      </div>
    </aside>
  );
};
