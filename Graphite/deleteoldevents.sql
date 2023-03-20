DELETE FROM tagging_taggeditem WHERE object_id IN (SELECT id FROM events_event WHERE "when" < datetime('now','-7 day'));
DELETE FROM events_event WHERE "when" < datetime('now','-7 day');
