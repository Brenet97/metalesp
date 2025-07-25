local license_file = "license.txt"
local function load_license_key()
    local f = io.open(license_file, "r")
    if f then
        local key = f:read("*all")
        f:close()
        return key or ""
    end
    return ""
end

local saved_key = load_license_key()

local options = {
    enabled = ui.new_checkbox("Enable Model ESP"),
    licenseInput = ui.textinput("License Key", saved_key)
}
local last_license_key = saved_key or ""
local license_checked = false
local license_valid = false
local license_check_in_progress = false

local function save_license_key(key)
    local f = io.open(license_file, "w")
    if f then
        f:write(key)
        f:close()
    end
end

local script_name = "print_workspace_objects"

local icon_url = "https://i.imgur.com/rSH2sst.png"
local rescanKey = ui.keybind("Rescan Metals", nil)
local texture = nil
local attemptedLoad = false
local hasError = false
local modelParts = {}
local last_scan_time = 0
local scan_interval = 10 -- seconds

local function collect_model_parts(parent)
    if not parent or not parent:Children() then
        return
    end
    for _, obj in ipairs(parent:Children()) do
        if obj:ClassName() == "Model" and obj:Name() == "Model" then
            local hasPrompt = false
            local part = nil
            for _, child in ipairs(obj:Children()) do
                if child:ClassName() == "ProximityPrompt" and child:Name() == "hidden-metal-prompt" then
                    hasPrompt = true
                elseif child:ClassName() == "Part" and child:Primitive() then
                    part = child
                end
            end
            if hasPrompt and part then
                table.insert(modelParts, part)
            end
        end
        if obj:Children() and #obj:Children() > 0 then
            collect_model_parts(obj)
        end
    end
end

local function update_model_cache()
    modelParts = {}
    local workspace = globals.workspace()
    if workspace then
        collect_model_parts(workspace)
    end
end

cheat.set_callback("paint", function()
    local license_key = options.licenseInput:get()
    local hwid = utils.get_hwid()

    -- Detect license key change
    if license_key ~= last_license_key then
        save_license_key(license_key)
        license_checked = false
        license_valid = false
        last_license_key = license_key
    end

    if license_key == "" then
        render.text(10, 30, "Please enter your license key!", 255, 0, 0, 255, "s", 0)
        return
    end

    -- Only check license if not checked and not already in progress
    if not license_checked and not license_check_in_progress then
        license_check_in_progress = true
        print("[DEBUG] Attempting license check...")
        local url = "https://cb80111b-34e9-4d32-b885-b261216387c5-00-30n8b4sbrj2b3.picard.replit.dev/check_license?key="..license_key.."&hwid="..hwid.."&script="..script_name
        print("[DEBUG] License check URL: " .. url)
        http.get(url, function(resp)
            print("[DEBUG] License server response: " .. tostring(resp))
            license_checked = true
            license_valid = (resp == "valid")
            license_check_in_progress = false
        end)
        render.text(10, 30, "Checking license...", 255, 255, 0, 255, "s", 0)
        return
    end

    if not license_valid then
        render.text(10, 30, "Invalid or expired license key!", 255, 0, 0, 255, "s", 0)
        return
    end

    pcall(function()
        render.text(10, 10, "Metal parts found: " .. #modelParts, 255, 255, 255, 255, 's', 0)
        if not options.enabled:get() then
            if texture or attemptedLoad or hasError then
                texture = nil
                attemptedLoad = false
                hasError = false
            end
            return
        end

        if not attemptedLoad then
            local success, result = pcall(function() return render.texture(icon_url) end)
            if success and result then
                texture = result
            else
                hasError = true
            end
            attemptedLoad = true
        end

        local now = tonumber(utils.get_tickcount()) / 1000
        if now - last_scan_time > scan_interval or rescanKey:get() then
            update_model_cache()
            last_scan_time = now
        end

        local color = options.espColor and options.espColor.get and options.espColor:get() or {r=1,g=0,b=0,a=1}
        local r, g, b, a = math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), math.floor(color.a * 255)

        for _, part in ipairs(modelParts) do
            local pos = nil
            if part and part:Primitive() then
                pos = part:Primitive():GetPartPosition()
            end
            if pos then
                local screen_pos = utils.world_to_screen(pos)
                if screen_pos and texture then
                    render.image(texture, screen_pos.x - 16, screen_pos.y - 16, screen_pos.x + 16, screen_pos.y + 16, 0, 0, 1, 1, 255, 255, 255, 200)
                end
                -- Removed label rendering here
            end
        end

        if hasError and not texture then
            render.text(10, 25, "Icon loading error", 255, 0, 0, 255, "s", 0)
        end
    end)
end)

update_model_cache()
