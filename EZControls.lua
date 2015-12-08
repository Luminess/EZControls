-- ezcontrols.lua - v0.1.0
-- © 2015 Howard Nguyen
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--------------------------------------------------------------------------------------------------
-- Main Object
--------------------------------------------------------------------------------------------------

local controls = {
  _VERSION = '0.1.0',
  _DESCRIPTION = 'Callback style controls library for Lua.',
  _URL = 'https://github.com/Luminess/EZControls',

  states = {},
  keyObjects = {},
  state = nil
}

--------------------------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------------------------

local rootDir = (...):match("(.-)[^%/]+$")

local dkjson --= require(rootDir .. 'lib.dkjson.dkjson') We're lazy loading but leaving a comment just to show our intent. We lazy load to make dkjson an option dependency.
local inspect = require('inspect')

local type = type
local setmetatable = setmetatable
local pairs = pairs
local table = {
  insert = table.insert
}
local error = error
local love = love

--------------------------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------------------------

local tableContains = function(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

local tableConcat = function(t1, t2)
  for i=1,#t2 do
      t1[#t1+1] = t2[i]
  end
  return t1
end

local stripTableByKeyName
stripTableByKeyName = function(table, keyName)
  for k, v in pairs(table) do
    if k == keyName then
      table.remove(table, k)
    elseif type(v) == 'table' then
      stripTableByKeyName(v, keyName)
    end
  end
end

--------------------------------------------------------------------------------------------------
-- Binding Object
--------------------------------------------------------------------------------------------------

local binding = {--[[
  keys = {},
  onPressCallbacks = {},
  onReleaseCallbacks = {}
]]}
binding.__index = binding

function binding:onPress(function_callback, listenToRepeat)
  table.insert(self.onPressCallbacks, {
    func = function_callback,
    listenToRepeat = listenToRepeat or false
  })
end

function binding:onRelease(function_callback)
  table.insert(self.onReleaseCallbacks, function_callback)
end

function binding:bind(key)
  if type(key) == 'table' then
    tableConcat(self.keys, key)
  else
    table.insert(self.keys, key)
  end
end

function binding:unbind(key)
  if type(key) == 'table' then
    for i = 1, #self.keys do
      if self.keys[i] == key then
        table.remove(self.keys, key)
      end
    end
  else
    table.remove(self.keys, key)
  end
end

--------------------------------------------------------------------------------------------------
-- Private Methods
--------------------------------------------------------------------------------------------------

local function createBinding(stateName, bindingName)
   local newBinding = setmetatable({
    keys = {},
    onPressCallbacks = {},
    onReleaseCallbacks = {}
  }, binding)

  if not controls.states[stateName] then
    controls.states[stateName] = {}
  end
  controls.states[stateName][bindingName] = newBinding

  return newBinding
end

local function bindingExists(stateName, bindingName)
  return (type(controls.states[stateName][bindingName]) == 'table')
end

local function returnBindingOrNew(stateName, bindingName)
  local workingBinding, isNew = nil, false
  if controls[stateName] and bindingExists(bindingName) then
    workingBinding = controls.states[stateName][bindingName]
  else
    workingBinding = createBinding(stateName, bindingName)
    isNew = true
  end
  return workingBinding, isNew
end

--------------------------------------------------------------------------------------------------
-- Public Methods
--------------------------------------------------------------------------------------------------

function controls.bind(keys, stateName, bindingName)
  local workingBinding = returnBindingOrNew(stateName, bindingName)
  workingBinding:bind(keys)
  return workingBinding
end

function controls.state(stateName)
  local function getBinding(bindingName)
    return (returnBindingOrNew(stateName, bindingName))
  end
  local function bind(keys, bindingName)
    return controls.bind(keys, stateName, bindingName)
  end
  return { binding = getBinding, bind = bind }
end

function controls.parse(table)
 -- TODO
end

function controls.load(loadPath)
  if not dkjson then
    dkjson = require(rootDir .. 'lib.dkjson.dkjson')
  end

  controls.states = dkjson.decode(io.open(loadPath):read('*all'))
end

function controls.save(savePath)
  if not dkjson then
    dkjson = require(rootDir .. 'lib.dkjson.dkjson')
  end

  local states = stripTableByKeyName(controls.states, {'onPressCallbacks', 'onReleaseCallbacks'})

  for state, v in pairs(states) do
    for binding, v in pairs(v) do
      -- TODO
    end
  end

  io.open(savePath, 'w+'):write(dkjson.encode(states, { exceptions = function() return true end}))
end

--------------------------------------------------------------------------------------------------
-- Mouse Object
--------------------------------------------------------------------------------------------------
local mouse = {}

mouse.physics = {
  onMoveCallbacks = {}
}

function mouse.physics:onMove(function_callback)
  table.insert(self.onMoveCallbacks, function_callback)
end

-- Simple syntactical sugar.
mouse.leftButton = controls.bind('mouse_l', 'all', 'mouse_l')
mouse.middleButton = controls.bind('mouse_m', 'all', 'mouse_m')
mouse.rightButton = controls.bind('mouse_r', 'all', 'mouse_r')
mouse.mouseWheel = {}
mouse.mouseWheel.up = controls.bind('mouse_wu', 'all', 'mouse_wu')
mouse.mouseWheel.down = controls.bind('mouse_wd', 'all', 'mouse_wd')

controls.mouse = mouse

--------------------------------------------------------------------------------------------------
-- Love2D Callbacks Handlers
--------------------------------------------------------------------------------------------------

love.keyboard.setKeyRepeat(true)

function love.keypressed(key, isRepeat, x, y)
  for state, bindings in pairs(controls.states) do
    if state == controls.state or state == 'all' then
      for _, bindingProps in pairs(bindings) do
        if tableContains(bindingProps.keys, key) then
          for _, callback in pairs(bindingProps.onPressCallbacks) do
            if not (callback.listenToRepeat or isRepeat) then
              callback.func(x, y)
            end
          end
        end
      end
    end
  end
end

function love.keyreleased(key, x, y)
  for state, bindings in pairs(controls.states) do
    if state == controls.state or state == 'all' then
      for _, bindingProps in pairs(bindings) do
        if tableContains(bindingProps.keys, key) then
          for i = 1, #bindingProps.onReleaseCallbacks do
            bindingProps.onReleaseCallbacks[i](x, y)
          end
        end
      end
    end
  end
end

function love.mousepressed(x, y, button)
  love.keypressed('mouse_' .. button, false, x, y)
end

function love.mousereleased(x, y, button)
  love.keyreleased('mouse_' .. button, x, y)
end

function love.mousemoved(x, y, deltaX, deltaY) -- TODO: Maybe implement state awareness.
  for _, callback in pairs(mouse.physics.onMoveCallbacks) do
    callback(x, y, deltaX, deltaY)
  end
end

return controls
