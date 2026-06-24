--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
getgenv().Running = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Loader = require(ReplicatedStorage.Packages.Loader)
local ReplicaController = require(Loader.Shared.Utility.ReplicaController)
local BooksData = require(Loader.Shared.Data.Books)

local LibraryReplica = nil
for _, r in pairs(ReplicaController._replicas) do
    if r.Class == "Library" then LibraryReplica = r break end
end
if not LibraryReplica then
    ReplicaController.ReplicaOfClassCreated("Library", function(replica) LibraryReplica = replica end)
    while not LibraryReplica do task.wait() end
end

local Library = Workspace.Library
local BooksFolder = Library.Books
local player = Players.LocalPlayer

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 20
task.spawn(function() task.wait(0.1) player.CameraMinZoomDistance = 0.5 end)

local shelfModels = {}
for _, shelfModel in ipairs(CollectionService:GetTagged("Shelf")) do
    shelfModels[shelfModel.Name] = shelfModel
end

local function getShelfAssignedSeries(shelfId)
    local shelfData = LibraryReplica.Data.Shelves[shelfId]
    if not shelfData then return nil end
    for _, placedBook in pairs(shelfData.Books) do
        local bookName = typeof(placedBook) == "Instance" and placedBook.Name or placedBook
        local seriesName = bookName:match("^(.-)_(.+)$")
        if seriesName then return seriesName end
    end
end

local function findShelfForSeries(seriesName, genreName, volumeCount)
    for shelfId, shelfData in pairs(LibraryReplica.Data.Shelves) do
        if not shelfData.Completed and shelfData.Category == genreName then
            local shelfModel = shelfModels[shelfId]
            if shelfModel and shelfModel:GetAttribute("Width") == volumeCount then
                if getShelfAssignedSeries(shelfId) == seriesName then return shelfModel end
            end
        end
    end
    for shelfId, shelfData in pairs(LibraryReplica.Data.Shelves) do
        if not shelfData.Completed and shelfData.Category == genreName then
            local shelfModel = shelfModels[shelfId]
            if shelfModel and shelfModel:GetAttribute("Width") == volumeCount then
                if not getShelfAssignedSeries(shelfId) and next(shelfData.Books) == nil then return shelfModel end
            end
        end
    end
end

local function teleportTo(obj)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
    if root and part then
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
        task.wait(0.05)
    end
end

task.spawn(function()
    for _, book in ipairs(BooksFolder:GetChildren()) do
        if not getgenv().Running then break end
        task.wait(0.02)
        
        local seriesName, volumeStr = book.Name:match("^(.-)_(.+)$")
        local volumeNum = tonumber(volumeStr)
        if seriesName and volumeNum then
            local genreName, bookInfo = BooksData.GetCategory(seriesName)
            if genreName and bookInfo then
                local shelfModel = findShelfForSeries(seriesName, genreName, bookInfo.VolumeCount)
                if shelfModel then
                    local shelfData = LibraryReplica.Data.Shelves[shelfModel.Name]
                    if not (shelfData and shelfData.Books[tostring(volumeNum)]) then
                        teleportTo(book)
                        LibraryReplica:FireServer("Grab", book)
                        task.wait(0.1)
                        teleportTo(shelfModel)
                        LibraryReplica:FireServer("Place", shelfModel, volumeNum - 1)
                        task.wait(0.4)
                    end
                end
            end
        end
    end
    getgenv().Running = false
end)
