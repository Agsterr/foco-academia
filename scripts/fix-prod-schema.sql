ALTER TABLE exercises ADD COLUMN IF NOT EXISTS media_type VARCHAR(16);
UPDATE exercises SET media_type = 'NONE' WHERE media_type IS NULL;
ALTER TABLE exercises ALTER COLUMN media_type SET DEFAULT 'NONE';
ALTER TABLE exercises ALTER COLUMN media_type SET NOT NULL;

ALTER TABLE academies ADD COLUMN IF NOT EXISTS app_blocked boolean;
UPDATE academies SET app_blocked = false WHERE app_blocked IS NULL;
ALTER TABLE academies ALTER COLUMN app_blocked SET DEFAULT false;
ALTER TABLE academies ALTER COLUMN app_blocked SET NOT NULL;

ALTER TABLE device_sessions ADD COLUMN IF NOT EXISTS app_client VARCHAR(255);
UPDATE device_sessions SET app_client = 'WEB' WHERE app_client IS NULL;
ALTER TABLE device_sessions ALTER COLUMN app_client SET DEFAULT 'WEB';
ALTER TABLE device_sessions ALTER COLUMN app_client SET NOT NULL;

ALTER TABLE device_sessions ADD COLUMN IF NOT EXISTS app_version VARCHAR(255);
