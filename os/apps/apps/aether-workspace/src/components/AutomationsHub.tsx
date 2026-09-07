import React, { useState } from 'react';
import { 
  Workflow, 
  Play, 
  Plus, 
  Terminal, 
  CheckCircle2, 
  Clock, 
  Sliders, 
  Cpu, 
  FileText, 
  Sparkles,
  ToggleLeft,
  ToggleRight,
  RefreshCw,
  Trash2,
  Layers
} from 'lucide-react';
import { AutomationRule, Note, ActionType, TriggerType } from '../types';

interface AutomationsHubProps {
  automations: AutomationRule[];
  notes: Note[];
  selectedNote: Note | null;
  onToggleRule: (ruleId: string) => void;
  onRunRuleOnNote: (ruleId: string, note: Note) => void;
  onRunRuleOnAllNotes: (ruleId: string) => void;
  onAddRule: (rule: AutomationRule) => void;
  onDeleteRule: (ruleId: string) => void;
  executionLogs: string[];
  onClearLogs: () => void;
}

export const AutomationsHub: React.FC<AutomationsHubProps> = ({
  automations,
  notes,
  selectedNote,
  onToggleRule,
  onRunRuleOnNote,
  onRunRuleOnAllNotes,
  onAddRule,
  onDeleteRule,
  executionLogs,
  onClearLogs,
}) => {
  const [isCreatingRule, setIsCreatingRule] = useState(false);
  const [newRuleName, setNewRuleName] = useState('');
  const [newRuleDesc, setNewRuleDesc] = useState('');
  const [newRuleTrigger, setNewRuleTrigger] = useState<TriggerType>('on_save');
  const [newRuleAction, setNewRuleAction] = useState<ActionType>('format_markdown');

  const handleCreateRule = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRuleName.trim()) return;

    const newRule: AutomationRule = {
      id: 'rule_' + Math.random().toString(36).substring(2, 9),
      name: newRuleName.trim(),
      description: newRuleDesc.trim() || 'Custom user local automation rule.',
      trigger: newRuleTrigger,
      action: newRuleAction,
      enabled: true,
      runCount: 0,
    };

    onAddRule(newRule);
    setNewRuleName('');
    setNewRuleDesc('');
    setIsCreatingRule(false);
  };

  return (
    <div className="flex-1 bg-stone-950 flex flex-col h-full overflow-hidden select-none">
      {/* Top Banner */}
      <div className="h-14 border-b border-stone-800/80 px-6 flex items-center justify-between bg-stone-900/40">
        <div className="flex items-center space-x-3">
          <Workflow className="w-5 h-5 text-sky-400" />
          <div>
            <h2 className="text-sm font-semibold text-stone-200">Local Automator Engine</h2>
            <p className="text-[11px] text-stone-500 font-mono">
              Deterministic, zero-latency workflows running purely on-device (Zero AI • Zero Network)
            </p>
          </div>
        </div>

        <button
          onClick={() => setIsCreatingRule(true)}
          className="flex items-center space-x-1.5 bg-sky-500 hover:bg-sky-400 text-stone-950 font-semibold px-3 py-1.5 rounded-lg text-xs transition-all shadow-sm"
        >
          <Plus className="w-3.5 h-3.5 stroke-[2.5]" />
          <span>New Pipeline</span>
        </button>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-y-auto p-6 max-w-5xl w-full mx-auto space-y-6">
        {/* Create Rule Modal / Drawer Form */}
        {isCreatingRule && (
          <div className="bg-stone-900 border border-stone-800 rounded-xl p-5 shadow-xl space-y-4">
            <div className="flex items-center justify-between border-b border-stone-800 pb-3">
              <h3 className="text-xs font-semibold text-stone-200 flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-amber-400" />
                Configure Local Automation Rule
              </h3>
              <button
                onClick={() => setIsCreatingRule(false)}
                className="text-stone-500 hover:text-stone-300 text-xs"
              >
                Cancel
              </button>
            </div>

            <form onSubmit={handleCreateRule} className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
              <div>
                <label className="block text-stone-400 mb-1 font-medium">Pipeline Name</label>
                <input
                  type="text"
                  placeholder="e.g. Sanitize & Normalize Spacing"
                  value={newRuleName}
                  onChange={(e) => setNewRuleName(e.target.value)}
                  className="w-full bg-stone-950 border border-stone-800 rounded-lg p-2 text-stone-200 focus:outline-none focus:border-amber-500"
                  required
                />
              </div>

              <div>
                <label className="block text-stone-400 mb-1 font-medium">Description</label>
                <input
                  type="text"
                  placeholder="Brief description of what this rule executes..."
                  value={newRuleDesc}
                  onChange={(e) => setNewRuleDesc(e.target.value)}
                  className="w-full bg-stone-950 border border-stone-800 rounded-lg p-2 text-stone-200 focus:outline-none focus:border-amber-500"
                />
              </div>

              <div>
                <label className="block text-stone-400 mb-1 font-medium">Trigger Event</label>
                <select
                  value={newRuleTrigger}
                  onChange={(e) => setNewRuleTrigger(e.target.value as TriggerType)}
                  className="w-full bg-stone-950 border border-stone-800 rounded-lg p-2 text-stone-200 focus:outline-none"
                >
                  <option value="on_save">On Note Save / Autosave</option>
                  <option value="manual">Manual Trigger Only</option>
                  <option value="on_tag">When Specific Tag is Present</option>
                  <option value="daily_standup">Daily Routine / Roll-over</option>
                </select>
              </div>

              <div>
                <label className="block text-stone-400 mb-1 font-medium">Deterministic Action</label>
                <select
                  value={newRuleAction}
                  onChange={(e) => setNewRuleAction(e.target.value as ActionType)}
                  className="w-full bg-stone-950 border border-stone-800 rounded-lg p-2 text-stone-200 focus:outline-none"
                >
                  <option value="format_markdown">Beautify & Format Markdown</option>
                  <option value="extract_tasks">Extract Checkbox Items to Tasks</option>
                  <option value="auto_tag">Auto-Detect #Hashtags & Keywords</option>
                  <option value="append_timestamp">Append Local Cryptographic Timestamp</option>
                  <option value="calculate_metrics">Calculate Words & Reading Metrics</option>
                  <option value="sanitize_whitespace">Strip Trailing Whitespaces</option>
                </select>
              </div>

              <div className="sm:col-span-2 flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsCreatingRule(false)}
                  className="px-3 py-1.5 rounded-lg text-stone-400 hover:text-stone-200 text-xs"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="bg-amber-500 hover:bg-amber-400 text-stone-950 px-4 py-1.5 rounded-lg font-semibold text-xs transition-colors"
                >
                  Create Rule
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Rules Grid */}
        <div className="space-y-3">
          <div className="flex items-center justify-between text-xs text-stone-400 px-1">
            <span className="font-semibold uppercase tracking-wider text-[11px] text-stone-500">
              Active Automation Recipes ({automations.length})
            </span>
            <span className="font-mono text-[11px] text-stone-500">
              Hardware Engine: Instantaneous JS Runtime
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {automations.map((rule) => {
              return (
                <div
                  key={rule.id}
                  className={`p-4 rounded-xl border transition-all ${
                    rule.enabled
                      ? 'bg-stone-900/80 border-stone-800/80 text-stone-200 hover:border-stone-700'
                      : 'bg-stone-950/60 border-stone-900 text-stone-500'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3 mb-2">
                    <div className="flex items-center space-x-2">
                      <div className={`p-1.5 rounded-lg ${rule.enabled ? 'bg-sky-950/60 text-sky-400 border border-sky-800/40' : 'bg-stone-800 text-stone-600'}`}>
                        <Cpu className="w-4 h-4" />
                      </div>
                      <div>
                        <h4 className="text-xs font-semibold text-stone-200">{rule.name}</h4>
                        <span className="text-[10px] font-mono text-stone-500">
                          Trigger: {rule.trigger.replace('_', ' ')} • Action: {rule.action.replace('_', ' ')}
                        </span>
                      </div>
                    </div>

                    <button
                      onClick={() => onToggleRule(rule.id)}
                      className="text-stone-400 hover:text-stone-200 transition-colors"
                      title={rule.enabled ? "Disable rule" : "Enable rule"}
                    >
                      {rule.enabled ? (
                        <ToggleRight className="w-6 h-6 text-emerald-400" />
                      ) : (
                        <ToggleLeft className="w-6 h-6 text-stone-600" />
                      )}
                    </button>
                  </div>

                  <p className="text-[11px] text-stone-400 leading-relaxed mb-4">
                    {rule.description}
                  </p>

                  <div className="flex items-center justify-between pt-3 border-t border-stone-800/60 text-xs">
                    <span className="text-[10px] font-mono text-stone-500">
                      Executions: {rule.runCount}
                    </span>

                    <div className="flex items-center space-x-2">
                      {selectedNote && (
                        <button
                          onClick={() => onRunRuleOnNote(rule.id, selectedNote)}
                          disabled={!rule.enabled}
                          className="flex items-center space-x-1 px-2.5 py-1 rounded bg-stone-800 hover:bg-stone-750 disabled:opacity-40 text-stone-300 text-[11px] transition-colors"
                          title="Run on currently active note"
                        >
                          <Play className="w-3 h-3 text-amber-400" />
                          <span>Run on Active</span>
                        </button>
                      )}

                      <button
                        onClick={() => onRunRuleOnAllNotes(rule.id)}
                        disabled={!rule.enabled}
                        className="flex items-center space-x-1 px-2.5 py-1 rounded bg-stone-800 hover:bg-stone-750 disabled:opacity-40 text-stone-300 text-[11px] transition-colors"
                        title="Run on entire vault"
                      >
                        <Layers className="w-3 h-3 text-sky-400" />
                        <span>Run on Vault</span>
                      </button>

                      <button
                        onClick={() => onDeleteRule(rule.id)}
                        className="p-1 text-stone-600 hover:text-rose-400 transition-colors"
                        title="Delete rule"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Live Execution Console & Audit Stream */}
        <div className="bg-stone-900/90 border border-stone-800 rounded-xl overflow-hidden shadow-lg">
          <div className="h-9 bg-stone-900 border-b border-stone-800 px-4 flex items-center justify-between text-xs">
            <div className="flex items-center space-x-2 text-stone-400">
              <Terminal className="w-3.5 h-3.5 text-emerald-400" />
              <span className="font-mono font-medium">Local Automation Event Console</span>
            </div>

            <div className="flex items-center space-x-3 text-[11px] font-mono text-stone-500">
              <span className="text-emerald-400">0 Network Calls</span>
              <button
                onClick={onClearLogs}
                className="hover:text-stone-300 transition-colors"
              >
                Clear
              </button>
            </div>
          </div>

          <div className="p-4 bg-stone-950 font-mono text-[11px] text-stone-300 h-44 overflow-y-auto space-y-1.5">
            {executionLogs.length === 0 ? (
              <p className="text-stone-600 italic">No automations executed in this session yet. Ready for triggers.</p>
            ) : (
              executionLogs.map((log, index) => (
                <div key={index} className="flex items-start space-x-2 leading-relaxed">
                  <span className="text-stone-600 select-none">[{index + 1}]</span>
                  <span className="text-emerald-400 select-none">❯</span>
                  <span className="text-stone-300">{log}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
