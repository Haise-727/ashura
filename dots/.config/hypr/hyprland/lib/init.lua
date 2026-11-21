HOME = os.getenv("HOME")

function is_file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

function create_if_not_exists(path)
   if not is_file_exists(path) then
      os.execute("mkdir -p \"$(dirname \"" .. path .. "\")\"")
      os.execute("echo '-- This file will not be overwritten across Ashura updates.\n-- The file name is for the sake of organization and does not matter\n-- See the corresponding files in ~/.config/hypr/hyprland for examples' > \"" .. path .. "\"")
      return true
   end
   return false
end

function workspace_in_group(i)
    local curr = hl.get_active_workspace().id
    local newVal = math.floor((curr - 1) / workspaceGroupSize) * workspaceGroupSize + i
    -- hl.notification.create({ text = "curr " .. curr .. " floor " .. math.floor(curr / 10) .. " new " .. newVal, duration = 5000 })
    return newVal
end

-- Ashura: the workspace `d` steps away inside the current group of ten,
-- clamped to the group (1-10, 101-110, ...).
function ashura_group_target(d)
    local id = hl.get_active_workspace().id
    local base = math.floor((id - 1) / workspaceGroupSize) * workspaceGroupSize
    return math.max(base + 1, math.min(base + workspaceGroupSize, id + d))
end
function ashura_group_step(d)
    hl.dispatch(hl.dsp.focus({ workspace = ashura_group_target(d) }))
end
function ashura_group_send(d)
    hl.dispatch(hl.dsp.window.move({ workspace = ashura_group_target(d) }))
end
