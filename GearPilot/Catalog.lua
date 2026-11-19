local _, GP = ...
-- The offline importer will populate rows here. No account, key or provider
-- addon is needed by the game client.
-- Row fields: itemID, source (Quests/Dungeons), sourceID, level, name,
-- faction (optional), prerequisites (confirmed quest IDs), provenance (optional).
GP.catalog = {
    rows = {},
}
