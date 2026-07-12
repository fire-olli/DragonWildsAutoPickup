-- Dragonwilds Auto Pickup v0.8 - optimized wood and stone auto scan
-- F7: dump matching UObject instances/classes
-- F8: toggle lightweight auto pickup
-- F9: one detailed manual pickup scan

local enabled = false
local scan_interval_ms = 3000
local pickup_radius_cm = 900.0
local max_dump_logs = 1800
local max_manual_candidates_per_scan = 350
local max_auto_candidates_per_scan = 120

local table_unpack = table.unpack or unpack
local discovery_terms = { "item", "pickup", "loot", "resource", "drop", "world", "tree", "log", "wood", "stone", "rock", "ore", "mineral" }
local resource_terms = { "tree", "log", "wood", "branch", "timber", "ashbranch", "stone", "rock", "ore", "mineral", "clay", "copper", "tin", "iron", "coal", "flint", "granite", "sandstone", "limestone", "pebble" }

local manual_world_item_classes = {
    "RuntimeSpawnedWorldItem",
    "WorldItem",
}

local manual_placed_resource_classes = {
    "TreeLog",
    "SplittableTreeLog",
    "FelledTree",
    "BaseInteractableResource",
    "GatherableResource",
    "HarvestableResource",
    "SalvageableResource",
}

-- Auto mode is intentionally narrow to prevent hitching. F9 still runs the broader diagnostic scan.
local auto_world_item_classes = {
    "RuntimeSpawnedWorldItem",
}

local auto_placed_resource_classes = {
    "GatherableResource",
}

local function log(msg)
    print("[DragonwildsAutoPickup] " .. tostring(msg) .. "\n")
end

local function safe_call(label, fn, noisy)
    local ok, result = pcall(fn)
    if not ok then
        if noisy then log(label .. " failed: " .. tostring(result)) end
        return false, nil
    end
    return true, result
end

local function is_valid(obj)
    if obj == nil then return false end
    local ok, result = pcall(function() return obj:IsValid() end)
    return ok and result
end

local function safe_full_name(obj)
    if obj == nil then return "<nil>" end
    local ok, name = pcall(function() return obj:GetFullName() end)
    if ok and name ~= nil then return tostring(name) end
    return tostring(obj)
end

local function safe_name(obj)
    if obj == nil then return "<nil>" end
    local ok, name = pcall(function() return obj:GetName() end)
    if ok and name ~= nil then return tostring(name) end
    local full_name = safe_full_name(obj)
    return string.match(full_name, "([^%s%.:]+)$") or full_name
end

local function safe_class_name(obj)
    if obj == nil then return "<nil>" end
    local ok_class, class_obj = pcall(function() return obj:GetClass() end)
    if ok_class and class_obj ~= nil then
        local ok_name, class_name = pcall(function() return class_obj:GetName() end)
        if ok_name and class_name ~= nil then return tostring(class_name) end
        local ok_full, class_full = pcall(function() return class_obj:GetFullName() end)
        if ok_full and class_full ~= nil then return tostring(class_full) end
    end
    return "<class unavailable>"
end

local function contains_any(text, terms)
    if text == nil then return false end
    local lower = string.lower(tostring(text))
    for _, term in ipairs(terms) do
        if string.find(lower, term, 1, true) ~= nil then return true end
    end
    return false
end

local function has_target_resource_name(obj)
    return contains_any(safe_name(obj), resource_terms) or contains_any(safe_class_name(obj), resource_terms) or contains_any(safe_full_name(obj), resource_terms)
end

local function vec_x(v) return v and (v.X or v.x or 0.0) or 0.0 end
local function vec_y(v) return v and (v.Y or v.y or 0.0) or 0.0 end
local function vec_z(v) return v and (v.Z or v.z or 0.0) or 0.0 end

local function vec_is_zero(v)
    return math.abs(vec_x(v)) < 0.01 and math.abs(vec_y(v)) < 0.01 and math.abs(vec_z(v)) < 0.01
end

local function distance(a, b)
    local dx = vec_x(a) - vec_x(b)
    local dy = vec_y(a) - vec_y(b)
    local dz = vec_z(a) - vec_z(b)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function vec_text(v)
    if v == nil then return "<nil>" end
    return string.format("X=%.1f Y=%.1f Z=%.1f", vec_x(v), vec_y(v), vec_z(v))
end

local function call_method(obj, method_name, ...)
    if obj == nil then return false, nil end
    local args = { ... }
    return safe_call(method_name, function()
        return obj[method_name](obj, table_unpack(args))
    end, false)
end

local function get_property(obj, property_name)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj[property_name] end)
    if ok then return value end
    return nil
end

local function get_component_location(component)
    if component == nil then return nil end
    local ok, loc = call_method(component, "K2_GetComponentLocation")
    if ok and loc ~= nil and not vec_is_zero(loc) then return loc end
    return nil
end

local function get_actor_location(actor)
    local ok, loc = call_method(actor, "K2_GetActorLocation")
    if ok and loc ~= nil and not vec_is_zero(loc) then return loc end

    local ok_static, static_mesh = call_method(actor, "GetStaticMeshComponent")
    loc = get_component_location(static_mesh)
    if loc ~= nil then return loc end

    loc = get_component_location(get_property(actor, "StaticMeshComponent"))
    if loc ~= nil then return loc end

    loc = get_component_location(get_property(actor, "RootStaticMeshComponent"))
    if loc ~= nil then return loc end

    loc = get_component_location(get_property(actor, "BoxColliderComponent"))
    if loc ~= nil then return loc end

    loc = get_component_location(get_property(actor, "Root"))
    if loc ~= nil then return loc end

    local ok_root, root = call_method(actor, "K2_GetRootComponent")
    loc = get_component_location(root)
    if ok_root and loc ~= nil then return loc end

    if ok then return loc end
    return nil
end

local function safe_find_all(class_name)
    local ok, objects = safe_call("FindAllOf " .. class_name, function()
        return FindAllOf(class_name)
    end, false)
    if not ok or objects == nil then return {} end
    return objects
end

local function get_player()
    local players = safe_find_all("DominionPlayerCharacter")
    for _, player in ipairs(players) do
        if player ~= nil then return player end
    end
    return nil
end

local function get_interaction_manager(player)
    local ok, manager = call_method(player, "GetInteractionManager")
    if ok and manager ~= nil then return manager end
    return nil
end

local function get_interaction_component(actor)
    local ok, component = call_method(actor, "GetInteractionComponent")
    if ok and component ~= nil then return component end
    local direct = get_property(actor, "InteractionComponent")
    if direct ~= nil then return direct end
    return nil
end

local function get_interaction_collision(actor)
    local ok, collision = call_method(actor, "GetInteractionCollision")
    if ok and collision ~= nil then return collision end
    local box = get_property(actor, "BoxColliderComponent")
    if box ~= nil then return box end
    local static_mesh = get_property(actor, "StaticMeshComponent")
    if static_mesh ~= nil then return static_mesh end
    local root_mesh = get_property(actor, "RootStaticMeshComponent")
    if root_mesh ~= nil then return root_mesh end
    return nil
end

local function collect_by_classes(class_names, noisy)
    local result = {}
    local seen = {}
    for _, class_name in ipairs(class_names) do
        local objects = safe_find_all(class_name)
        if noisy then log("FindAllOf(" .. class_name .. ")=" .. tostring(#objects)) end
        for _, obj in ipairs(objects) do
            local key = safe_full_name(obj)
            if obj ~= nil and not seen[key] then
                seen[key] = true
                table.insert(result, obj)
            end
        end
    end
    return result
end

local function try_magnetize_world_item(item, player, player_loc, noisy)
    local item_loc = get_actor_location(item)
    if item_loc == nil then
        if noisy then log("WorldItem location unavailable: " .. safe_full_name(item)) end
        return false
    end

    local dist = distance(player_loc, item_loc)
    if dist > pickup_radius_cm then return false end

    if noisy then
        log("WorldItem nearby dist=" .. string.format("%.1f", dist) .. " class=" .. safe_class_name(item))
        log("  full=" .. safe_full_name(item))
        log("  loc=" .. vec_text(item_loc))
    end

    local ok_mag, magnet = call_method(item, "GetMagneticComponent")
    if noisy then log("  GetMagneticComponent ok=" .. tostring(ok_mag) .. " nil=" .. tostring(magnet == nil) .. " valid=" .. tostring(is_valid(magnet))) end
    if ok_mag and magnet ~= nil then
        local ok_call, result = call_method(magnet, "BP_MagnetizeToPlayer", player, true)
        if noisy then log("  BP_MagnetizeToPlayer ok=" .. tostring(ok_call) .. " result=" .. tostring(result)) end
        if ok_call then return true end
    end

    local manager = get_interaction_manager(player)
    local interaction = get_interaction_component(item)
    local collision = get_interaction_collision(item)
    if noisy then
        log("  InteractionManager nil=" .. tostring(manager == nil) .. " valid=" .. tostring(is_valid(manager)))
        log("  InteractionComponent nil=" .. tostring(interaction == nil) .. " valid=" .. tostring(is_valid(interaction)))
        log("  InteractionCollision nil=" .. tostring(collision == nil) .. " valid=" .. tostring(is_valid(collision)))
    end
    if manager ~= nil and interaction ~= nil then
        local ok_req, result = call_method(manager, "Server_RequestInteraction", interaction, collision, false, false)
        if noisy then log("  Server_RequestInteraction ok=" .. tostring(ok_req) .. " result=" .. tostring(result)) end
        return ok_req
    end

    return false
end

local function try_collect_placed_resource(actor, player, player_loc, noisy)
    if not has_target_resource_name(actor) then return false end

    local loc = get_actor_location(actor)
    if loc == nil then
        if noisy then log("Placed resource location unavailable: " .. safe_full_name(actor)) end
        return false
    end

    local dist = distance(player_loc, loc)
    if dist > pickup_radius_cm then return false end

    if noisy then
        log("Placed resource nearby dist=" .. string.format("%.1f", dist) .. " class=" .. safe_class_name(actor))
        log("  name=" .. safe_name(actor))
        log("  full=" .. safe_full_name(actor))
        log("  loc=" .. vec_text(loc))
    end

    local ok_available, available = call_method(actor, "IsResourceAvailable")
    if noisy and ok_available then log("  IsResourceAvailable=" .. tostring(available)) end
    if ok_available and available == false then return false end

    local ok_drop, drop_result = call_method(actor, "DropItems", player)
    if noisy then log("  DropItems(player) ok=" .. tostring(ok_drop) .. " result=" .. tostring(drop_result)) end
    if ok_drop then return true end

    local manager = get_interaction_manager(player)
    local interaction = get_interaction_component(actor)
    local collision = get_interaction_collision(actor)
    if noisy then
        log("  InteractionManager nil=" .. tostring(manager == nil) .. " valid=" .. tostring(is_valid(manager)))
        log("  InteractionComponent nil=" .. tostring(interaction == nil) .. " valid=" .. tostring(is_valid(interaction)))
        log("  InteractionCollision nil=" .. tostring(collision == nil) .. " valid=" .. tostring(is_valid(collision)))
    end
    if manager ~= nil and interaction ~= nil then
        local ok_req, req_result = call_method(manager, "Server_RequestInteraction", interaction, collision, false, false)
        if noisy then log("  Server_RequestInteraction ok=" .. tostring(ok_req) .. " result=" .. tostring(req_result)) end
        return ok_req
    end

    if noisy then log("  No exposed pickup/interaction path for this Placed resource actor") end
    return false
end

local function pickup_scan(noisy, lightweight)
    local player = get_player()
    if player == nil then
        if noisy then log("No DominionPlayerCharacter found") end
        return
    end

    local player_loc = get_actor_location(player)
    if player_loc == nil then
        if noisy then log("Player location unavailable: " .. safe_full_name(player)) end
        return
    end

    local world_classes = lightweight and auto_world_item_classes or manual_world_item_classes
    local resource_classes = lightweight and auto_placed_resource_classes or manual_placed_resource_classes
    local max_candidates = lightweight and max_auto_candidates_per_scan or max_manual_candidates_per_scan

    if noisy then
        log("Pickup scan started. RadiusCm=" .. tostring(pickup_radius_cm) .. " Lightweight=" .. tostring(lightweight))
        log("Player=" .. safe_full_name(player))
        log("PlayerLoc=" .. vec_text(player_loc))
    end

    local attempted = 0
    local success = 0

    for _, item in ipairs(collect_by_classes(world_classes, noisy)) do
        if attempted >= max_candidates then break end
        attempted = attempted + 1
        if try_magnetize_world_item(item, player, player_loc, noisy) then success = success + 1 end
    end

    for _, actor in ipairs(collect_by_classes(resource_classes, noisy)) do
        if attempted >= max_candidates then break end
        attempted = attempted + 1
        if try_collect_placed_resource(actor, player, player_loc, noisy) then success = success + 1 end
    end

    if noisy then log("Pickup scan finished. Attempted=" .. tostring(attempted) .. " SuccessCalls=" .. tostring(success)) end
end

local function dump_match(index, obj, object_name, class_name)
    log("UObjectMatch #" .. tostring(index))
    log("  ObjectName: " .. tostring(object_name))
    log("  ClassName: " .. tostring(class_name))
    log("  FullName: " .. safe_full_name(obj))
end

local function dump_matching_uobjects()
    local scanned = 0
    local matched = 0
    local logged = 0
    local class_counts = {}

    log("UObject discovery started. Filters=Item, Pickup, Loot, Resource, Drop, World, Tree, Log, Wood, Stone, Rock, Ore, Mineral")
    local ok, err = pcall(function()
        ForEachUObject(function(obj)
            scanned = scanned + 1
            if obj ~= nil then
                local object_name = safe_name(obj)
                local class_name = safe_class_name(obj)
                if contains_any(object_name, discovery_terms) or contains_any(class_name, discovery_terms) then
                    matched = matched + 1
                    class_counts[class_name] = (class_counts[class_name] or 0) + 1
                    if logged < max_dump_logs then
                        logged = logged + 1
                        dump_match(logged, obj, object_name, class_name)
                    end
                end
            end
        end)
    end)

    if not ok then
        log("ForEachUObject failed: " .. tostring(err))
        for _, obj in ipairs(collect_by_classes({ "Object", "Actor", "WorldActor", "WorldItem", "RuntimeSpawnedWorldItem", "TreeLog", "BaseInteractableResource" }, true)) do
            local object_name = safe_name(obj)
            local class_name = safe_class_name(obj)
            if contains_any(object_name, discovery_terms) or contains_any(class_name, discovery_terms) then
                matched = matched + 1
                if logged < max_dump_logs then
                    logged = logged + 1
                    dump_match(logged, obj, object_name, class_name)
                end
            end
        end
    end

    log("UObject discovery finished. Scanned=" .. tostring(scanned) .. " Matched=" .. tostring(matched) .. " Logged=" .. tostring(logged))
    local rows = {}
    for class_name, count in pairs(class_counts) do table.insert(rows, { class_name = class_name, count = count }) end
    table.sort(rows, function(a, b) return a.count > b.count end)
    for i = 1, math.min(#rows, 80) do log("  " .. tostring(rows[i].count) .. " x " .. rows[i].class_name) end
end

RegisterKeyBind(Key.F7, {}, function()
    ExecuteInGameThread(function()
        dump_matching_uobjects()
    end)
end)

RegisterKeyBind(Key.F8, {}, function()
    enabled = not enabled
    log("Auto pickup " .. (enabled and "ON" or "OFF") .. ". IntervalMs=" .. tostring(scan_interval_ms))
end)

RegisterKeyBind(Key.F9, {}, function()
    ExecuteInGameThread(function()
        pickup_scan(true, false)
    end)
end)

LoopAsync(scan_interval_ms, function()
    if enabled then
        ExecuteInGameThread(function()
            pickup_scan(false, true)
        end)
    end
    return false
end)

log("v0.8 loaded. F7=UObject discovery, F8=optimized wood/stone auto pickup, F9=detailed manual pickup scan.")

