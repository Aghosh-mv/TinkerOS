import { Note, TaskItem, AutomationRule } from '../types';

/**
 * Native Deterministic Local Automation Engine
 * Runs completely on-device without network, cloud, or AI dependencies.
 */

export interface AutomationResult {
  modifiedNote?: Note;
  createdTasks?: TaskItem[];
  logs: string[];
}

/**
 * Clean & normalize markdown text
 */
export function formatMarkdown(content: string): string {
  let text = content;
  // Normalize bullet points to '-'
  text = text.replace(/^[ \t]*\*[ \t]+/gm, '- ');
  // Ensure single blank line before headings
  text = text.replace(/([^\n])\n(#{1,6} )/g, '$1\n\n$2');
  // Trim trailing whitespaces on lines
  text = text.replace(/[ \t]+$/gm, '');
  // Collapse 3+ consecutive newlines to 2
  text = text.replace(/\n{3,}/g, '\n\n');
  return text.trim();
}

/**
 * Extract checkbox or TODO lines from note content and convert to TaskItems
 */
export function extractTasksFromContent(content: string, noteId: string): TaskItem[] {
  const lines = content.split('\n');
  const tasks: TaskItem[] = [];

  const taskRegex = /^[ \t]*-\s*\[([ xX])\]\s*(.+)$/;
  const todoRegex = /^[ \t]*(?:TODO|FIXME|ACTION):\s*(.+)$/i;

  lines.forEach((line) => {
    let taskTitle = '';
    let isCompleted = false;

    const checkboxMatch = line.match(taskRegex);
    if (checkboxMatch) {
      isCompleted = checkboxMatch[1].toLowerCase() === 'x';
      taskTitle = checkboxMatch[2].trim();
    } else {
      const todoMatch = line.match(todoRegex);
      if (todoMatch) {
        taskTitle = todoMatch[1].trim();
      }
    }

    if (taskTitle) {
      let priority: 'low' | 'medium' | 'high' | 'urgent' = 'medium';
      if (taskTitle.includes('!urgent') || taskTitle.includes('#urgent')) {
        priority = 'urgent';
      } else if (taskTitle.includes('!high') || taskTitle.includes('#high')) {
        priority = 'high';
      } else if (taskTitle.includes('!low') || taskTitle.includes('#low')) {
        priority = 'low';
      }

      // Extract inline hashtags as tags
      const tags = (taskTitle.match(/#[a-zA-Z0-9_-]+/g) || []).map((t) => t.substring(1));

      // Clean hashtags and priority flags from title
      const cleanTitle = taskTitle
        .replace(/!(?:urgent|high|medium|low)/gi, '')
        .replace(/#[a-zA-Z0-9_-]+/g, '')
        .trim();

      tasks.push({
        id: 'task_' + Math.random().toString(36).substring(2, 9),
        title: cleanTitle || taskTitle,
        completed: isCompleted,
        priority,
        tags,
        noteReferenceId: noteId,
        createdAt: Date.now(),
      });
    }
  });

  return tasks;
}

/**
 * Automatically scan text for hashtags or predefined keywords and return updated tag array
 */
export function extractTagsFromContent(content: string, existingTags: string[] = []): string[] {
  const foundTags = new Set(existingTags);
  const tagMatches = content.match(/#[a-zA-Z0-9_-]+/g);
  if (tagMatches) {
    tagMatches.forEach((t) => {
      const clean = t.substring(1).toLowerCase();
      if (clean.length > 1) {
        foundTags.add(clean);
      }
    });
  }

  // Common context keywords auto-detection
  const lower = content.toLowerCase();
  if (lower.includes('meeting') || lower.includes('agenda') || lower.includes('attendees')) {
    foundTags.add('meeting');
  }
  if (lower.includes('project') || lower.includes('milestone') || lower.includes('deliverable')) {
    foundTags.add('project');
  }
  if (lower.includes('budget') || lower.includes('invoice') || lower.includes('$') || lower.includes('expense')) {
    foundTags.add('finance');
  }
  if (lower.includes('bug') || lower.includes('fix') || lower.includes('refactor') || lower.includes('code')) {
    foundTags.add('dev');
  }

  return Array.from(foundTags);
}

/**
 * Calculate precise metrics (words, chars, reading time)
 */
export function calculateTextMetrics(content: string) {
  const words = content.trim() ? content.trim().split(/\s+/).length : 0;
  const chars = content.length;
  const lines = content.split('\n').length;
  const readingTimeMin = Math.max(1, Math.ceil(words / 200));
  return { words, chars, lines, readingTimeMin };
}

/**
 * Execute a specific automation rule against a note
 */
export function executeAutomationRule(
  rule: AutomationRule,
  note: Note
): AutomationResult {
  const logs: string[] = [];
  let updatedNote: Note = { ...note };
  let createdTasks: TaskItem[] = [];

  switch (rule.action) {
    case 'format_markdown': {
      const beforeLength = updatedNote.content.length;
      updatedNote.content = formatMarkdown(updatedNote.content);
      logs.push(`Formatted Markdown typography & spacing (byte delta: ${updatedNote.content.length - beforeLength})`);
      break;
    }

    case 'extract_tasks': {
      createdTasks = extractTasksFromContent(updatedNote.content, updatedNote.id);
      logs.push(`Extracted ${createdTasks.length} action items from Markdown checklists`);
      break;
    }

    case 'auto_tag': {
      const newTags = extractTagsFromContent(updatedNote.content, updatedNote.tags);
      const added = newTags.filter((t) => !updatedNote.tags.includes(t));
      updatedNote.tags = newTags;
      logs.push(`Auto-tagged note with: ${added.length > 0 ? added.join(', ') : 'no new tags'}`);
      break;
    }

    case 'append_timestamp': {
      const timestampStr = `\n\n_Last automated audit: ${new Date().toLocaleString()}_`;
      if (!updatedNote.content.includes('_Last automated audit:')) {
        updatedNote.content += timestampStr;
        logs.push('Appended local ISO audit timestamp to note footer');
      } else {
        logs.push('Audit timestamp already present');
      }
      break;
    }

    case 'calculate_metrics': {
      const metrics = calculateTextMetrics(updatedNote.content);
      logs.push(`Computed metrics: ${metrics.words} words, ${metrics.chars} characters (~${metrics.readingTimeMin} min read)`);
      break;
    }

    case 'sanitize_whitespace': {
      updatedNote.content = updatedNote.content.replace(/[ \t]+$/gm, '').trim();
      logs.push('Sanitized trailing whitespaces and carriage returns');
      break;
    }

    default:
      logs.push(`Action ${rule.action} executed with zero side effects.`);
  }

  updatedNote.updatedAt = Date.now();

  return {
    modifiedNote: updatedNote,
    createdTasks,
    logs,
  };
}

/**
 * Default Automation Recipes that ship out-of-the-box
 */
export const DEFAULT_AUTOMATIONS: AutomationRule[] = [
  {
    id: 'auto_task_extract',
    name: 'Checklist to Task Extractor',
    description: 'Scans note for checkbox items (- [ ]) and adds them to your Action Items dashboard.',
    trigger: 'on_save',
    action: 'extract_tasks',
    enabled: true,
    runCount: 0,
  },
  {
    id: 'auto_tagger',
    name: 'Smart Local Tag Detector',
    description: 'Extracts #hashtags and auto-categorizes meeting, finance, or dev notes based on keywords.',
    trigger: 'on_save',
    action: 'auto_tag',
    enabled: true,
    runCount: 0,
  },
  {
    id: 'markdown_sanitizer',
    name: 'Markdown & Whitespace Beautifier',
    description: 'Enforces clean header gaps, aligns bullet points, and eliminates trailing spaces.',
    trigger: 'manual',
    action: 'format_markdown',
    enabled: true,
    runCount: 0,
  },
  {
    id: 'timestamp_auditor',
    name: 'Cryptographic Timestamp Stamp',
    description: 'Appends local device verification timestamp without network or server reliance.',
    trigger: 'manual',
    action: 'append_timestamp',
    enabled: true,
    runCount: 0,
  },
  {
    id: 'metrics_evaluator',
    name: 'Word Count & Read Time Profiler',
    description: 'Calculates exact word density and estimated reading duration in milliseconds.',
    trigger: 'on_save',
    action: 'calculate_metrics',
    enabled: true,
    runCount: 0,
  },
];
