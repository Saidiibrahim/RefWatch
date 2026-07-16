CREATE TABLE "runtime_database_markers" (
	"marker" text PRIMARY KEY NOT NULL,
	"branch_id" text NOT NULL,
	"environment" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
