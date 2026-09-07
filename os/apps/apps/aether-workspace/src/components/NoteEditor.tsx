import React, { useState, useEffect, useRef } from 'react';
import { 
  Lock, 
  Unlock, 
  ShieldCheck, 
  Sparkles, 
  Eye, 
  Edit3, 
  Columns, 
  Hash, 
  CheckSquare, 
  Clock, 
  Folder, 
  Tag as TagIcon, 
  Share2, 
  FileCheck, 
  Bold, 
  Italic, 
  Code, 
  List, 
  Table as TableIcon,
  ChevronDown,
  Play,
  Plus
} from 'lucide-react';
import { Note, AutomationRule } from '../types';
import { calculateTextMetrics, formatMarkdown } from '../utils/automations';
import { sha256 } from '../utils/crypto';

interface NoteEditorProps {
  note: Note | null;
  folders: string[];
  automations: AutomationRule[];
  onUpdateNote: (updatedNote: Note) => void;
  onRunAutomation: (ruleId: string, note: Note) => void;
  onOpenSecurityModal: () => void;
  onNewNote?: () => void;
}

export const NoteEditor: React.FC<NoteEditorProps> = ({
  note,
  folders,
  automations,
  onUpdateNote,
  onRunAutomation,
  onOpenSecurityModal,
  onNewNote,
}) => {
  if (!note) {
    return (
      <div className="flex-1 bg-stone-950 flex flex-col items-center justify-center text-stone-500 p-8 select-none">
        <ShieldCheck className="w-12 h-12 text-stone-700 mb-3" />
        <p className="text-sm font-medium text-stone-300">No Document Selected</p>
        <p className="text-xs text-stone-500 mt-1.5 max-w-sm text-center leading-relaxed">
          Create an encrypted record in your sovereign vault or choose a note from the list.
        </p>
        {onNewNote && (
          <button
            onClick={onNewNote}
            className="mt-4 inline-flex items-center gap-2 bg-amber-500 hover:bg-amber-400 text-stone-950 px-4 py-2 rounded-lg text-xs font-semibold shadow-md transition-all cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Create New Document</span>
          </button>
        )}
      </div>
    );
  }

  const [title, setTitle] = useState(note.title);
  const [content, setContent] = useState(note.content);
  const [folder, setFolder] = useState(note.folder);
  const [tags, setTags] = useState<string[]>(note.tags);
  const [newTagInput, setNewTagInput] = useState('');
  const [viewMode, setViewMode] = useState<'split' | 'edit' | 'preview'>('split');
  const [liveChecksum, setLiveChecksum] = useState(note.encryptionMeta?.checksum || 'computing...');
  const [showAutomationsMenu, setShowAutomationsMenu] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Sync state whenever selected note changes
  useEffect(() => {
    setTitle(note.title);
    setContent(note.content);
    setFolder(note.folder);
    setTags(note.tags);
    sha256(note.content).then(setLiveChecksum);
  }, [note.id]);

  // Handle title/content changes with debounce update
  const handleContentChange = (newContent: string) => {
    setContent(newContent);
    sha256(newContent).then(setLiveChecksum);
    onUpdateNote({
      ...note,
      title,
      content: newContent,
      folder,
      tags,
      updatedAt: Date.now(),
    });
  };

  const handleTitleChange = (newTitle: string) => {
    setTitle(newTitle);
    onUpdateNote({
      ...note,
      title: newTitle,
      content,
      folder,
      tags,
      updatedAt: Date.now(),
    });
  };

  const handleFolderChange = (newFolder: string) => {
    setFolder(newFolder);
    onUpdateNote({
      ...note,
      title,
      content,
      folder: newFolder,
      tags,
      updatedAt: Date.now(),
    });
  };

  const handleAddTag = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && newTagInput.trim()) {
      e.preventDefault();
      const cleanTag = newTagInput.trim().replace(/^#/, '').toLowerCase();
      if (!tags.includes(cleanTag)) {
        const updatedTags = [...tags, cleanTag];
        setTags(updatedTags);
        setNewTagInput('');
        onUpdateNote({
          ...note,
          tags: updatedTags,
          updatedAt: Date.now(),
        });
      }
    }
  };

  const handleRemoveTag = (tagToRemove: string) => {
    const updatedTags = tags.filter((t) => t !== tagToRemove);
    setTags(updatedTags);
    onUpdateNote({
      ...note,
      tags: updatedTags,
      updatedAt: Date.now(),
    });
  };

  // Quick insertion helpers for editor
  const insertTextAtCursor = (prefix: string, suffix: string = '') => {
    if (!textareaRef.current) return;
    const textarea = textareaRef.current;
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selected = content.substring(start, end);
    const replacement = `${prefix}${selected}${suffix}`;
    const newContent = content.substring(0, start) + replacement + content.substring(end);
    handleContentChange(newContent);

    setTimeout(() => {
      textarea.focus();
      textarea.setSelectionRange(start + prefix.length, end + prefix.length);
    }, 0);
  };

  const metrics = calculateTextMetrics(content);

  // Simple, safe Markdown renderer for preview
  const renderSimpleMarkdown = (text: string) => {
    const lines = text.split('\n');
    return lines.map((line, idx) => {
      // Headings
      if (line.startsWith('# ')) {
        return <h1 key={idx} className="text-xl font-bold text-stone-100 mt-4 mb-2 pb-1 border-b border-stone-800">{line.replace('# ', '')}</h1>;
      }
      if (line.startsWith('## ')) {
        return <h2 key={idx} className="text-lg font-semibold text-stone-200 mt-3 mb-1.5">{line.replace('## ', '')}</h2>;
      }
      if (line.startsWith('### ')) {
        return <h3 key={idx} className="text-sm font-semibold text-amber-300 mt-2.5 mb-1">{line.replace('### ', '')}</h3>;
      }
      // Checkboxes
      if (/^[ \t]*-\s*\[([ xX])\]\s*(.+)$/.test(line)) {
        const match = line.match(/^[ \t]*-\s*\[([ xX])\]\s*(.+)$/);
        const isChecked = match?.[1].toLowerCase() === 'x';
        const taskText = match?.[2] || '';
        return (
          <div key={idx} className="flex items-center gap-2 py-0.5 text-xs text-stone-300">
            <span className={`w-3.5 h-3.5 rounded border flex items-center justify-center ${
              isChecked ? 'bg-amber-500 border-amber-600 text-stone-950 font-bold text-[10px]' : 'border-stone-600 bg-stone-900'
            }`}>
              {isChecked ? '✓' : ''}
            </span>
            <span className={isChecked ? 'line-through text-stone-500' : 'text-stone-300'}>{taskText}</span>
          </div>
        );
      }
      // Bullet list
      if (line.startsWith('- ')) {
        return (
          <div key={idx} className="flex items-start gap-2 py-0.5 text-xs text-stone-300 pl-2">
            <span className="text-amber-500 font-bold">•</span>
            <span>{line.substring(2)}</span>
          </div>
        );
      }
      // Blockquote
      if (line.startsWith('> ')) {
        return (
          <blockquote key={idx} className="border-l-2 border-amber-500/60 pl-3 italic text-xs text-stone-400 my-2">
            {line.replace('> ', '')}
          </blockquote>
        );
      }
      // Code block lines or plain text
      if (line.startsWith('```')) {
        return <div key={idx} className="font-mono text-[11px] text-amber-400 bg-stone-900 px-2 py-1 rounded my-1">{line}</div>;
      }
      if (line.trim() === '') {
        return <div key={idx} className="h-2" />;
      }
      return <p key={idx} className="text-xs text-stone-300 leading-relaxed">{line}</p>;
    });
  };

  return (
    <div className="flex-1 bg-stone-950 flex flex-col h-full overflow-hidden select-text">
      {/* Top Document Metadata Bar */}
      <div className="h-12 border-b border-stone-800/80 px-4 flex items-center justify-between bg-stone-900/40 text-xs">
        <div className="flex items-center space-x-3">
          {/* Folder Selector */}
          <div className="flex items-center space-x-1.5 text-stone-400">
            <Folder className="w-3.5 h-3.5 text-amber-400" />
            <select
              value={folder}
              onChange={(e) => handleFolderChange(e.target.value)}
              className="bg-transparent border-none text-xs text-stone-300 focus:outline-none cursor-pointer hover:text-stone-100"
            >
              {folders.map((f) => (
                <option key={f} value={f} className="bg-stone-900 text-stone-200">
                  {f}
                </option>
              ))}
            </select>
          </div>

          <div className="h-3.5 w-px bg-stone-800" />

          {/* Encryption Indicator Badge */}
          <button
            onClick={onOpenSecurityModal}
            className="flex items-center space-x-1.5 px-2 py-1 rounded bg-stone-900/80 hover:bg-stone-850 border border-stone-800/80 text-stone-400 hover:text-stone-200 transition-colors"
            title="Click to view Zero-Knowledge Cryptographic Proof"
          >
            <ShieldCheck className="w-3.5 h-3.5 text-amber-400" />
            <span className="text-[11px] font-mono text-stone-300">AES-256 E2EE</span>
          </button>
        </div>

        {/* View Mode & Local Automator Trigger */}
        <div className="flex items-center space-x-2">
          {/* View Mode Toggle */}
          <div className="flex items-center bg-stone-900 rounded-lg p-0.5 border border-stone-800">
            <button
              onClick={() => setViewMode('edit')}
              className={`p-1 rounded text-xs transition-colors ${
                viewMode === 'edit' ? 'bg-stone-800 text-amber-400' : 'text-stone-500 hover:text-stone-300'
              }`}
              title="Editor View"
            >
              <Edit3 className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setViewMode('split')}
              className={`p-1 rounded text-xs transition-colors ${
                viewMode === 'split' ? 'bg-stone-800 text-amber-400' : 'text-stone-500 hover:text-stone-300'
              }`}
              title="Split View (Editor + Live Preview)"
            >
              <Columns className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setViewMode('preview')}
              className={`p-1 rounded text-xs transition-colors ${
                viewMode === 'preview' ? 'bg-stone-800 text-amber-400' : 'text-stone-500 hover:text-stone-300'
              }`}
              title="Rendered Markdown Preview"
            >
              <Eye className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Local Automator Quick Dropdown */}
          <div className="relative">
            <button
              onClick={() => setShowAutomationsMenu(!showAutomationsMenu)}
              className="flex items-center space-x-1.5 bg-sky-950/60 hover:bg-sky-900/60 text-sky-400 border border-sky-800/40 px-2.5 py-1 rounded-lg text-xs font-medium transition-colors shadow-sm"
              title="Run Deterministic Local Automation on this Note"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Automations</span>
              <ChevronDown className="w-3 h-3" />
            </button>

            {showAutomationsMenu && (
              <div className="absolute right-0 mt-1 w-64 bg-stone-900 border border-stone-800 rounded-lg shadow-xl py-1 z-30 divide-y divide-stone-800/60">
                <div className="px-3 py-1.5 text-[10px] uppercase font-semibold text-stone-500 tracking-wider">
                  Offline Rule Engine
                </div>
                {automations.map((rule) => (
                  <button
                    key={rule.id}
                    onClick={() => {
                      onRunAutomation(rule.id, note);
                      setShowAutomationsMenu(false);
                    }}
                    className="w-full text-left px-3 py-2 hover:bg-stone-800/70 text-xs flex items-center justify-between text-stone-300 group"
                  >
                    <div>
                      <div className="font-medium text-stone-200 group-hover:text-amber-400">{rule.name}</div>
                      <div className="text-[10px] text-stone-500 line-clamp-1">{rule.description}</div>
                    </div>
                    <Play className="w-3 h-3 text-stone-600 group-hover:text-amber-400 shrink-0 ml-2" />
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Title & Tag Row */}
      <div className="px-6 pt-4 pb-2 border-b border-stone-800/40 bg-stone-950">
        <input
          type="text"
          value={title}
          onChange={(e) => handleTitleChange(e.target.value)}
          placeholder="Document Title..."
          className="w-full bg-transparent text-xl font-bold text-stone-100 placeholder-stone-600 focus:outline-none tracking-tight"
        />

        {/* Tags List & Add Input */}
        <div className="flex flex-wrap items-center gap-1.5 mt-2">
          <TagIcon className="w-3 h-3 text-stone-500 mr-0.5" />
          {tags.map((tag) => (
            <span
              key={tag}
              className="inline-flex items-center gap-1 bg-stone-900 border border-stone-800 px-2 py-0.5 rounded-full text-[10px] font-mono text-stone-300"
            >
              <span>#{tag}</span>
              <button
                onClick={() => handleRemoveTag(tag)}
                className="hover:text-rose-400 text-stone-500"
              >
                ×
              </button>
            </span>
          ))}
          <input
            type="text"
            placeholder="+ tag..."
            value={newTagInput}
            onChange={(e) => setNewTagInput(e.target.value)}
            onKeyDown={handleAddTag}
            className="bg-transparent border-none text-[11px] text-stone-400 placeholder-stone-600 focus:outline-none w-20 py-0.5 font-mono"
          />
        </div>
      </div>

      {/* Editor Formatting Ribbon */}
      <div className="h-9 border-b border-stone-800/60 px-6 flex items-center space-x-1 bg-stone-900/30 text-stone-400">
        <button
          onClick={() => insertTextAtCursor('**', '**')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Bold (**text**)"
        >
          <Bold className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={() => insertTextAtCursor('*', '*')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Italic (*text*)"
        >
          <Italic className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={() => insertTextAtCursor('`', '`')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Inline Code (`code`)"
        >
          <Code className="w-3.5 h-3.5" />
        </button>
        <div className="h-3 w-px bg-stone-800 mx-1" />
        <button
          onClick={() => insertTextAtCursor('### ')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 text-xs font-bold transition-colors"
          title="Heading (### )"
        >
          H3
        </button>
        <button
          onClick={() => insertTextAtCursor('- [ ] ')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Task Checkbox (- [ ] )"
        >
          <CheckSquare className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={() => insertTextAtCursor('- ')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Bullet Point (- )"
        >
          <List className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={() => insertTextAtCursor('\n| Column 1 | Column 2 |\n| :--- | :--- |\n| Data A | Data B |\n')}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Markdown Table"
        >
          <TableIcon className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={() => insertTextAtCursor(`\n_Timestamp: ${new Date().toLocaleTimeString()}_ \n`)}
          className="p-1.5 hover:bg-stone-800 rounded hover:text-stone-200 transition-colors"
          title="Insert Local Timestamp"
        >
          <Clock className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Main Content Area (Split / Edit / Preview) */}
      <div className="flex-1 flex overflow-hidden">
        {/* Editor Pane */}
        {(viewMode === 'edit' || viewMode === 'split') && (
          <div className="flex-1 flex flex-col p-6 overflow-hidden border-r border-stone-800/40">
            <textarea
              ref={textareaRef}
              value={content}
              onChange={(e) => handleContentChange(e.target.value)}
              placeholder="Write your encrypted notes in Markdown... (e.g. - [ ] Checklist item)"
              className="w-full h-full bg-transparent resize-none focus:outline-none text-xs text-stone-200 font-mono leading-relaxed placeholder-stone-600"
              spellCheck={false}
            />
          </div>
        )}

        {/* Live Preview Pane */}
        {(viewMode === 'preview' || viewMode === 'split') && (
          <div className="flex-1 p-6 overflow-y-auto bg-stone-950/40 text-xs">
            <div className="max-w-2xl prose prose-invert">
              {renderSimpleMarkdown(content)}
            </div>
          </div>
        )}
      </div>

      {/* Document Status & Cryptographic Integrity Footer */}
      <div className="h-8 border-t border-stone-800/80 px-4 bg-stone-900/60 flex items-center justify-between text-[11px] font-mono text-stone-500 select-none">
        <div className="flex items-center space-x-3">
          <span>{metrics.words} words</span>
          <span>•</span>
          <span>{metrics.chars} chars</span>
          <span>•</span>
          <span>~{metrics.readingTimeMin} min read</span>
        </div>

        <div className="flex items-center space-x-2 truncate max-w-xs sm:max-w-md">
          <FileCheck className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
          <span className="text-stone-400 truncate">SHA-256: {liveChecksum.substring(0, 16)}...</span>
        </div>
      </div>
    </div>
  );
};
