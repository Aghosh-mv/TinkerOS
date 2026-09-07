import React, { useState } from 'react';
import { 
  BookOpen, 
  Plus, 
  Calendar, 
  Clock, 
  Smile, 
  Flame, 
  Feather, 
  Send, 
  FileText,
  ChevronLeft,
  ChevronRight,
  Trash2
} from 'lucide-react';
import { JournalEntry } from '../types';

interface DailyJournalProps {
  entries: JournalEntry[];
  onAddEntry: (entry: JournalEntry) => void;
  onDeleteEntry: (id: string) => void;
  onConvertDayToNote: (date: string, entries: JournalEntry[]) => void;
}

export const DailyJournal: React.FC<DailyJournalProps> = ({
  entries,
  onAddEntry,
  onDeleteEntry,
  onConvertDayToNote,
}) => {
  const [selectedDate, setSelectedDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [inputText, setInputText] = useState('');
  const [category, setCategory] = useState<'Reflection' | 'Idea' | 'Standup' | 'Log'>('Reflection');
  const [mood, setMood] = useState<'Focused' | 'Energetic' | 'Calm' | 'Productive'>('Focused');

  const handlePostEntry = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputText.trim()) return;

    const now = new Date();
    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const newEntry: JournalEntry = {
      id: 'journal_' + Math.random().toString(36).substring(2, 9),
      date: selectedDate,
      time: timeStr,
      content: inputText.trim(),
      category,
      mood,
      createdAt: Date.now(),
    };

    onAddEntry(newEntry);
    setInputText('');
  };

  const dayEntries = entries.filter((e) => e.date === selectedDate).sort((a, b) => a.createdAt - b.createdAt);

  const stepDate = (days: number) => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + days);
    setSelectedDate(d.toISOString().split('T')[0]);
  };

  const isToday = selectedDate === new Date().toISOString().split('T')[0];

  return (
    <div className="flex-1 bg-stone-950 flex flex-col h-full overflow-hidden select-none">
      {/* Top Header & Date Navigation */}
      <div className="h-14 border-b border-stone-800/80 px-6 flex items-center justify-between bg-stone-900/40">
        <div className="flex items-center space-x-3">
          <BookOpen className="w-5 h-5 text-amber-400" />
          <div>
            <h2 className="text-sm font-semibold text-stone-200">Daily Life Log & Reflections</h2>
            <p className="text-[11px] text-stone-500 font-mono">
              Offline stream of thoughts, standups, and daily notes
            </p>
          </div>
        </div>

        {/* Date Selector */}
        <div className="flex items-center space-x-2">
          <div className="flex items-center bg-stone-900 border border-stone-800 rounded-lg p-1 text-xs">
            <button
              onClick={() => stepDate(-1)}
              className="p-1 text-stone-400 hover:text-stone-200 rounded transition-colors"
              title="Previous Day"
            >
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
            <span className="font-mono text-stone-300 px-2 font-medium">
              {isToday ? 'Today' : selectedDate}
            </span>
            <button
              onClick={() => stepDate(1)}
              className="p-1 text-stone-400 hover:text-stone-200 rounded transition-colors"
              title="Next Day"
            >
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {dayEntries.length > 0 && (
            <button
              onClick={() => onConvertDayToNote(selectedDate, dayEntries)}
              className="flex items-center space-x-1.5 bg-stone-800 hover:bg-stone-700 text-stone-200 border border-stone-700 px-3 py-1.5 rounded-lg text-xs transition-colors"
              title="Compile today's entries into an encrypted vault document"
            >
              <FileText className="w-3.5 h-3.5 text-amber-400" />
              <span>Export as Note</span>
            </button>
          )}
        </div>
      </div>

      {/* Main Journal Stream */}
      <div className="flex-1 overflow-y-auto p-6 max-w-3xl w-full mx-auto flex flex-col justify-between">
        {/* Entries List */}
        <div className="space-y-4 mb-6">
          {dayEntries.length === 0 ? (
            <div className="text-center py-16 text-stone-600 space-y-2">
              <Feather className="w-10 h-10 mx-auto text-stone-700" />
              <p className="text-xs text-stone-400 font-medium">No logs for {selectedDate}</p>
              <p className="text-[11px]">Capture a quick thought, observation, or milestone below.</p>
            </div>
          ) : (
            dayEntries.map((entry) => (
              <div
                key={entry.id}
                className="group relative bg-stone-900/60 border border-stone-800/80 rounded-xl p-4 hover:border-stone-700 transition-all shadow-sm"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-2">
                    <span className="text-xs font-mono font-semibold text-amber-400">
                      {entry.time}
                    </span>
                    <span className="text-stone-700">•</span>
                    <span className="text-[10px] font-medium uppercase tracking-wider px-2 py-0.5 rounded bg-stone-800 text-stone-300">
                      {entry.category}
                    </span>
                    {entry.mood && (
                      <span className="text-[10px] px-2 py-0.5 rounded bg-stone-950 text-stone-400 border border-stone-800/80">
                        {entry.mood}
                      </span>
                    )}
                  </div>

                  <button
                    onClick={() => onDeleteEntry(entry.id)}
                    className="opacity-0 group-hover:opacity-100 text-stone-500 hover:text-rose-400 p-1 rounded transition-opacity"
                    title="Delete entry"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                <p className="text-xs text-stone-200 leading-relaxed whitespace-pre-wrap select-text">
                  {entry.content}
                </p>
              </div>
            ))
          )}
        </div>

        {/* Quick Micro-Entry Composer */}
        <form onSubmit={handlePostEntry} className="bg-stone-900 border border-stone-800 rounded-xl p-4 shadow-xl">
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            placeholder="Record a thought, breakthrough, or quick note for today..."
            rows={3}
            className="w-full bg-transparent text-xs text-stone-100 placeholder-stone-500 resize-none focus:outline-none leading-relaxed"
          />

          <div className="flex flex-wrap items-center justify-between pt-3 border-t border-stone-800 gap-2">
            <div className="flex items-center space-x-2 text-xs">
              {/* Category Pill */}
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value as any)}
                className="bg-stone-950 border border-stone-800 rounded-md px-2 py-1 text-[11px] text-stone-300 focus:outline-none"
              >
                <option value="Reflection">Reflection</option>
                <option value="Idea">Idea</option>
                <option value="Standup">Standup</option>
                <option value="Log">Log</option>
              </select>

              {/* Mood Pill */}
              <select
                value={mood}
                onChange={(e) => setMood(e.target.value as any)}
                className="bg-stone-950 border border-stone-800 rounded-md px-2 py-1 text-[11px] text-stone-300 focus:outline-none"
              >
                <option value="Focused">Focused</option>
                <option value="Energetic">Energetic</option>
                <option value="Calm">Calm</option>
                <option value="Productive">Productive</option>
              </select>
            </div>

            <button
              type="submit"
              disabled={!inputText.trim()}
              className="bg-amber-500 hover:bg-amber-400 disabled:opacity-40 text-stone-950 px-4 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition-all shadow-sm"
            >
              <span>Record</span>
              <Send className="w-3 h-3" />
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
