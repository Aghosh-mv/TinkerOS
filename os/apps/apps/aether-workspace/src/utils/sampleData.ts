import { Note, TaskItem, JournalEntry, VaultMetadata } from '../types';

export const INITIAL_VAULT_META: VaultMetadata = {
  vaultName: 'Aether Sovereign Vault',
  isLocked: false,
  autoLockMinutes: 15,
  lastActive: Date.now(),
  totalNotesEncrypted: 0,
  createdAt: Date.now(),
};

export const INITIAL_NOTES: Note[] = [];

export const INITIAL_TASKS: TaskItem[] = [];

export const INITIAL_JOURNAL: JournalEntry[] = [];

