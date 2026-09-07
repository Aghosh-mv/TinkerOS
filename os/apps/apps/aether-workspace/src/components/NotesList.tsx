import React, { useState } from 'react';
import { 
  Search, 
  Pin, 
  Trash2, 
  Lock, 
  Calendar, 
  Folder, 
  ArrowUpDown,
  FilePlus,
  SlidersHorizontal
} from 'lucide-react';
import { Note } from '../types';

interface NotesListProps {
  notes: Note[];
  selectedNoteId: string | null;
  onSelectNote: (id: string) => void;
  onNewNote: () => void;
  onDeleteNote: (id: string) => void;
  onTogglePin: (id: string) => void;
  selectedFolder: string | null;
  selectedTag: string | null;
}

export const NotesList: React.FC<NotesListProps> = ({
  notes,
  selectedNoteId,
  onSelectNote,
  onNewNote,
  onDeleteNote,
  onTogglePin,
  selectedFolder,
  selectedTag,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [sortBy, setSortBy] = useState<'updated' | 'created' | 'title'>('updated');

  // Filter notes based on folder, tag, and search query
  const filteredNotes = notes.filter((note) => {
    if (selectedFolder && note.folder !== selectedFolder) return false;
    if (selectedTag && !note.tags.includes(selectedTag)) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const inTitle = note.title.toLowerCase().includes(q);
      const inContent = note.content.toLowerCase().includes(q);
      const inTags = note.tags.some((t) => t.toLowerCase().includes(q));
      return inTitle || inContent || inTags;
    }
    return true;
  });

  // Sort notes: pinned first, then by selected sort
  const sortedNotes = [...filteredNotes].sort((a, b) => {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;

    if (sortBy === 'updated') return b.updatedAt - a.updatedAt;
    if (sortBy === 'created') return b.createdAt - a.createdAt;
    if (sortBy === 'title') return a.title.localeCompare(b.title);
    return 0;
  });

  const formatDate = (timestamp: number) => {
    const date = new Date(timestamp);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    if (isToday) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  return (
    <div className="w-80 bg-stone-900/60 border-r border-stone-800/80 flex flex-col h-full select-none">
      {/* Search & Sort Header */}
      <div className="p-3 border-b border-stone-800/80 space-y-2">
        <div className="relative">
          <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-stone-500" />
          <input
            type="text"
            placeholder="Filter encrypted notes..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-stone-950/80 border border-stone-800/90 rounded-lg pl-8 pr-3 py-1.5 text-xs text-stone-200 placeholder-stone-500 focus:outline-none focus:border-amber-500/60 transition-colors"
          />
        </div>

        <div className="flex items-center justify-between text-[11px] text-stone-400">
          <div className="flex items-center gap-1">
            {selectedFolder && (
              <span className="bg-stone-800 text-stone-300 px-1.5 py-0.5 rounded flex items-center gap-1">
                <Folder className="w-3 h-3" /> {selectedFolder}
              </span>
            )}
            {selectedTag && (
              <span className="bg-stone-800 text-stone-300 px-1.5 py-0.5 rounded">
                #{selectedTag}
              </span>
            )}
            {!selectedFolder && !selectedTag && (
              <span>{sortedNotes.length} {sortedNotes.length === 1 ? 'document' : 'documents'}</span>
            )}
          </div>

          <div className="flex items-center gap-1">
            <button
              onClick={() => {
                if (sortBy === 'updated') setSortBy('created');
                else if (sortBy === 'created') setSortBy('title');
                else setSortBy('updated');
              }}
              className="hover:text-stone-200 flex items-center gap-1 px-1.5 py-0.5 rounded hover:bg-stone-800 transition-colors"
              title="Change sort order"
            >
              <ArrowUpDown className="w-3 h-3" />
              <span className="capitalize">{sortBy}</span>
            </button>
          </div>
        </div>
      </div>

      {/* Notes List Stream */}
      <div className="flex-1 overflow-y-auto divide-y divide-stone-800/50 p-1.5 space-y-1">
        {sortedNotes.length === 0 ? (
          <div className="p-8 text-center text-stone-500 space-y-3">
            <p className="text-xs">No documents match your filter.</p>
            <button
              onClick={onNewNote}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-stone-800 hover:bg-stone-700 text-stone-200 text-xs rounded-lg transition-colors"
            >
              <FilePlus className="w-3.5 h-3.5" />
              <span>Create Note</span>
            </button>
          </div>
        ) : (
          sortedNotes.map((note) => {
            const isSelected = selectedNoteId === note.id;
            const snippet = note.content
              .replace(/#+\s+/g, '')
              .replace(/\[[ xX]\]/g, '')
              .replace(/[-*]\s+/g, '')
              .substring(0, 85);

            return (
              <div
                key={note.id}
                onClick={() => onSelectNote(note.id)}
                className={`group relative p-3 rounded-lg cursor-pointer transition-all ${
                  isSelected
                    ? 'bg-amber-500/10 border border-amber-500/30 text-stone-100 shadow-sm'
                    : 'hover:bg-stone-800/50 border border-transparent text-stone-300'
                }`}
              >
                {/* Top Row: Title, Pin, Lock */}
                <div className="flex items-start justify-between gap-2 mb-1">
                  <div className="flex items-center gap-1.5 flex-1 min-w-0">
                    <h3 className={`text-xs font-semibold truncate ${isSelected ? 'text-amber-300' : 'text-stone-200'}`}>
                      {note.title || 'Untitled Document'}
                    </h3>
                  </div>

                  <div className="flex items-center space-x-1 shrink-0">
                    {note.isPinned && (
                      <Pin className="w-3 h-3 text-amber-400 fill-amber-400" />
                    )}
                    {note.isEncrypted && (
                      <Lock className="w-3 h-3 text-stone-500 group-hover:text-amber-400 transition-colors" />
                    )}
                  </div>
                </div>

                {/* Content Snippet Preview */}
                <p className="text-[11px] text-stone-400 line-clamp-2 leading-relaxed mb-2 font-normal">
                  {snippet || 'Empty note...'}
                </p>

                {/* Bottom Row: Metadata (Date, Folder, Tags, Quick Pin/Delete) */}
                <div className="flex items-center justify-between text-[10px] text-stone-500">
                  <div className="flex items-center space-x-2 truncate">
                    <span>{formatDate(note.updatedAt)}</span>
                    <span>•</span>
                    <span className="truncate">{note.folder}</span>
                  </div>

                  {/* Hover Quick Actions */}
                  <div className="opacity-0 group-hover:opacity-100 flex items-center space-x-1 transition-opacity">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onTogglePin(note.id);
                      }}
                      className="p-1 hover:text-amber-400 rounded transition-colors"
                      title={note.isPinned ? "Unpin Note" : "Pin Note to Top"}
                    >
                      <Pin className="w-3 h-3" />
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteNote(note.id);
                      }}
                      className="p-1 hover:text-rose-400 rounded transition-colors"
                      title="Delete Note"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                </div>

                {/* Tags preview */}
                {note.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1 mt-2">
                    {note.tags.slice(0, 3).map((tag) => (
                      <span
                        key={tag}
                        className="text-[9px] px-1.5 py-0.2 rounded bg-stone-800 text-stone-400 font-mono"
                      >
                        #{tag}
                      </span>
                    ))}
                    {note.tags.length > 3 && (
                      <span className="text-[9px] text-stone-500 font-mono">
                        +{note.tags.length - 3}
                      </span>
                    )}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
