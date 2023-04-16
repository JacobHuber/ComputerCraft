local modem = peripheral.find("modem", function(name, modem)
  return modem.isWireless()
end) or error("No wireless modem attached")

if not pocket then
  error("Not on pocket computer")
end

local port = tonumber(arg[1])
if (port == nil) then error("No port supplied") end

local width, height = term.getSize()

local cols = {
  ["bg"] = colors.purple,
  ["text"] = colors.white,
  ["textBg"] = colors.magenta
}

function storeThirdRow()

end

function listItems()

end

local options = {
  {
    ["text"] = "Store Third Row",
    ["callback"] = storeThirdRow
  },
  {
    ["text"] = "List Items",
    ["callback"] = listItems
  }
}


function setupScreenVars()
  term.setBackgroundColour(cols["bg"])
  term.setTextColour(cols["text"])
end

function drawScreen()
  term.clear()
  local x, y = { 2, 2 }
  term.setCursorPos(x, y)

  local n = table.getn(options)
  for i = 1, n, 1 do
    local text = options[i]["text"]
    local len = #text
    term.blit(text, string.rep("0", len), string.rep("2", len))
    y = y + 2
    term.setCursorPos(x, y)
  end
end

setupScreenVars()
while true do
  drawScreen()
end