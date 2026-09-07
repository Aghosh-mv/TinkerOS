CREATE TABLE `device_codes` (
	`hash` text PRIMARY KEY NOT NULL,
	`code` text NOT NULL,
	`user_id` text,
	`email` text,
	`name` text,
	`expires` integer NOT NULL,
	`consumed` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `device_codes_code_unique` ON `device_codes` (`code`);--> statement-breakpoint
CREATE TABLE `sessions` (
	`hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`email` text NOT NULL,
	`name` text NOT NULL,
	`expires` integer NOT NULL
);
