-- kwbind: KWin/KGlobalAccel shortcut + KWin-session autostart manager
-- Syntax target: Lua 5.1 / LuaJIT 2.1

local HOME = os.getenv("HOME")

if not HOME or HOME == "" then
    io.stderr:write("kwbind: HOME is not set\n")
    os.exit(1)
end

local XDG_DATA_HOME = os.getenv("XDG_DATA_HOME")
if not XDG_DATA_HOME or XDG_DATA_HOME == "" then
    XDG_DATA_HOME = HOME .. "/.local/share"
end

local XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME")
if not XDG_CONFIG_HOME or XDG_CONFIG_HOME == "" then
    XDG_CONFIG_HOME = HOME .. "/.config"
end

local STATE_DIR = XDG_DATA_HOME .. "/kwbind"
local RUNNER_DIR = STATE_DIR .. "/runners"
local AUTOSTART_DIR = STATE_DIR .. "/autostart"
local APP_DIR = XDG_DATA_HOME .. "/applications"
local KGLOBALACCEL_DIR = XDG_DATA_HOME .. "/kglobalaccel"
local LOCAL_BIN = HOME .. "/.local/bin"
local BIND_DB = STATE_DIR .. "/bindings.db"
local AUTOSTART_DB = STATE_DIR .. "/autostart.db"
local PENDING_DELETE_DB = STATE_DIR .. "/pending-delete.db"
local KWIN_AUTOSTART = LOCAL_BIN .. "/kwin-autostart"

local function shell_quote(s)
    s = tostring(s or "")
    if s == "" then
        return "''"
    end
    return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function desktop_escape(s)
    s = tostring(s or "")
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "")
    return s
end

local function desktop_exec_quote(s)
    s = tostring(s or "")
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "`", "\\`")
    s = string.gsub(s, "%$", "\\$")
    return '"' .. s .. '"'
end

local function execute_ok(command)
    local a, b, c = os.execute(command)
    if type(a) == "number" then
        return a == 0
    end
    if type(a) == "boolean" then
        if not a then
            return false
        end
        if c ~= nil then
            return c == 0
        end
        return true
    end
    return false
end

local function command_path(name)
    if not name or name == "" or string.sub(name, 1, 1) == "-" then
        return nil
    end

    if string.find(name, "/", 1, true) then
        if execute_ok("test -x " .. shell_quote(name)) then
            return name
        end
        return nil
    end

    local pipe = io.popen("command -v " .. shell_quote(name) .. " 2>/dev/null", "r")
    if not pipe then
        return nil
    end
    local path = pipe:read("*l")
    pipe:close()
    if path and path ~= "" then
        return path
    end
    return nil
end

local function ensure_dir(path)
    if not execute_ok("mkdir -p -- " .. shell_quote(path)) then
        io.stderr:write("kwbind: cannot create directory: " .. path .. "\n")
        os.exit(1)
    end
end

local function read_all(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    return data
end

local function write_atomic(path, data)
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "wb")
    if not f then
        return nil, err
    end
    local ok, write_err = f:write(data)
    if not ok then
        f:close()
        os.remove(tmp)
        return nil, write_err
    end
    f:close()
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        os.remove(tmp)
        return nil, rename_err
    end
    return true
end

local function copy_file(src, dst)
    local data = read_all(src)
    if data == nil then
        return nil, "cannot read " .. src
    end
    return write_atomic(dst, data)
end

local function hex_encode(s)
    return (string.gsub(s, ".", function(c)
        return string.format("%02x", string.byte(c))
    end))
end

local function hex_decode(s)
    if not s or (#s % 2) ~= 0 or string.find(s, "[^0-9a-fA-F]") then
        return nil
    end
    return (string.gsub(s, "(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

local function save_bindings(db)
    local keys = {}
    local key
    for key in pairs(db) do
        table.insert(keys, key)
    end
    table.sort(keys)

    local out = {}
    local i
    for i = 1, #keys do
        key = keys[i]
        local rec = db[key]
        table.insert(out, hex_encode(key) .. "\t" .. hex_encode(rec.display) .. "\n")
    end
    return write_atomic(BIND_DB, table.concat(out))
end

local function load_bindings()
    local db = {}
    local f = io.open(BIND_DB, "r")
    if not f then
        return db
    end
    for line in f:lines() do
        local a, b = string.match(line, "^([^\t]+)\t([^\t]*)$")
        if a and b then
            local key = hex_decode(a)
            local display = hex_decode(b)
            if key and display then
                db[key] = { display = display }
            end
        end
    end
    f:close()
    return db
end

local function save_pending_deletes(db)
    local keys = {}
    local key
    for key in pairs(db) do
        table.insert(keys, key)
    end
    table.sort(keys)

    local out = {}
    local i
    for i = 1, #keys do
        table.insert(out, hex_encode(keys[i]) .. "\n")
    end
    return write_atomic(PENDING_DELETE_DB, table.concat(out))
end

local function load_pending_deletes()
    local db = {}
    local f = io.open(PENDING_DELETE_DB, "r")
    if not f then
        return db
    end
    for line in f:lines() do
        local key = hex_decode(line)
        if key then
            db[key] = true
        end
    end
    f:close()
    return db
end

local function save_autostarts(db)
    local ids = {}
    local id
    for id in pairs(db) do
        table.insert(ids, id)
    end
    table.sort(ids)

    local out = {}
    local i
    for i = 1, #ids do
        id = ids[i]
        table.insert(out, tostring(id) .. "\t" .. hex_encode(db[id].display) .. "\n")
    end
    return write_atomic(AUTOSTART_DB, table.concat(out))
end

local function load_autostarts()
    local db = {}
    local f = io.open(AUTOSTART_DB, "r")
    if not f then
        return db
    end
    for line in f:lines() do
        local a, b = string.match(line, "^(%d+)\t([^\t]*)$")
        if a and b then
            local id = tonumber(a)
            local display = hex_decode(b)
            if id and display then
                db[id] = { display = display }
            end
        end
    end
    f:close()
    return db
end

local function make_display(path, args, first)
    local parts = { shell_quote(path) }
    local i
    for i = first, #args do
        table.insert(parts, shell_quote(args[i]))
    end
    return table.concat(parts, " ")
end

local function write_runner(path, command, args, first)
    local parts = { "#!/bin/sh\nexec ", shell_quote(command) }
    local i
    for i = first, #args do
        table.insert(parts, " ")
        table.insert(parts, shell_quote(args[i]))
    end
    table.insert(parts, "\n")

    local ok, err = write_atomic(path, table.concat(parts))
    if not ok then
        return nil, err
    end
    if not execute_ok("chmod 755 -- " .. shell_quote(path)) then
        return nil, "chmod failed"
    end
    return true
end

local function refresh_service_cache()
    local kbuild = command_path("kbuildsycoca6")
    if kbuild then
        os.execute(shell_quote(kbuild) .. " --noincremental >/dev/null 2>&1")
    end
end

local function write_shortcut_config(desktop_name, key)
    local kwrite = command_path("kwriteconfig6")
    if not kwrite then
        return nil, "kwriteconfig6 not found (install kde-cli-tools)"
    end

    local cmd = shell_quote(kwrite)
        .. " --file kglobalshortcutsrc"
        .. " --group services"
        .. " --group " .. shell_quote(desktop_name)
        .. " --key _launch " .. shell_quote(key)

    if not execute_ok(cmd) then
        return nil, "kwriteconfig6 failed"
    end
    return true
end

local function delete_shortcut_config(desktop_name)
    local kwrite = command_path("kwriteconfig6")
    if not kwrite then
        return nil, "kwriteconfig6 not found (install kde-cli-tools)"
    end

    local cmd = shell_quote(kwrite)
        .. " --file kglobalshortcutsrc"
        .. " --group services"
        .. " --group " .. shell_quote(desktop_name)
        .. " --key _launch --delete ''"

    if not execute_ok(cmd) then
        return nil, "kwriteconfig6 --delete failed"
    end
    return true
end

local function binding_id(key)
    return "net.local.kwbind." .. hex_encode(key)
end

local function remove_binding(key, quiet)
    local id = binding_id(key)
    local desktop_name = id .. ".desktop"
    local runner = RUNNER_DIR .. "/" .. id

    local ok, err = delete_shortcut_config(desktop_name)
    if not ok then
        io.stderr:write("kwbind: " .. err .. "\n")
        return false
    end

    os.remove(APP_DIR .. "/" .. desktop_name)
    os.remove(KGLOBALACCEL_DIR .. "/" .. desktop_name)
    os.remove(runner)

    local db = load_bindings()
    db[key] = nil
    local saved, save_err = save_bindings(db)
    if not saved then
        io.stderr:write("kwbind: cannot update binding database: " .. tostring(save_err) .. "\n")
        return false
    end

    local pending = load_pending_deletes()
    pending[key] = true
    local pending_saved, pending_err = save_pending_deletes(pending)
    if not pending_saved then
        io.stderr:write("kwbind: cannot update pending-delete database: " .. tostring(pending_err) .. "\n")
        return false
    end

    refresh_service_cache()

    if not quiet then
        print("removed: " .. key)
        print("restart through start-kwin; kwbind sync will remove it before KWin starts")
    end
    return true
end

local function add_binding(key, args)
    if not key or key == "" or #args < 1 then
        io.stderr:write("usage: kwbind Meta+Return command [args...]\n")
        return false
    end

    local command = args[1]
    local path = command_path(command)
    if not path then
        io.stderr:write("kwbind: command not found or not executable: " .. tostring(command) .. "\n")
        return false
    end

    local id = binding_id(key)
    local desktop_name = id .. ".desktop"
    local runner = RUNNER_DIR .. "/" .. id

    local runner_ok, runner_err = write_runner(runner, path, args, 2)
    if not runner_ok then
        io.stderr:write("kwbind: cannot create runner: " .. tostring(runner_err) .. "\n")
        return false
    end

    local desktop = table.concat({
        "[Desktop Entry]\n",
        "Type=Application\n",
        "Name=kwbind ", desktop_escape(key), "\n",
        "Exec=", desktop_exec_quote(runner), "\n",
        "NoDisplay=true\n",
        "StartupNotify=false\n",
        "X-KDE-GlobalAccel-CommandShortcut=true\n"
    })

    local app_path = APP_DIR .. "/" .. desktop_name
    local accel_path = KGLOBALACCEL_DIR .. "/" .. desktop_name

    local wrote, write_err = write_atomic(app_path, desktop)
    if not wrote then
        io.stderr:write("kwbind: cannot write desktop file: " .. tostring(write_err) .. "\n")
        return false
    end

    local copied, copy_err = copy_file(app_path, accel_path)
    if not copied then
        io.stderr:write("kwbind: cannot copy desktop file to kglobalaccel: " .. tostring(copy_err) .. "\n")
        return false
    end

    local config_ok, config_err = write_shortcut_config(desktop_name, key)
    if not config_ok then
        io.stderr:write("kwbind: " .. tostring(config_err) .. "\n")
        return false
    end

    local db = load_bindings()
    db[key] = { display = make_display(path, args, 2) }
    local saved, save_err = save_bindings(db)
    if not saved then
        io.stderr:write("kwbind: cannot update binding database: " .. tostring(save_err) .. "\n")
        return false
    end

    local pending = load_pending_deletes()
    if pending[key] then
        pending[key] = nil
        local pending_saved, pending_err = save_pending_deletes(pending)
        if not pending_saved then
            io.stderr:write("kwbind: cannot update pending-delete database: " .. tostring(pending_err) .. "\n")
            return false
        end
    end

    refresh_service_cache()

    print("bound: " .. key .. " -> " .. db[key].display)
    print("restart through start-kwin; kwbind sync will apply it before KWin starts")
    return true
end

local function sync_bindings()
    local pending = load_pending_deletes()
    local key

    for key in pairs(pending) do
        local desktop_name = binding_id(key) .. ".desktop"
        local ok, err = delete_shortcut_config(desktop_name)
        if not ok then
            io.stderr:write("kwbind: sync delete failed for " .. key .. ": " .. tostring(err) .. "\n")
            return false
        end
    end

    local db = load_bindings()
    for key in pairs(db) do
        local desktop_name = binding_id(key) .. ".desktop"
        local ok, err = write_shortcut_config(desktop_name, key)
        if not ok then
            io.stderr:write("kwbind: sync write failed for " .. key .. ": " .. tostring(err) .. "\n")
            return false
        end
    end

    local cleared, clear_err = save_pending_deletes({})
    if not cleared then
        io.stderr:write("kwbind: cannot clear pending-delete database: " .. tostring(clear_err) .. "\n")
        return false
    end

    refresh_service_cache()
    print("kwbind shortcuts synced")
    return true
end

local function list_bindings()
    local db = load_bindings()
    local keys = {}
    local key
    for key in pairs(db) do
        table.insert(keys, key)
    end
    table.sort(keys)

    if #keys == 0 then
        print("no kwbind shortcuts")
        return true
    end

    local i
    for i = 1, #keys do
        key = keys[i]
        print(key .. " -> " .. db[key].display)
    end
    return true
end

local function resolve_self()
    local installed = command_path("kwbind")
    if installed then
        return installed
    end

    local self = arg and arg[0] or nil
    if not self or self == "" then
        return nil
    end
    if string.find(self, "/", 1, true) then
        if string.sub(self, 1, 1) == "/" then
            return self
        end
        local pwd_pipe = io.popen("pwd -P", "r")
        if not pwd_pipe then
            return self
        end
        local pwd = pwd_pipe:read("*l")
        pwd_pipe:close()
        if pwd and pwd ~= "" then
            return pwd .. "/" .. self
        end
        return self
    end
    return command_path(self)
end

local function install_autostart_runner()
    local self = resolve_self()
    if not self then
        return nil, "cannot resolve kwbind executable path"
    end

    if not execute_ok("test -x " .. shell_quote(self)) then
        return nil, "kwbind is not an executable yet; build/install the SRLua executable first"
    end

    local body = "#!/bin/sh\nexec " .. shell_quote(self) .. " autostart run\n"
    local ok, err = write_atomic(KWIN_AUTOSTART, body)
    if not ok then
        return nil, err
    end
    if not execute_ok("chmod 755 -- " .. shell_quote(KWIN_AUTOSTART)) then
        return nil, "chmod failed"
    end
    return true
end

local function autostart_add(args)
    if #args < 1 then
        io.stderr:write("usage: kwbind autostart add command [args...]\n")
        return false
    end

    local command = args[1]
    local path = command_path(command)
    if not path then
        io.stderr:write("kwbind: command not found or not executable: " .. tostring(command) .. "\n")
        return false
    end

    local db = load_autostarts()
    local id = 1
    while db[id] do
        id = id + 1
    end

    local runner = AUTOSTART_DIR .. "/" .. string.format("%04d", id) .. ".run"
    local runner_ok, runner_err = write_runner(runner, path, args, 2)
    if not runner_ok then
        io.stderr:write("kwbind: cannot create autostart runner: " .. tostring(runner_err) .. "\n")
        return false
    end

    db[id] = { display = make_display(path, args, 2) }
    local saved, save_err = save_autostarts(db)
    if not saved then
        io.stderr:write("kwbind: cannot update autostart database: " .. tostring(save_err) .. "\n")
        return false
    end

    local installed, install_err = install_autostart_runner()
    if not installed then
        io.stderr:write("kwbind: note: autostart entry saved, but kwin-autostart was not installed: " .. tostring(install_err) .. "\n")
        io.stderr:write("kwbind: after installing the executable, run: kwbind autostart install\n")
    end

    print(string.format("autostart [%d]: %s", id, db[id].display))
    return true
end

local function autostart_remove(id_text)
    local id = tonumber(id_text)
    if not id or id < 1 or id ~= math.floor(id) then
        io.stderr:write("usage: kwbind autostart remove NUMBER\n")
        return false
    end

    local db = load_autostarts()
    if not db[id] then
        io.stderr:write("kwbind: no autostart entry: " .. tostring(id) .. "\n")
        return false
    end

    local old = db[id].display
    db[id] = nil
    os.remove(AUTOSTART_DIR .. "/" .. string.format("%04d", id) .. ".run")

    local saved, save_err = save_autostarts(db)
    if not saved then
        io.stderr:write("kwbind: cannot update autostart database: " .. tostring(save_err) .. "\n")
        return false
    end

    print(string.format("autostart removed [%d]: %s", id, old))
    return true
end

local function autostart_list()
    local db = load_autostarts()
    local ids = {}
    local id
    for id in pairs(db) do
        table.insert(ids, id)
    end
    table.sort(ids)

    if #ids == 0 then
        print("no autostart programs")
        return true
    end

    local i
    for i = 1, #ids do
        id = ids[i]
        print(string.format("[%d] %s", id, db[id].display))
    end
    return true
end

local function autostart_run()
    local db = load_autostarts()
    local ids = {}
    local id
    for id in pairs(db) do
        table.insert(ids, id)
    end
    table.sort(ids)

    local i
    for i = 1, #ids do
        id = ids[i]
        local runner = AUTOSTART_DIR .. "/" .. string.format("%04d", id) .. ".run"
        if execute_ok("test -x " .. shell_quote(runner)) then
            os.execute(shell_quote(runner) .. " >/dev/null 2>&1 &")
        else
            io.stderr:write("kwbind: missing autostart runner for [" .. tostring(id) .. "]\n")
        end
    end
    return true
end

local function doctor()
    local failed = false
    local required = { "kwriteconfig6", "kwin_wayland" }
    local optional = { "kbuildsycoca6", "waybar", "fuzzel", "swaybg", "konsole" }
    local i

    print("required:")
    for i = 1, #required do
        local path = command_path(required[i])
        if path then
            print("  OK   " .. required[i] .. " -> " .. path)
        else
            print("  MISS " .. required[i])
            failed = true
        end
    end

    print("optional/session tools:")
    for i = 1, #optional do
        local path = command_path(optional[i])
        if path then
            print("  OK   " .. optional[i] .. " -> " .. path)
        else
            print("  MISS " .. optional[i])
        end
    end

    if read_all(KWIN_AUTOSTART) then
        print("  OK   kwin-autostart -> " .. KWIN_AUTOSTART)
    else
        print("  MISS kwin-autostart (created by: kwbind autostart install)")
    end

    if failed then
        return false
    end
    return true
end

local function usage()
    print("usage:")
    print("  kwbind Meta+Return command [args...]")
    print("  kwbind remove Meta+Return")
    print("  kwbind list")
    print("  kwbind sync")
    print("  kwbind autostart add command [args...]")
    print("  kwbind autostart remove NUMBER")
    print("  kwbind autostart list")
    print("  kwbind autostart install")
    print("  kwbind autostart run")
    print("  kwbind doctor")
end

ensure_dir(STATE_DIR)
ensure_dir(RUNNER_DIR)
ensure_dir(AUTOSTART_DIR)
ensure_dir(APP_DIR)
ensure_dir(KGLOBALACCEL_DIR)
ensure_dir(LOCAL_BIN)

local a1 = arg[1]
local ok = false

if a1 == "list" then
    ok = list_bindings()
elseif a1 == "sync" then
    ok = sync_bindings()
elseif a1 == "remove" or a1 == "rm" or a1 == "del" then
    if not arg[2] or arg[3] then
        io.stderr:write("usage: kwbind remove Meta+Return\n")
        ok = false
    else
        ok = remove_binding(arg[2], false)
    end
elseif a1 == "autostart" then
    local sub = arg[2]
    if sub == "add" then
        local args = {}
        local i
        for i = 3, #arg do
            table.insert(args, arg[i])
        end
        ok = autostart_add(args)
    elseif sub == "remove" or sub == "rm" or sub == "del" then
        if not arg[3] or arg[4] then
            io.stderr:write("usage: kwbind autostart remove NUMBER\n")
            ok = false
        else
            ok = autostart_remove(arg[3])
        end
    elseif sub == "list" then
        ok = autostart_list()
    elseif sub == "run" then
        ok = autostart_run()
    elseif sub == "install" then
        local installed, err = install_autostart_runner()
        if installed then
            print("installed: " .. KWIN_AUTOSTART)
            ok = true
        else
            io.stderr:write("kwbind: " .. tostring(err) .. "\n")
            ok = false
        end
    else
        usage()
        ok = false
    end
elseif a1 == "doctor" then
    ok = doctor()
elseif not a1 then
    usage()
    ok = false
else
    local args = {}
    local i
    for i = 2, #arg do
        table.insert(args, arg[i])
    end
    ok = add_binding(a1, args)
end

if ok then
    os.exit(0)
else
    os.exit(1)
end
