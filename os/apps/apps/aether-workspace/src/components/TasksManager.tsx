import React, { useState } from 'react';
import { 
  CheckSquare, 
  Square, 
  Plus, 
  Trash2, 
  Sparkles, 
  AlertCircle, 
  Calendar, 
  Tag as TagIcon, 
  Clock, 
  ArrowUpRight,
  Filter,
  CheckCircle2
} from 'lucide-react';
import { TaskItem, Priority, Note } from '../types';

interface TasksManagerProps {
  tasks: TaskItem[];
  notes: Note[];
  onToggleTask: (id: string) => void;
  onAddTask: (task: Partial<TaskItem>) => void;
  onDeleteTask: (id: string) => void;
  onExtractTasksFromAllNotes: () => void;
  onSelectNote: (noteId: string) => void;
}

export const TasksManager: React.FC<TasksManagerProps> = ({
  tasks,
  notes,
  onToggleTask,
  onAddTask,
  onDeleteTask,
  onExtractTasksFromAllNotes,
  onSelectNote,
}) => {
  const [filter, setFilter] = useState<'pending' | 'all' | 'completed' | 'urgent'>('pending');
  const [quickInput, setQuickInput] = useState('');
  const [priority, setPriority] = useState<Priority>('medium');
  const [dueDate, setDueDate] = useState('');

  const handleCreateTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!quickInput.trim()) return;

    let text = quickInput.trim();
    let detectedPriority = priority;

    // Detect inline priority flags
    if (text.includes('!urgent')) {
      detectedPriority = 'urgent';
      text = text.replace('!urgent', '').trim();
    } else if (text.includes('!high')) {
      detectedPriority = 'high';
      text = text.replace('!high', '').trim();
    } else if (text.includes('!low')) {
      detectedPriority = 'low';
      text = text.replace('!low', '').trim();
    }

    // Detect inline hashtags
    const extractedTags = (text.match(/#[a-zA-Z0-9_-]+/g) || []).map((t) => t.substring(1));
    const cleanTitle = text.replace(/#[a-zA-Z0-9_-]+/g, '').trim();

    onAddTask({
      id: 'task_' + Math.random().toString(36).substring(2, 9),
      title: cleanTitle || text,
      completed: false,
      priority: detectedPriority,
      dueDate: dueDate || undefined,
      tags: extractedTags,
      createdAt: Date.now(),
    });

    setQuickInput('');
    setDueDate('');
  };

  const filteredTasks = tasks.filter((t) => {
    if (filter === 'pending') return !t.completed;
    if (filter === 'completed') return t.completed;
    if (filter === 'urgent') return !t.completed && (t.priority === 'urgent' || t.priority === 'high');
    return true;
  });

  const getPriorityBadge = (p: Priority) => {
    switch (p) {
      case 'urgent':
        return <span className="text-[10px] uppercase font-bold text-rose-400 bg-rose-950/60 border border-rose-800/60 px-1.5 py-0.5 rounded">Urgent</span>;
      case 'high':
        return <span className="text-[10px] uppercase font-semibold text-amber-400 bg-amber-950/60 border border-amber-800/60 px-1.5 py-0.5 rounded">High</span>;
      case 'medium':
        return <span className="text-[10px] uppercase font-medium text-sky-400 bg-sky-950/60 border border-sky-800/60 px-1.5 py-0.5 rounded">Medium</span>;
      case 'low':
        return <span className="text-[10px] uppercase text-stone-400 bg-stone-900 border border-stone-800 px-1.5 py-0.5 rounded">Low</span>;
    }
  };

  const completedCount = tasks.filter((t) => t.completed).length;
  const pendingCount = tasks.filter((t) => !t.completed).length;

  return (
    <div className="flex-1 bg-stone-950 flex flex-col h-full overflow-hidden select-none">
      {/* Top Banner & Automated Scanner Bar */}
      <div className="h-14 border-b border-stone-800/80 px-6 flex items-center justify-between bg-stone-900/40">
        <div className="flex items-center space-x-3">
          <CheckCircle2 className="w-5 h-5 text-amber-400" />
          <div>
            <h2 className="text-sm font-semibold text-stone-200">Action Items & Daily Focus</h2>
            <p className="text-[11px] text-stone-500 font-mono">
              {pendingCount} active • {completedCount} completed
            </p>
          </div>
        </div>

        {/* Local Automation Scanner */}
        <button
          onClick={onExtractTasksFromAllNotes}
          className="flex items-center space-x-1.5 bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 px-3 py-1.5 rounded-lg text-xs font-medium transition-all shadow-sm"
          title="Run local offline parser to extract checklists from all encrypted notes"
        >
          <Sparkles className="w-3.5 h-3.5 text-amber-400" />
          <span>Extract from All Notes</span>
        </button>
      </div>

      {/* Main Task Creator & Filters */}
      <div className="p-6 max-w-4xl w-full mx-auto flex-1 flex flex-col overflow-hidden">
        {/* Quick Add Bar */}
        <form onSubmit={handleCreateTask} className="bg-stone-900/90 border border-stone-800 rounded-xl p-3 shadow-lg mb-6">
          <div className="flex items-center gap-2 mb-2">
            <input
              type="text"
              placeholder="Add a new task (e.g. 'Deploy sovereign key audit !urgent #security')..."
              value={quickInput}
              onChange={(e) => setQuickInput(e.target.value)}
              className="flex-1 bg-transparent text-xs text-stone-100 placeholder-stone-500 focus:outline-none"
            />
            <button
              type="submit"
              disabled={!quickInput.trim()}
              className="bg-amber-500 disabled:opacity-40 hover:bg-amber-400 text-stone-950 px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1 transition-all"
            >
              <Plus className="w-3.5 h-3.5 stroke-[2.5]" />
              <span>Add</span>
            </button>
          </div>

          <div className="flex flex-wrap items-center justify-between text-xs text-stone-400 pt-2 border-t border-stone-800/60">
            <div className="flex items-center gap-2">
              <span className="text-[11px] text-stone-500">Priority:</span>
              {(['low', 'medium', 'high', 'urgent'] as Priority[]).map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setPriority(p)}
                  className={`text-[10px] uppercase font-semibold px-2 py-0.5 rounded transition-all ${
                    priority === p
                      ? 'bg-stone-700 text-stone-100 border border-stone-600'
                      : 'text-stone-500 hover:text-stone-300'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>

            <div className="flex items-center gap-2 mt-1 sm:mt-0">
              <span className="text-[11px] text-stone-500">Due:</span>
              <input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="bg-stone-950 border border-stone-800 text-[11px] text-stone-300 rounded px-2 py-0.5 focus:outline-none"
              />
            </div>
          </div>
        </form>

        {/* Filter Navigation Tabs */}
        <div className="flex items-center space-x-2 mb-4 text-xs">
          <button
            onClick={() => setFilter('pending')}
            className={`px-3 py-1 rounded-lg transition-colors font-medium ${
              filter === 'pending'
                ? 'bg-stone-800 text-amber-300 border border-stone-700'
                : 'text-stone-400 hover:text-stone-200'
            }`}
          >
            Pending ({pendingCount})
          </button>
          <button
            onClick={() => setFilter('urgent')}
            className={`px-3 py-1 rounded-lg transition-colors font-medium ${
              filter === 'urgent'
                ? 'bg-stone-800 text-amber-300 border border-stone-700'
                : 'text-stone-400 hover:text-stone-200'
            }`}
          >
            Urgent / High
          </button>
          <button
            onClick={() => setFilter('completed')}
            className={`px-3 py-1 rounded-lg transition-colors font-medium ${
              filter === 'completed'
                ? 'bg-stone-800 text-amber-300 border border-stone-700'
                : 'text-stone-400 hover:text-stone-200'
            }`}
          >
            Completed ({completedCount})
          </button>
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1 rounded-lg transition-colors font-medium ${
              filter === 'all'
                ? 'bg-stone-800 text-amber-300 border border-stone-700'
                : 'text-stone-400 hover:text-stone-200'
            }`}
          >
            All ({tasks.length})
          </button>
        </div>

        {/* Task Item List */}
        <div className="flex-1 overflow-y-auto space-y-2 pr-1">
          {filteredTasks.length === 0 ? (
            <div className="text-center py-12 text-stone-600 space-y-2">
              <CheckSquare className="w-10 h-10 mx-auto text-stone-700" />
              <p className="text-xs text-stone-400 font-medium">No tasks in this view</p>
              <p className="text-[11px]">All clear. Use the quick add input above or extract from notes.</p>
            </div>
          ) : (
            filteredTasks.map((task) => {
              const sourceNote = notes.find((n) => n.id === task.noteReferenceId);

              return (
                <div
                  key={task.id}
                  className={`group flex items-start justify-between p-3 rounded-lg border transition-all ${
                    task.completed
                      ? 'bg-stone-900/30 border-stone-900 text-stone-500'
                      : 'bg-stone-900/70 border-stone-800/80 text-stone-200 hover:border-stone-700'
                  }`}
                >
                  <div className="flex items-start space-x-3 flex-1 min-w-0">
                    <button
                      onClick={() => onToggleTask(task.id)}
                      className="mt-0.5 text-stone-400 hover:text-amber-400 transition-colors shrink-0"
                    >
                      {task.completed ? (
                        <CheckSquare className="w-4 h-4 text-emerald-400" />
                      ) : (
                        <Square className="w-4 h-4" />
                      )}
                    </button>

                    <div className="flex-1 min-w-0">
                      <p className={`text-xs font-medium leading-normal ${task.completed ? 'line-through text-stone-500' : 'text-stone-200'}`}>
                        {task.title}
                      </p>

                      {/* Badges & Tags */}
                      <div className="flex flex-wrap items-center gap-1.5 mt-1.5">
                        {getPriorityBadge(task.priority)}

                        {task.dueDate && (
                          <span className="inline-flex items-center gap-1 text-[10px] font-mono text-stone-400 bg-stone-950 px-1.5 py-0.5 rounded border border-stone-800">
                            <Calendar className="w-3 h-3 text-stone-500" />
                            {task.dueDate}
                          </span>
                        )}

                        {sourceNote && (
                          <button
                            onClick={() => onSelectNote(sourceNote.id)}
                            className="inline-flex items-center gap-1 text-[10px] text-stone-400 hover:text-amber-400 bg-stone-950 px-1.5 py-0.5 rounded border border-stone-800 transition-colors"
                            title="Go to source note"
                          >
                            <span>From: {sourceNote.title}</span>
                            <ArrowUpRight className="w-3 h-3" />
                          </button>
                        )}

                        {task.tags.map((t) => (
                          <span key={t} className="text-[10px] font-mono text-stone-400 bg-stone-800/70 px-1.5 py-0.5 rounded">
                            #{t}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="opacity-0 group-hover:opacity-100 flex items-center space-x-1 pl-2 transition-opacity">
                    <button
                      onClick={() => onDeleteTask(task.id)}
                      className="p-1 hover:text-rose-400 text-stone-500 rounded transition-colors"
                      title="Delete task"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
};
