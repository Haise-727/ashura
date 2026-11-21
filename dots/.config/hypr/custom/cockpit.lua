-- Ashura cockpit: a space of its own, workspaces 101-110, apart from user space
-- (workspaces 1-10). The base config already groups workspaces in tens, so inside the
-- cockpit Super+1..0, Super+Shift+N, the bar and the overview all work on
-- 101-110 with no extra binds; in user space they work on 1-10 as before.
--
-- There is ONE cockpit and one repo in it at a time. Every window on 101-110
-- belongs to the repo on stage: open it there, or move it there, and it is part
-- of that repo's environment. Switching repo parks the current repo's windows in
-- a hidden special workspace of their own (`special:cp-<id>`, never shown), each
-- remembering its slot with a tag (`cpslot<n>`), and brings the next repo's
-- windows back to the same slots. Nothing is closed by switching or leaving.
--
-- Super+D goes in (to the cockpit workspace you were last on) and back out (to
-- the user workspace you came from). Super+Space picks a repo.
--
-- Late windows: VS Code and kitty can take a few seconds to appear, by which time
-- you may have left the cockpit. kitty started with class `kitty-cockpit` and a VS
-- Code window whose title names the repo's folder are claimed wherever they open
-- and moved into the cockpit. Nothing else is claimed by class (a restored Firefox
-- session must never be pulled in).
--
-- devpit owns the list of cockpits and their launch commands; the shell asks it,
-- then calls `ashura_cockpit.open(id, name, { cmds }, unique_name)`. Nothing here
-- runs a blocking command: a slow call inside the compositor freezes the desktop.

local M = {}
ashura_cockpit = M

local BASE = 100                               -- cockpit workspaces are BASE+1..BASE+10
local SLOTS = 10
local CLAIM_SECONDS = 30
local KITTY_CLASS = "kitty-cockpit"
local STATE_FILE = os.getenv("HOME") .. "/.local/state/ashura/cockpit.json"
-- Where each app of each repo sits (class -> slot), kept up to date while you
-- work, so a repo opened again (after closing it, or after a reboot) brings its
-- apps back to the same workspaces. New repos: Firefox 1, VS Code 2, terminal 3.
local LAYOUT_FILE = os.getenv("HOME") .. "/.local/state/ashura/cockpit-layouts.json"
local DEFAULT_SLOT = { firefox = 1, code = 2, ["kitty-cockpit"] = 3 }
local PLACE_SECONDS = 30

-- Created once at load; write_state() runs on every window event and must not fork.
os.execute('mkdir -p "' .. STATE_FILE:match("(.*)/") .. '"')

M.current = nil       -- id of the repo on stage
M.names = {}          -- id -> display name
M.unique = {}         -- id -> folder name is unique (safe to match VS Code by title)
M.claims = {}         -- { id, kind = "kitty" | "code", deadline }
M.lastUser = 1        -- user workspace to return to
M.lastCockpit = BASE + 1
M.layouts = {}        -- id -> { class -> slot }
M.placing = {}        -- class -> deadline: a launched app still on its way

------------------------------------------------------------------ helpers
local function park(id) return "special:cp-" .. id end
local function addr(w) return "address:" .. w.address end
local function cls(w) return (w.class or ""):lower() end
local function wsid(w) return (w.workspace and w.workspace.id) or 0 end
local function wsname(w) return (w.workspace and w.workspace.name) or "" end
local function is_cockpit_ws(id) return id > BASE and id <= BASE + SLOTS end
local function in_cockpit(w) return is_cockpit_ws(wsid(w)) end

local function active_id()
    local ws = hl.get_active_workspace()
    return ws and ws.id or 1
end

local function tag_value(w, prefix)
    for _, t in ipairs(w.tags or {}) do
        local v = t:match("^" .. prefix .. "(.-)%*?$")
        if v then return v end
    end
    return nil
end
local function tag_of(w) return tag_value(w, "cockpit:") end
local function slot_of(w) return tonumber(tag_value(w, "cpslot") or "") end

local function tag(w, t) hl.dispatch(hl.dsp.window.tag({ tag = t, window = addr(w) })) end

local function settag(w, id)
    local old = tag_of(w)
    if old == id then return end
    if old then tag(w, "-cockpit:" .. old) end
    tag(w, "+cockpit:" .. id)
end

local function setslot(w, n)
    local old = slot_of(w)
    if old == n then return end
    if old then tag(w, "-cpslot" .. old) end
    tag(w, "+cpslot" .. n)
end

local function move(w, ws)
    hl.dispatch(hl.dsp.window.move({ workspace = ws, follow = false, window = addr(w) }))
end

local function focus(ws) hl.dispatch(hl.dsp.focus({ workspace = ws })) end

-- The repo's windows: on stage they are whatever sits on 101-110; parked ones
-- carry its tag.
local function cockpit_windows(skip)
    local out = {}
    for _, w in ipairs(hl.get_windows()) do
        if in_cockpit(w) and (not skip or w.address ~= skip.address) then table.insert(out, w) end
    end
    return out
end

local function parked_windows(id, skip)
    local out = {}
    for _, w in ipairs(hl.get_windows()) do
        if wsname(w) == park(id) and (not skip or w.address ~= skip.address) then table.insert(out, w) end
    end
    return out
end

local function json_str(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
end

-- The shell reads this (bar, dashboard, picker). `skip` is a window that is still
-- listed but about to go (window.close fires before Hyprland drops it).
local remember         -- defined below; write_state calls it
function M.write_state(skip)
    remember()
    local counts = {}
    for _, w in ipairs(hl.get_windows()) do
        if not skip or w.address ~= skip.address then
            local id = nil
            if in_cockpit(w) then id = M.current
            else id = wsname(w):match("^special:cp%-(.+)$") end
            if id then counts[id] = (counts[id] or 0) + 1 end
        end
    end
    local parts = {}
    for id, n in pairs(counts) do
        table.insert(parts, json_str(id) .. ': {"name": ' .. json_str(M.names[id] or id) .. ', "windows": ' .. n .. '}')
    end
    local body = '{"current": ' .. (M.current and json_str(M.current) or "null")
        .. ', "currentName": ' .. (M.current and json_str(M.names[M.current] or M.current) or "null")
        .. ', "visible": ' .. tostring(is_cockpit_ws(active_id()))
        .. ', "lastUser": ' .. M.lastUser .. ', "lastCockpit": ' .. M.lastCockpit
        .. ', "repos": {' .. table.concat(parts, ", ") .. '}}\n'
    local tmp = STATE_FILE .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(body)
    f:close()
    os.rename(tmp, STATE_FILE)
end

-- VS Code titles are "<file> - <folder> - Visual Studio Code" or
-- "<folder> - Visual Studio Code". Plain finds: repo names contain "-", which is
-- magic in Lua patterns.
local function title_names(title, name)
    title = title or ""
    return title:find(" - " .. name .. " - ", 1, true) ~= nil
        or title:find(name .. " - Visual Studio Code", 1, true) == 1
end

local function existing_editor(name)
    for _, w in ipairs(hl.get_windows()) do
        if cls(w) == "code" and not in_cockpit(w) and not wsname(w):match("^special:")
            and title_names(w.title, name) then return w end
    end
    return nil
end

local function kind_of(cmd)
    local prog = cmd:match("^%s*'?([^%s']+)") or ""
    prog = prog:match("([^/]+)$") or prog
    if prog == "code" then return "code" end
    if prog == "kitty" and cmd:find(KITTY_CLASS, 1, true) then return "kitty" end
    return nil
end

local function claims_pending(id)
    local now = os.time()
    for _, c in ipairs(M.claims) do
        if c.id == id and c.deadline >= now then return true end
    end
    return false
end

local function slot_for(id, class)
    return (M.layouts[id] or {})[class] or DEFAULT_SLOT[class] or 1
end

local function save_layouts()
    local repos = {}
    for id, l in pairs(M.layouts) do
        local parts = {}
        for c, n in pairs(l) do table.insert(parts, json_str(c) .. ": " .. n) end
        table.insert(repos, json_str(id) .. ": {" .. table.concat(parts, ", ") .. "}")
    end
    local tmp = LAYOUT_FILE .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write("{" .. table.concat(repos, ", ") .. "}\n")
    f:close()
    os.rename(tmp, LAYOUT_FILE)
end

-- Record where the repo on stage has its apps (only changes are written).
remember = function()
    local id = M.current
    if not id then return end
    local l = M.layouts[id] or {}
    local changed = false
    for _, w in ipairs(cockpit_windows()) do
        local c, n = cls(w), wsid(w) - BASE
        if c ~= "" and l[c] ~= n then l[c] = n; changed = true end
    end
    M.layouts[id] = l
    if changed then save_layouts() end
end

-- Where a repo's window goes when it arrives late: its app's slot if that repo
-- is on stage, otherwise straight to its parking.
local function home_for(id, w)
    if M.current ~= id then return park(id) end
    return tostring(BASE + slot_for(id, w and cls(w) or ""))
end

-- A just-launched app of the repo on stage goes to its slot.
local function place_launched(w)
    local c = cls(w)
    local deadline = M.placing[c]
    if not deadline or deadline < os.time() or not M.current then return false end
    M.placing[c] = nil
    local target = BASE + slot_for(M.current, c)
    if wsid(w) ~= target then move(w, tostring(target)) end
    return true
end

-- Try to claim a window that opened OUTSIDE the cockpit for a pending launch.
local function try_claim(w)
    local now, c = os.time(), cls(w)
    local keep, claimed = {}, nil
    for _, cl in ipairs(M.claims) do
        if cl.deadline < now then
            -- expired: drop it
        elseif not claimed and ((cl.kind == "kitty" and c == KITTY_CLASS)
            or (cl.kind == "code" and c == "code" and title_names(w.title, M.names[cl.id] or ""))) then
            claimed = cl
        else
            table.insert(keep, cl)
        end
    end
    M.claims = keep
    if not claimed then return false end
    settag(w, claimed.id)
    M.placing[cls(w)] = nil
    if not in_cockpit(w) or claimed.id == M.current then move(w, home_for(claimed.id, w)) end
    return true
end

-- Park everything on 101-110 under `id`, remembering each window's slot.
local function park_all(id)
    for _, w in ipairs(cockpit_windows()) do
        settag(w, id)
        setslot(w, wsid(w) - BASE)
        move(w, park(id))
    end
end

-- Bring `id`'s parked windows back to their slots.
local function unpark(id)
    for _, w in ipairs(parked_windows(id)) do
        move(w, tostring(BASE + (slot_of(w) or 1)))
    end
end

------------------------------------------------------------------ actions
function M.enter()
    if not M.current then
        hl.dispatch(hl.dsp.global("quickshell:cockpitPicker"))
        return
    end
    local a = active_id()
    if not is_cockpit_ws(a) and a > 0 then M.lastUser = a end
    focus(tostring(M.lastCockpit))
    M.write_state()
end

function M.leave()
    focus(tostring(M.lastUser))
    M.write_state()
end

function M.toggle()
    if is_cockpit_ws(active_id()) then M.leave() else M.enter() end
end
-- Older name kept for the shell's callers.
M.show = M.enter
M.hide = M.leave

-- Put repo `id` on stage and go into the cockpit. `cmds` (shell strings) run only
-- when the repo has no windows at all: the first open since login or since it
-- was closed.
function M.open(id, name, cmds, unique)
    M.names[id] = name or id
    M.unique[id] = unique ~= false
    local a = active_id()
    if not is_cockpit_ws(a) and a > 0 then M.lastUser = a end

    if M.current ~= id then
        if M.current then
            park_all(M.current)
        else
            -- Windows that sat in the cockpit with no repo on stage belong to
            -- nobody: send them back to user space rather than adopt them.
            for _, w in ipairs(cockpit_windows()) do move(w, tostring(M.lastUser)) end
        end
        M.current = id
        unpark(id)
        M.lastCockpit = BASE + 1
    end
    focus(tostring(M.lastCockpit))

    if #cockpit_windows() == 0 and not claims_pending(id) then
        local deadline = os.time() + CLAIM_SECONDS
        for _, cmd in ipairs(cmds or {}) do
            local kind = kind_of(cmd)
            local adopt = (kind == "code" and M.unique[id]) and existing_editor(M.names[id]) or nil
            if adopt then
                move(adopt, tostring(M.lastCockpit))
            else
                if kind == "kitty" or (kind == "code" and M.unique[id]) then
                    table.insert(M.claims, { id = id, kind = kind, deadline = deadline })
                end
                local prog = (cmd:match("^%s*'?([^%s']+)") or ""):match("([^/]+)$") or ""
                local class = (kind == "kitty") and KITTY_CLASS or prog
                if DEFAULT_SLOT[class] or (M.layouts[id] or {})[class] then
                    M.placing[class] = os.time() + PLACE_SECONDS
                end
                hl.exec_cmd(cmd)
            end
        end
    end
    M.write_state()
end

-- Send the focused window to the same slot in the other space: user ws 3 <->
-- cockpit ws 103. Into the cockpit it joins the repo on stage; out of it, it
-- stops belonging to the repo (window.move_to_workspace drops the tags).
function M.send_other()
    local id = active_id()
    local slot = ((id - 1) % SLOTS) + 1
    local target = is_cockpit_ws(id) and slot or (BASE + slot)
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(target), follow = false }))
    M.write_state()
end

-- Close every window of a repo, on stage or parked. The repo stays current until
-- its windows are really gone: one that refuses (unsaved changes) keeps it, and
-- window.destroy clears it once the last one goes.
function M.close(id)
    local keep = {}
    for _, cl in ipairs(M.claims) do
        if cl.id ~= id then table.insert(keep, cl) end
    end
    M.claims = keep
    local list = parked_windows(id)
    if M.current == id then
        for _, w in ipairs(cockpit_windows()) do table.insert(list, w) end
    end
    for _, w in ipairs(list) do
        hl.dispatch(hl.dsp.window.close({ window = addr(w) }))
    end
    M.write_state()
end

------------------------------------------------------------------ events
hl.on("window.open", function(w)
    if not w then return end
    local claimed = (not in_cockpit(w) and #M.claims > 0) and try_claim(w)
    -- Firefox is only placed when it opened inside the cockpit (a window of
    -- your own browsing elsewhere must never be pulled in).
    if not claimed and in_cockpit(w) then place_launched(w) end
    M.write_state()
end)

-- VS Code shows its folder in the title only once it has loaded it, and may
-- reuse an empty window instead of opening one: both arrive here.
hl.on("window.title", function(w)
    if w and cls(w) == "code" and not in_cockpit(w) and #M.claims > 0 then
        if try_claim(w) then M.write_state() end
    end
end)

hl.on("window.close", function(w) M.write_state(w) end)

hl.on("window.destroy", function(w)
    -- The repo on stage is done once its last window is gone and nothing it
    -- launched is still on its way. Then Super+D asks for a repo again.
    if M.current and #cockpit_windows(w) == 0 and #parked_windows(M.current, w) == 0
        and not claims_pending(M.current) then
        M.current = nil
    end
    M.write_state(w)
end)

-- A window moved out of the cockpit by hand stops belonging to the repo.
hl.on("window.move_to_workspace", function(w)
    if not w then return end
    local id = tag_of(w)
    if id and not in_cockpit(w) and wsname(w) ~= park(id) then
        tag(w, "-cockpit:" .. id)
        local s = slot_of(w)
        if s then tag(w, "-cpslot" .. s) end
    end
    M.write_state()
end)

-- Remember where you were on each side, for Super+D.
-- The 3-finger swipe walks plain ids (hyprland/general.lua), so one step past
-- the end of a group of ten lands in the next group. Nothing else moves by a
-- single id across a group edge (binds are clamped to the group), so such a
-- step is a swipe overshoot: go back, and do not record the passing workspace.
-- The jump back MUST NOT be dispatched from inside this handler: Hyprland fires
-- workspace.active in the middle of finishing the swipe and keeps using the
-- swipe's state afterwards, so changing workspace here crashed Hyprland
-- (2026-11-11). It goes out as a separate hyprctl call a moment later instead.
local lastSeen = nil
hl.on("workspace.active", function(ws)
    local id = ws and ws.id or active_id()
    local prev = lastSeen
    lastSeen = id
    if prev and id and prev > 0 and id > 0 and math.abs(id - prev) == 1
        and math.floor((id - 1) / workspaceGroupSize) ~= math.floor((prev - 1) / workspaceGroupSize) then
        lastSeen = prev
        hl.exec_cmd(string.format("sleep 0.15; hyprctl dispatch 'hl.dsp.focus({ workspace = %d })'", prev))
        return
    end
    if is_cockpit_ws(id) then M.lastCockpit = id
    elseif id and id > 0 then M.lastUser = id end
    M.write_state()
end)

-- After a config reload the Lua state is fresh: the repo on stage, names and
-- positions come back from the last state file (its format is ours, written
-- above, so a pattern read is safe).
do
    local f = io.open(STATE_FILE, "r")
    if f then
        local prev = f:read("*a")
        f:close()
        for id, name in prev:gmatch('"([^"]+)": {"name": "([^"]*)"') do M.names[id] = name end
        local cur = prev:match('"current": "([^"]*)"')
        if cur and #cur > 0 then M.current = cur end
        M.lastUser = tonumber(prev:match('"lastUser": (%d+)') or "") or M.lastUser
        M.lastCockpit = tonumber(prev:match('"lastCockpit": (%d+)') or "") or M.lastCockpit
    end
end
do
    local f = io.open(LAYOUT_FILE, "r")
    if f then
        local txt = f:read("*a")
        f:close()
        for id, body in txt:gmatch('"([^"]+)": {([^}]*)}') do
            local l = {}
            for c, n in body:gmatch('"([^"]+)": (%d+)') do l[c] = tonumber(n) end
            M.layouts[id] = l
        end
    end
end

-- From the first design (one special workspace as the stage): anything still
-- sitting there moves into the cockpit space.
for _, w in ipairs(hl.get_windows()) do
    if wsname(w) == "special:cockpit" then move(w, tostring(BASE + 1)) end
end
M.write_state()

return M
