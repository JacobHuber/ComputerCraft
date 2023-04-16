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

  local displayTable = {}
  for name, count in pairs(payload) do
    table.insert(displayTable, {name, count})
  end

  textutils.pagedTabulate(colors.orange, {"Name", "Count"}, colors.blue, table.unpack(displayTable))
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
    term.setCursorPos(option.x, option.y)
    local text = option.text
    local len = #text
    term.blit(text, string.rep("0", len), string.rep("2", len))   
  end
end

function handleMouseClick()
  local mouse = { os.pullEvent("mouse_click") }
  local n = table.getn(options)
  for i = 1, n, 1 do
    local option = options[i]
    if (mouse[3] == option.y) then
      if mouse[4] >= option.x and mouse[4] < option.x + #option.text then
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