local modem = peripheral.find("modem", function(name, modem)
  return modem.isWireless()
end) or error("No wireless modem attached")

if not pocket then
  error("Not on pocket computer")
end

local pretty = require "cc.pretty"
local port = tonumber(arg[1])
if (port == nil) then error("No port supplied") end

local width, height = term.getSize()

function writeText(x, y, text)
  term.setCursorPos(x, y)
  local len = #text
  term.blit(text, string.rep("0", len), string.rep("2", len))   
end

local cols = {
  ["bg"] = colors.purple,
  ["text"] = colors.white,
  ["textBg"] = colors.magenta
}

function storeThirdRow()
  modem.transmit(port, 0, "storeThirdRow")
end

function listItems()
  modem.open(port)
  modem.transmit(port, port, "listItems")
  local message = { os.pullEvent("modem_message") }
  local payload = message[5]

  local outputString = ""
  for name, count in pairs(payload) do
    local length = width - #name - 3
    outputString = outputString .. name .. string.rep(" ", length) .. count .. "\n"
  end

  term.clear()
  term.setCursorPos(1,2)
  textutils.pagedPrint(outputString, 0)
  drawMenus()
end

function sortAllChests()
  modem.open(port)
  modem.transmit(port, 0, "sortAllChests")

  term.clear()
  writeText(1, 1, "Sorting. Please wait...")
  local message = { os.pullEvent("modem_message") }
  local payload = message[5]
  drawMenus()
end

local options = {
  {
    ["x"] = 1,
    ["y"] = 1,
    ["text"] = "Store Third Row",
    ["callback"] = storeThirdRow
  },
  {
    ["x"] = 1,
    ["y"] = 3,
    ["text"] = "List Items",
    ["callback"] = listItems
  },
  {
    ["x"] = 1,
    ["y"] = 5,
    ["text"] = "Sort All Chests",
    ["callback"] = sortAllChests
  }
}


function setupScreenVars()
  term.setBackgroundColour(cols.bg)
  term.setTextColour(cols.text)
end

function drawMenus()
  term.clear()
  local x, y = 2, 2
  term.setCursorPos(x, y)

  local n = table.getn(options)
  for i = 1, n, 1 do
    local option = options[i]
    writeText(option.x, option.y, option.text)
  end
end

function handleMouseClick()
  local mouse = { os.pullEvent("mouse_click") }
  local n = table.getn(options)
  for i = 1, n, 1 do
    local option = options[i]
    if (mouse[4] == option.y) then
      if mouse[3] >= option.x and mouse[3] < option.x + #option.text then
        option.callback()
      end
    end
  end
end

setupScreenVars()
drawMenus()
while true do
  handleMouseClick()
end