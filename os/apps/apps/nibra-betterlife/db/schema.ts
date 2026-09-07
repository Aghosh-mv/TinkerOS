import {sqliteTable,text,integer} from 'drizzle-orm/sqlite-core';
export const deviceCodes=sqliteTable('device_codes',{hash:text('hash').primaryKey(),code:text('code').notNull().unique(),userId:text('user_id'),email:text('email'),name:text('name'),expires:integer('expires').notNull(),consumed:integer('consumed').notNull().default(0)});
export const sessions=sqliteTable('sessions',{hash:text('hash').primaryKey(),userId:text('user_id').notNull(),email:text('email').notNull(),name:text('name').notNull(),expires:integer('expires').notNull()});
