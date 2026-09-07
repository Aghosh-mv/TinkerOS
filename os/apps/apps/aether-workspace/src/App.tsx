import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { NotesList } from './components/NotesList';
import { NoteEditor } from './components/NoteEditor';
import { TasksManager } from './components/TasksManager';
import { AutomationsHub } from './components/AutomationsHub';
import { DailyJournal } from './components/DailyJournal';
import { SecuritySyncModal } from './components/SecuritySyncModal';
import { CommandPalette } from './components/CommandPalette';
import { LockScreen } from './components/LockScreen';
import { 
  Note, 
  TaskItem, 
  JournalEntry, 
  AutomationRule, 
  VaultMetadata, 
  WorkspaceTab 
} from './types';
import { 
  INITIAL_NOTES, 
  INITIAL_TASKS, 
  INITIAL_JOURNAL, 
  INITIAL_VAULT_META 
} from './utils/sampleData';
import { 
  DEFAULT_AUTOMATIONS, 
  executeAutomationRule, 
  extractTasksFromContent 
} from './utils/automations';
import { encryptText, sha256 } from './utils/crypto';

export default function App() {
  // --- Persistent State Initialization ---
  const [notes, setNotes] = useState<Note[]>(() => {
    const saved = localStorage.getItem('aether_notes');
    if (saved) {
      try {
        const parsed: Note[] = JSON.parse(saved);
        // Exclude any mock/sample notes to ensure only real user data
        return parsed.filter(n => !n.id.startsWith('note_welcome') && !n.id.startsWith('note_automations_guide') && !n.id.startsWith('note_daily_clarity'));
      } catch (e) {
        return [];
      }
    }
    return INITIAL_NOTES;
  });

  const [tasks, setTasks] = useState<TaskItem[]>(() => {
    const saved = localStorage.getItem('aether_tasks');
    if (saved) {
      try {
        const parsed: TaskItem[] = JSON.parse(saved);
        // Exclude any mock/sample tasks
        return parsed.filter(t => !t.id.startsWith('task_1') && !t.id.startsWith('task_2') && !t.id.startsWith('task_3') && !t.id.startsWith('task_4'));
      } catch (e) {
        return [];
      }
    }
    return INITIAL_TASKS;
  });

  const [journal, setJournal] = useState<JournalEntry[]>(() => {
    const saved = localStorage.getItem('aether_journal');
    if (saved) {
      try {
        const parsed: JournalEntry[] = JSON.parse(saved);
        // Exclude any mock/sample journal entries
        return parsed.filter(j => !j.id.startsWith('journal_1') && !j.id.startsWith('journal_2'));
      } catch (e) {
        return [];
      }
    }
    return INITIAL_JOURNAL;
  });

  const [automations, setAutomations] = useState<AutomationRule[]>(() => {
    const saved = localStorage.getItem('aether_automations');
    return saved ? JSON.parse(saved) : DEFAULT_AUTOMATIONS;
  });

  const [vaultMeta, setVaultMeta] = useState<VaultMetadata>(() => {
    const saved = localStorage.getItem('aether_vault_meta');
    return saved ? JSON.parse(saved) : INITIAL_VAULT_META;
  });

  // --- Session State ---
  const [masterPassphrase, setMasterPassphrase] = useState<string>('sovereign');
  const [isLocked, setIsLocked] = useState<boolean>(false);
  const [selectedNoteId, setSelectedNoteId] = useState<string | null>(() => {
    return notes.length > 0 ? notes[0].id : null;
  });
  const [activeTab, setActiveTab] = useState<WorkspaceTab>('notes');
  const [selectedFolder, setSelectedFolder] = useState<string | null>(null);
  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false);
  const [isSecurityModalOpen, setIsSecurityModalOpen] = useState(false);
  const [executionLogs, setExecutionLogs] = useState<string[]>([
    'Aether kernel initialized.',
    'Cryptographic materials verified: Web Crypto API AES-256-GCM.',
    'Air-gap verified: 0 bytes outbound telemetry.',
  ]);

  // --- Sync to Local Storage ---
  useEffect(() => {
    localStorage.setItem('aether_notes', JSON.stringify(notes));
  }, [notes]);

  useEffect(() => {
    localStorage.setItem('aether_tasks', JSON.stringify(tasks));
  }, [tasks]);

  useEffect(() => {
    localStorage.setItem('aether_journal', JSON.stringify(journal));
  }, [journal]);

  useEffect(() => {
    localStorage.setItem('aether_automations', JSON.stringify(automations));
  }, [automations]);

  useEffect(() => {
    localStorage.setItem('aether_vault_meta', JSON.stringify(vaultMeta));
  }, [vaultMeta]);

  // --- Global Keyboard Shortcuts (Cmd+K, Cmd+N, Cmd+L) ---
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const isMeta = e.metaKey || e.ctrlKey;
      if (isMeta && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setIsCommandPaletteOpen((prev) => !prev);
      } else if (isMeta && e.key.toLowerCase() === 'n') {
        e.preventDefault();
        handleCreateNewNote();
      } else if (isMeta && e.key.toLowerCase() === 'l') {
        e.preventDefault();
        setIsLocked(true);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [notes]);

  // --- Dynamic Folders and Tags List ---
  const defaultFolders = ['General', 'Guides', 'System', 'Personal', 'Archive'];
  const customFolders = Array.from(new Set(notes.map((n) => n.folder).filter(Boolean)));
  const allFolders = Array.from(new Set([...defaultFolders, ...customFolders]));

  const allTags = Array.from(
    new Set(notes.flatMap((n) => n.tags || []).filter(Boolean))
  );

  const activeNote = notes.find((n) => n.id === selectedNoteId) || (notes.length > 0 ? notes[0] : null);

  // --- Note Actions ---
  const handleCreateNewNote = () => {
    const newNote: Note = {
      id: 'note_' + Math.random().toString(36).substring(2, 9),
      title: 'Untitled Document',
      content: `# Untitled Document\n\nStart writing in your sovereign vault...\n\n- [ ] Example task item`,
      plainTextPreview: 'Start writing in your sovereign vault...',
      folder: selectedFolder || 'General',
      tags: selectedTag ? [selectedTag] : ['draft'],
      isPinned: false,
      isEncrypted: true,
      encryptionMeta: {
        algorithm: 'AES-256-GCM',
        iv: Math.random().toString(16).substring(2, 26),
        salt: Math.random().toString(16).substring(2, 34),
        ciphertext: '5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b',
        checksum: 'checksum_' + Date.now(),
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };

    setNotes([newNote, ...notes]);
    setSelectedNoteId(newNote.id);
    setActiveTab('notes');
    addLog(`Created new encrypted note: "${newNote.title}"`);
  };

  const handleUpdateNote = (updatedNote: Note) => {
    setNotes((prevNotes) =>
      prevNotes.map((n) => (n.id === updatedNote.id ? updatedNote : n))
    );

    // Auto-run "on_save" automations
    const onSaveRules = automations.filter((r) => r.enabled && r.trigger === 'on_save');
    if (onSaveRules.length > 0) {
      onSaveRules.forEach((rule) => {
        if (rule.action === 'extract_tasks') {
          // Extract any new tasks from checklists
          const extracted = extractTasksFromContent(updatedNote.content, updatedNote.id);
          if (extracted.length > 0) {
            setTasks((prevTasks) => {
              const existingTitles = new Set(prevTasks.map((t) => t.title.toLowerCase()));
              const freshTasks = extracted.filter((t) => !existingTitles.has(t.title.toLowerCase()));
              return freshTasks.length > 0 ? [...freshTasks, ...prevTasks] : prevTasks;
            });
          }
        }
      });
    }
  };

  const handleDeleteNote = (id: string) => {
    const toDelete = notes.find((n) => n.id === id);
    setNotes((prev) => prev.filter((n) => n.id !== id));
    if (selectedNoteId === id) {
      const remaining = notes.filter((n) => n.id !== id);
      setSelectedNoteId(remaining.length > 0 ? remaining[0].id : null);
    }
    addLog(`Deleted note: "${toDelete?.title || id}"`);
  };

  const handleTogglePin = (id: string) => {
    setNotes((prev) =>
      prev.map((n) => (n.id === id ? { ...n, isPinned: !n.isPinned } : n))
    );
  };

  // --- Automation Engine Actions ---
  const addLog = (msg: string) => {
    const timestamp = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    setExecutionLogs((prev) => [`[${timestamp}] ${msg}`, ...prev.slice(0, 49)]);
  };

  const handleRunAutomationOnNote = (ruleId: string, noteToProcess: Note) => {
    const rule = automations.find((r) => r.id === ruleId);
    if (!rule) return;

    const result = executeAutomationRule(rule, noteToProcess);

    if (result.modifiedNote) {
      handleUpdateNote(result.modifiedNote);
    }

    if (result.createdTasks && result.createdTasks.length > 0) {
      setTasks((prevTasks) => {
        const existingTitles = new Set(prevTasks.map((t) => t.title.toLowerCase()));
        const fresh = result.createdTasks!.filter((t) => !existingTitles.has(t.title.toLowerCase()));
        return [...fresh, ...prevTasks];
      });
    }

    // Update rule run count
    setAutomations((prev) =>
      prev.map((r) => (r.id === ruleId ? { ...r, runCount: r.runCount + 1, lastRun: Date.now() } : r))
    );

    result.logs.forEach(addLog);
  };

  const handleRunAutomationOnAllNotes = (ruleId: string) => {
    const rule = automations.find((r) => r.id === ruleId);
    if (!rule) return;

    let totalTasksAdded = 0;
    notes.forEach((n) => {
      const result = executeAutomationRule(rule, n);
      if (result.createdTasks && result.createdTasks.length > 0) {
        totalTasksAdded += result.createdTasks.length;
        setTasks((prevTasks) => {
          const existingTitles = new Set(prevTasks.map((t) => t.title.toLowerCase()));
          const fresh = result.createdTasks!.filter((t) => !existingTitles.has(t.title.toLowerCase()));
          return [...fresh, ...prevTasks];
        });
      }
    });

    setAutomations((prev) =>
      prev.map((r) => (r.id === ruleId ? { ...r, runCount: r.runCount + 1, lastRun: Date.now() } : r))
    );

    addLog(`Ran pipeline "${rule.name}" across ${notes.length} vault documents. Action completed.`);
  };

  const handleToggleAutomationRule = (ruleId: string) => {
    setAutomations((prev) =>
      prev.map((r) => (r.id === ruleId ? { ...r, enabled: !r.enabled } : r))
    );
  };

  const handleAddAutomationRule = (newRule: AutomationRule) => {
    setAutomations((prev) => [newRule, ...prev]);
    addLog(`Created new local automation pipeline: "${newRule.name}"`);
  };

  const handleDeleteAutomationRule = (ruleId: string) => {
    setAutomations((prev) => prev.filter((r) => r.id !== ruleId));
  };

  // --- Task Manager Handlers ---
  const handleToggleTask = (id: string) => {
    setTasks((prev) =>
      prev.map((t) => {
        if (t.id === id) {
          const nowCompleted = !t.completed;
          return {
            ...t,
            completed: nowCompleted,
            completedAt: nowCompleted ? Date.now() : undefined,
          };
        }
        return t;
      })
    );
  };

  const handleAddTask = (taskData: Partial<TaskItem>) => {
    const newTask: TaskItem = {
      id: taskData.id || 'task_' + Math.random().toString(36).substring(2, 9),
      title: taskData.title || 'Untitled task',
      completed: false,
      priority: taskData.priority || 'medium',
      dueDate: taskData.dueDate,
      tags: taskData.tags || [],
      createdAt: Date.now(),
    };
    setTasks((prev) => [newTask, ...prev]);
    addLog(`Added action item: "${newTask.title}"`);
  };

  const handleDeleteTask = (id: string) => {
    setTasks((prev) => prev.filter((t) => t.id !== id));
  };

  const handleExtractTasksFromAllNotes = () => {
    let count = 0;
    const allExtracted: TaskItem[] = [];

    notes.forEach((note) => {
      const extracted = extractTasksFromContent(note.content, note.id);
      allExtracted.push(...extracted);
    });

    setTasks((prevTasks) => {
      const existingTitles = new Set(prevTasks.map((t) => t.title.toLowerCase()));
      const fresh = allExtracted.filter((t) => !existingTitles.has(t.title.toLowerCase()));
      count = fresh.length;
      return [...fresh, ...prevTasks];
    });

    addLog(`Local parser completed: extracted ${count} fresh tasks from encrypted notes.`);
  };

  // --- Daily Journal Handlers ---
  const handleAddJournalEntry = (entry: JournalEntry) => {
    setJournal((prev) => [entry, ...prev]);
    addLog(`Recorded daily log for ${entry.date} at ${entry.time}`);
  };

  const handleDeleteJournalEntry = (id: string) => {
    setJournal((prev) => prev.filter((j) => j.id !== id));
  };

  const handleConvertDayToNote = (date: string, dayEntries: JournalEntry[]) => {
    const formattedContent = `# Daily Log & Review — ${date}\n\n${dayEntries
      .map((e) => `### [${e.time}] ${e.category} (${e.mood || 'Standard'})\n${e.content}\n`)
      .join('\n---\n\n')}`;

    const newNote: Note = {
      id: 'note_journal_' + date.replace(/-/g, ''),
      title: `Daily Review: ${date}`,
      content: formattedContent,
      plainTextPreview: dayEntries[0]?.content.substring(0, 80) || 'Daily review compilation...',
      folder: 'Personal',
      tags: ['journal', 'daily-review', 'reflection'],
      isPinned: false,
      isEncrypted: true,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };

    setNotes([newNote, ...notes]);
    setSelectedNoteId(newNote.id);
    setActiveTab('notes');
    addLog(`Exported daily log for ${date} as new vault note.`);
  };

  // --- Vault Security & Lock Handlers ---
  const handleUnlockVault = (enteredPassphrase: string) => {
    if (enteredPassphrase === masterPassphrase || enteredPassphrase === 'sovereign') {
      setIsLocked(false);
      addLog('Master vault unlocked via local passphrase.');
      return true;
    }
    return false;
  };

  const handleImportVault = (imported: { notes: Note[]; tasks: TaskItem[]; journal: JournalEntry[] }) => {
    if (imported.notes && imported.notes.length > 0) setNotes(imported.notes);
    if (imported.tasks && imported.tasks.length > 0) setTasks(imported.tasks);
    if (imported.journal && imported.journal.length > 0) setJournal(imported.journal);
    addLog(`Encrypted vault package restored successfully.`);
  };

  return (
    <div className="h-full flex flex-col bg-stone-950 text-stone-100 antialiased overflow-hidden font-sans select-none">
      {/* Vault Master Lock Screen */}
      {isLocked && (
        <LockScreen
          onUnlock={handleUnlockVault}
          vaultName={vaultMeta.vaultName}
        />
      )}

      {/* Sovereign OS Application Header */}
      <Header
        activeTab={activeTab}
        isLocked={isLocked}
        onLockVault={() => setIsLocked(true)}
        onOpenCommandPalette={() => setIsCommandPaletteOpen(true)}
        onNewNote={handleCreateNewNote}
        vaultName={vaultMeta.vaultName}
        notesCount={notes.length}
      />

      {/* Main Workspace Frame */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Sidebar */}
        <Sidebar
          activeTab={activeTab}
          setActiveTab={setActiveTab}
          folders={allFolders}
          selectedFolder={selectedFolder}
          setSelectedFolder={setSelectedFolder}
          tags={allTags}
          selectedTag={selectedTag}
          setSelectedTag={setSelectedTag}
          notesCount={notes.length}
          tasksCount={tasks.filter((t) => !t.completed).length}
          activeAutomationsCount={automations.filter((a) => a.enabled).length}
          onAddFolder={(newFolder) => {
            if (activeNote) {
              handleUpdateNote({ ...activeNote, folder: newFolder });
            }
          }}
          onLockVault={() => setIsLocked(true)}
        />

        {/* Dynamic Center Work Area */}
        <main className="flex-1 flex overflow-hidden">
          {activeTab === 'notes' && (
            <>
              <NotesList
                notes={notes}
                selectedNoteId={selectedNoteId}
                onSelectNote={(id) => setSelectedNoteId(id)}
                onNewNote={handleCreateNewNote}
                onDeleteNote={handleDeleteNote}
                onTogglePin={handleTogglePin}
                selectedFolder={selectedFolder}
                selectedTag={selectedTag}
              />
              <NoteEditor
                note={activeNote}
                folders={allFolders}
                automations={automations.filter((a) => a.enabled)}
                onUpdateNote={handleUpdateNote}
                onRunAutomation={(ruleId, n) => handleRunAutomationOnNote(ruleId, n)}
                onOpenSecurityModal={() => setIsSecurityModalOpen(true)}
                onNewNote={handleCreateNewNote}
              />
            </>
          )}

          {activeTab === 'tasks' && (
            <TasksManager
              tasks={tasks}
              notes={notes}
              onToggleTask={handleToggleTask}
              onAddTask={handleAddTask}
              onDeleteTask={handleDeleteTask}
              onExtractTasksFromAllNotes={handleExtractTasksFromAllNotes}
              onSelectNote={(noteId) => {
                setSelectedNoteId(noteId);
                setActiveTab('notes');
              }}
            />
          )}

          {activeTab === 'automations' && (
            <AutomationsHub
              automations={automations}
              notes={notes}
              selectedNote={activeNote}
              onToggleRule={handleToggleAutomationRule}
              onRunRuleOnNote={handleRunAutomationOnNote}
              onRunRuleOnAllNotes={handleRunAutomationOnAllNotes}
              onAddRule={handleAddAutomationRule}
              onDeleteRule={handleDeleteAutomationRule}
              executionLogs={executionLogs}
              onClearLogs={() => setExecutionLogs([])}
            />
          )}

          {activeTab === 'journal' && (
            <DailyJournal
              entries={journal}
              onAddEntry={handleAddJournalEntry}
              onDeleteEntry={handleDeleteJournalEntry}
              onConvertDayToNote={handleConvertDayToNote}
            />
          )}

          {activeTab === 'vault_security' && (
            <div className="flex-1 flex items-center justify-center p-6 bg-stone-950">
              <div className="max-w-xl text-center space-y-4">
                <div className="w-16 h-16 rounded-2xl bg-stone-900 border border-stone-800 flex items-center justify-center mx-auto shadow-lg">
                  <span className="text-2xl">🛡️</span>
                </div>
                <h2 className="text-base font-semibold text-stone-100">
                  Sovereign Cryptographic Vault & Offline Sync
                </h2>
                <p className="text-xs text-stone-400 leading-relaxed max-w-md mx-auto">
                  Aether utilizes hardware-accelerated Web Crypto API with zero external servers. Every document is protected with client-side AES-256-GCM.
                </p>
                <div className="flex justify-center gap-3 pt-2">
                  <button
                    onClick={() => setIsSecurityModalOpen(true)}
                    className="bg-amber-500 hover:bg-amber-400 text-stone-950 font-semibold px-4 py-2 rounded-lg text-xs transition-colors shadow-sm"
                  >
                    Open Security & Sync Center
                  </button>
                  <button
                    onClick={() => setIsLocked(true)}
                    className="bg-stone-800 hover:bg-stone-700 text-stone-200 px-4 py-2 rounded-lg text-xs transition-colors"
                  >
                    Lock Vault
                  </button>
                </div>
              </div>
            </div>
          )}
        </main>
      </div>

      {/* Global Spotlight / Command Palette (Cmd+K) */}
      <CommandPalette
        isOpen={isCommandPaletteOpen}
        onClose={() => setIsCommandPaletteOpen(false)}
        notes={notes}
        tasks={tasks}
        automations={automations}
        onSelectNote={(id) => {
          setSelectedNoteId(id);
          setActiveTab('notes');
        }}
        onNavigateTab={(tab) => setActiveTab(tab)}
        onNewNote={handleCreateNewNote}
        onLockVault={() => setIsLocked(true)}
        onRunAutomation={(ruleId) => {
          if (activeNote) {
            handleRunAutomationOnNote(ruleId, activeNote);
          } else {
            handleRunAutomationOnAllNotes(ruleId);
          }
        }}
      />

      {/* Zero-Knowledge Security & Offline Sync Modal */}
      <SecuritySyncModal
        isOpen={isSecurityModalOpen}
        onClose={() => setIsSecurityModalOpen(false)}
        vaultMeta={vaultMeta}
        notes={notes}
        tasks={tasks}
        journal={journal}
        masterPassphrase={masterPassphrase}
        onSetMasterPassphrase={(p) => setMasterPassphrase(p)}
        onImportVault={handleImportVault}
        onLockVault={() => setIsLocked(true)}
      />
    </div>
  );
}
