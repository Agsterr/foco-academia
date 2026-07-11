SELECT u.email, ds.device_id, ds.device_label, ds.last_seen_at
FROM device_sessions ds
JOIN users u ON u.id = ds.user_id
WHERE u.email = 'instrutor@academia.com';

DELETE FROM device_sessions
WHERE user_id = (SELECT id FROM users WHERE email = 'instrutor@academia.com');
