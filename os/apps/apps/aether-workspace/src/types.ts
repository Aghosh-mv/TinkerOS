export type Priority = 'low' | 'medium' | 'high' | 'urgent';

export interface Note {
  id: string;
  title: string;
  content: string;
  plainTextPreview?: string;
  folder: string;
  tags: string[];
  isPinned: boolean;
  isEncrypted: boolean;
  // Cryptographic metadata for E2EE
  encryptionMeta?: {
    iv: string;
    salt: string;
    ciphertext: string;
    algorithm: string;
    checksum: string;
  };
  createdAt: number;
  updatedAt: number;
}

export interface TaskItem {
  id: string;
  title: string;
  completed: boolean;
  priority: Priority;
  dueDate?: string;
  tags: string[];
  noteReferenceId?: string;
  createdAt: number;
  completedAt?: number;
}

export interface JournalEntry {
  id: string;
  date: string; // YYYY-MM-DD
  time: string; // HH:mm
  content: string;
  category: 'Reflection' | 'Idea' | 'Standup' | 'Log';
  mood?: 'Focused' | 'Energetic' | 'Calm' | 'Productive';
  createdAt: number;
}

export type TriggerType = 'on_save' | 'on_tag' | 'manual' | 'daily_standup' | 'on_task_create';

export type ActionType = 
  | 'extract_tasks' 
  | 'auto_tag' 
  | 'format_markdown' 
  | 'append_timestamp' 
  | 'calculate_metrics' 
  | 'sanitize_whitespace' 
  | 'archive_completed';

export interface AutomationRule {
  id: string;
  name: string;
  description: string;
  trigger: TriggerType;
  action: ActionType;
  enabled: boolean;
  lastRun?: number;
  runCount: number;
  config?: Record<string, any>;
}

export interface VaultMetadata {
  vaultName: string;
  isLocked: boolean;
  masterPasswordHash?: string;
  saltHex?: string;
  autoLockMinutes: number;
  lastActive: number;
  totalNotesEncrypted: number;
  createdAt: number;
}

export interface SyncPayload {
  version: string;
  timestamp: number;
  vaultName: string;
  checksum: string;
  payloadEncrypted: string;
  iv: string;
  salt: string;
}

export type WorkspaceTab = 'notes' | 'tasks' | 'journal' | 'automations' | 'vault_security';
