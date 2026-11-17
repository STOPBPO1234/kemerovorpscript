
--// v0xt ;)

--// Knit Loader
local Knit = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/matpatz/Roblox/refs/heads/main/src/Modules/Knit/init.lua"
))()

repeat
    task.wait()
until Knit and Knit.wrappers and Knit.services and Knit.git

local wrappers = Knit.wrappers
local services = Knit.services

--// ESP
local esp = Knit.require("Libraries/Esp/v1", "main")

--// Obsidian UI
local Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = loadstring(
    game:HttpGet(Repo .. "Library.lua")
)()

--// Window
local Window = Library:CreateWindow({
    Title = "v0xt ;)",
    Footer = "Subtitle",
    ToggleKeybind = Enum.KeyCode.RightControl,
    Center = true,
    AutoShow = true,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

--// Tabs
local Visuals = Window:AddTab("Visuals", "eye")

--// Sections
local PlayerSection = Visuals:AddLeftGroupbox("Player")
local ColorsSection = Visuals:AddRightGroupbox("Colors")

--// ESP Options
local Options = {
    { "Box", "ShowBox" },
    { "Name", "ShowName" },
    { "Held Item", "ShowHeld" },
    { "Tracer", "ShowTracer" },
    { "Health", "ShowHealth" },
    { "Distance", "ShowDistance" },
    { "Chams", "ShowChams" },
    { "Health Bar", "ShowHealthBar" },
    { "Team Color", "TeamColor" },
    { "Skeleton", "ShowSkeleton" },
    { "3D Box", "Show3DBox" },
    { "Performance Mode", "PerformanceMode" },
}

local OptionNames = {}

for _, Option in ipairs(Options) do
    table.insert(OptionNames, Option[1])
end

--// Safe ESP calls
local function ESPCall(callback)
    local Success, Error = pcall(callback)

    if not Success then
        warn("[v0xt ESP] " .. tostring(Error))
    end
end

--// ESP Dropdown
PlayerSection:AddDropdown("ESPSettings", {
    Text = "ESP Settings",
    Values = OptionNames,
    Default = {},
    Multi = true,
    Searchable = false,

    Callback = function(Selected)
        Selected = Selected or {}

        for _, Option in ipairs(Options) do
            local Enabled = Selected[Option[1]] == true

            ESPCall(function()
                esp:SetProperty(Option[2], Enabled)
            end)
        end
    end,
})

--// Enable ESP
PlayerSection:AddToggle("ESPEnabled", {
    Text = "Enable",
    Default = false,

    Callback = function(Value)
        ESPCall(function()
            if Value then
                esp:Enable()
            else
                esp:Disable()
            end
        end)
    end,
})

--// Distance
local function SnapDistance(Value)
    return math.clamp(
        math.floor(Value / 10 + 0.5) * 10,
        1,
        2000
    )
end

PlayerSection:AddSlider("ESPDistance", {
    Text = "ESP Distance",
    Min = 1,
    Max = 2000,
    Default = 1000,
    Rounding = 0,

    FormatDisplayValue = function(_, Value)
        return tostring(SnapDistance(Value)) .. " studs"
    end,

    Callback = function(Value)
        ESPCall(function()
            esp:SetProperty("MaxDist", SnapDistance(Value))
        end)
    end,
})

--// Colors
local Colors = {
    { "Box", "BoxColor" },
    { "Name", "NameColor" },
    { "Tracer", "TracerColor" },
    { "Chams", "ChamsColor" },
    { "Skeleton", "SkeletonColor" },
    { "3D Box", "Box3DColor" },
    { "Health Text", "HealthTextColor" },
    { "Health Bar", "HealthBarColorOverride" },
}

for _, Entry in ipairs(Colors) do
    local Name = Entry[1]
    local Property = Entry[2]

    local DefaultColor = esp[Property]

    if typeof(DefaultColor) ~= "Color3" then
        DefaultColor = Color3.fromRGB(255, 255, 255)
    end

    ColorsSection:AddLabel(Name):AddColorPicker(
        "ESPColor_" .. Property,
        {
            Default = DefaultColor,
            Title = Name,

            Callback = function(Value)
                ESPCall(function()
                    esp:SetProperty(Property, Value)
                end)
            end,
        }
    )
end

--// Default Distance
ESPCall(function()
    esp:SetProperty("MaxDist", 1000)
end)

--// Unload
Library:OnUnload(function()
    ESPCall(function()
        esp:Disable()
    end)
end)
