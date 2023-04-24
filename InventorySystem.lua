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

function swapItems(fromChestI, toChestI, fromSlot, toSlot)
  local fromChest = remoteChests[fromChestI]
  local toChest = remoteChests[toChestI]
  local fromName = peripheral.getName(fromChest)
  local toName = peripheral.getName(toChest)
  
  invChest.pullItems(toName, toSlot, 999, 1) -- move from toChest to invChest
  toChest.pullItems(fromName, fromSlot, 999, toSlot) -- move from fromChest to toChest
  invChest.pushItems(fromName, 1, 999, fromSlot) -- move from invChest to fromChest
end

function sortAllChests()
  local allItems = {}
  local sortedItems = {}

  for i = 1, chestN, 1 do
    local chest = remoteChests[i]
    local chestItems = chest.list()

    allItems[i] = {}

    for slot, item in pairs(chestItems) do
      item.slot = slot
      item.chest = i
      allItems[i][slot] = item
      table.insert(sortedItems, item)
    end
  end

  table.sort(sortedItems, function(itemA, itemB) return itemA.name < itemB.name end)

  local prevItem = nil
  local indexCount = 1
  for sortedIndex, item in pairs(sortedItems) do
    local fromChest = item.chest
    local fromSlot = item.slot
    local toChest = math.floor((indexCount - 1) / 54) + 1
    local toSlot = ((indexCount - 1) % 54) + 1

    local shouldSkip = false
    if (prevItem ~= nil) then
      if (prevItem.name == item.name) then
        local count = prevItem.count
        local limit = remoteChests[prevItem.chest].getItemLimit(prevItem.slot)

        if (count < limit) then
          local remaining = limit - count
          remoteChests[prevItem.chest].pullItems(peripheral.getName(remoteChests[fromChest]), fromSlot, remaining, prevItem.slot)
          
          if (remaining >= item.count) then
            allItems[fromChest][fromSlot] = nil
            prevItem.count = prevItem.count + item.count
            shouldSkip = true
          else
            item.count = item.count - remaining
            prevItem.count = limit
          end
        end
      end
    end

    if (not shouldSkip) then
      local swappedItem = allItems[toChest][toSlot]

      if (swappedItem == nil) then
        remoteChests[toChest].pullItems(peripheral.getName(remoteChests[fromChest]), fromSlot, 999, toSlot)
        allItems[fromChest][fromSlot] = nil
        allItems[toChest][toSlot] = item
      else
        swapItems(fromChest, toChest, fromSlot, toSlot)
        allItems[fromChest][fromSlot] = swappedItem
        allItems[toChest][toSlot] = item
        swappedItem.chest = fromChest
        swappedItem.slot = fromSlot
      end
      
      item.chest = toChest
      item.slot = toSlot

      prevItem = item
      indexCount = indexCount + 1
    end
  end

  enderModem.transmit(port, port, "Done")
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