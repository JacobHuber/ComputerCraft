local monitor = peripheral.find("monitor") or error("No monitor attached")
monitor.setBackgroundColour(colors.white)
monitor.clear()
monitor.setCursorPos(1,1)
monitor.setTextScale(0.5)

local width, height = monitor.getSize()

function writeToDisplay(text, col)
  local len = #text
  local x, y = monitor.getCursorPos()
  if (x + len > width) then
    monitor.setCursorPos(1, y + 1)
  end
  if (y > height) then
    monitor.setCursorPos(1, y - 1)
    monitor.scroll(1)
  end

  monitor.setTextColour(col)
  monitor.write(text)
end

function capitalizeFirst(word)
  local first = string.upper(string.sub(word, 1, 1))
  return first .. string.sub(word, 2)
end

function formatItemName(name)
  local prefixI = string.find(name, ":")
  local snakeCaseName = string.sub(name, prefixI + 1, -1)
  local name = ""
  
  while (snakeCaseName ~= "") do
    local i = string.find(snakeCaseName, "_")
    if (i == nil) then i = string.len(snakeCaseName) + 1 end
    local part = capitalizeFirst(string.sub(snakeCaseName, 0, i - 1))
    snakeCaseName = string.sub(snakeCaseName, i + 1)
    name = name .. part
  end

  return name
end

local enderModem = peripheral.find("modem", function(name, modem)
  return modem.isWireless()
end) or error("No Ender modem")

local wiredModem = peripheral.find("modem", function(name, modem)
  return not modem.isWireless()
end) or error("No wired modem")

-- Error Checking
local inv = peripheral.find("inventoryManager") or error("No Inventory Manager attached")
if (inv.getOwner() == nil) then
  error("No owner for Inventory Manager")
end

function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local remoteChests = { peripheral.find("minecraft:chest", function(name, chest)
  return chest.size() == 54
end) }
local invChest = peripheral.find("minecraft:chest", function(name, chest) 
  return chest.size() == 27
end)
local chestN = table.getn(remoteChests)

if (chestN == 0) then
  error("No remote chests attached")
end

if (invChest == nil) then
  error("No inv chest attached")
end

local pretty = require "cc.pretty"
writeToDisplay("Found " .. chestN .. " remote chest(s)", colors.black)

local port = tonumber(arg[1])
if (port == nil) then error("No port specified") end

enderModem.open(port)

function getEmptyChest()
  for i = 1, chestN, 1 do
    local chest = remoteChests[i]
    local usedSlots = tableLength(chest.list())
    local totalSlots = chest.size()

    if (usedSlots < totalSlots) then
      return peripheral.getName(chest)
    end
  end
  
  return ""
end

function transferItemToStorage(item)
  inv.removeItemFromPlayerNBT("right", item.count, 0, {name=item.name, fromSlot=item.slot, toSlot=0})
  local toChest = getEmptyChest()
  if (toChest ~= "") then
    invChest.pushItems(toChest, 1)
  else
    writeToDisplay("No storage space!", colors.black)
  end
end

function storeThirdRow()
  local items = inv.getItems()
  local n = table.getn(items)
  for i = 1, n, 1 do
    local item = items[i]
    if (item.slot >= 27 and item.slot <= 35) then
      transferItemToStorage(item)
    end
  end
end

function getAllItems()
  local allItems = {}
  for i = 1, chestN, 1 do
    local chest = remoteChests[i]
    local chestItems = chest.list()
    for slot, item in pairs(chestItems) do
      local name = formatItemName(item.name)
      if (allItems[name] == nil) then
        allItems[name] = {}
        allItems[name] = item.count
      else
        allItems[name] = allItems[name] + item.count
      end
    end
  end

  return allItems
end

function swapItems(chest, slot1, slot2)
  local name = peripheral.getName(chest)
  invChest.pullItems(name, slot1, 999, 1)
  chest.pushItems(name, slot2, 999, slot1)
  invChest.pushItems(name, 1, 999, slot2)
end

function sortAllChests()
  for i = 1, chestN, 1 do
    local allItems = {}
    local sortedItems = {}
    local chest = remoteChests[i]
    local chestItems = chest.list()
    for slot, item in pairs(chestItems) do
      item.slot = slot
      allItems[slot] = item
      table.insert(sortedItems, item)
    end

    table.sort(sortedItems, function(itemA, itemB) return itemA.name > itemB.name end)

    for toSlot, item in pairs(sortedItems) do
      local swappedItem = allItems[toSlot]
      local fromSlot = item.slot
      if (swappedItem == nil) then
        chest.pushItems(peripheral.getName(chest), fromSlot, 999, toSlot)
        allItems[toSlot] = item
        allItems[fromSlot] = nil
      else
        swapItems(chest, toSlot, fromSlot)
        allItems[fromSlot] = swappedItem
        allItems[toSlot] = item
        swappedItem.slot = fromSlot
      end
      
      item.slot = toSlot
    end
  end
end

function listItems(search)
  if (search == nil) then search = "" end
  local allItems = getAllItems()

  monitor.clear()
  monitor.setCursorPos(1,1)

  local sortedItems = {}

  for name, count in pairs(allItems) do
    if (string.find(string.lower(name), string.lower(search)) ~= nil) then 
      sortedItems[name] = count
    end
  end

  enderModem.transmit(port, port, sortedItems)
end

local allFunctions = {
  ["storeThirdRow"] = storeThirdRow,
  ["listItems"] = listItems,
  ["sortAllChests"] = sortAllChests
}

-- Modem exists, and is wireless!
-- Do main loop
while true do
  local msg = { os.pullEvent("modem_message") }
  local i = string.find(msg[5], " ")
  local command
  local arg
  if (i == nil) then
    allFunctions[msg[5]]()
  else
    local command = string.sub(msg[5], 1, i - 1)
    local arg = string.sub(msg[5], i + 1, -1)
    allFunctions[command](arg)
  end
end