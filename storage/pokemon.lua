local Pokemon = {}

local Bridge = require "util.bridge"
local Input = require "util.input"
local Memory = require "util.memory"
local Menu = require "util.menu"

local yellow = YELLOW

local pokeIDs = {
	rhydon = 1,
	kangaskhan = 2,
	nidoran = 3,
	spearow = 5,
	voltorb = 6,
	nidoking = 7,
	ivysaur = 9,
	gengar = 14,
	nidoranf = 15,
	nidoqueen = 16,
	cubone = 17,
	rhyhorn = 18,
	gyarados = 22,
	growlithe = 33,
	onix = 34,
	pidgey = 36,
	kadabra = 38,
	jinx = 72,
	meowth = 77,
	pikachu = 84,
	dragonair = 89,
	sandshrew = 96,
	zubat = 107,
	ekans = 108,
	paras = 109,
	weedle = 112,
	kakuna = 113,
	dewgong = 120,
	caterpie = 123,
	metapod = 124,
	hypno = 129,
	weezing = 143,
	alakazam = 149,
	pidgeotto = 150,
	pidgeot = 151,
	rattata = 165,
	raticate = 166,
	nidorino = 167,
	geodude = 169,
	charmander = 176,
	squirtle = 177,
	oddish = 185,
}

local moveList = {
	cut = 15,
	fly = 19,
	sand_attack = 28,
	horn_attack = 30,
	horn_drill = 32,
	tackle = 33,
	thrash = 37,
	tail_whip = 39,
	poison_sting = 40,
	leer = 43,
	growl = 45,
	water_gun = 55,
	surf = 57,
	ice_beam = 58,
	bubblebeam = 61,
	strength = 70,
	thunderbolt = 85,
	earthquake = 89,
	dig = 91,
	rock_slide = 157,
}

local data = {
	hp = {1, true},
	status = {4},
	moves = {8},
	pp = {28},
	level = {33},
	max_hp = {34, true},

	attack = {36, true},
	defense = {38, true},
	speed = {40, true},
	special = {42, true},
}

local previousPartySize

local function getAddress(index)
	return 0x116B + index * 0x2C
end

local function index(index, offset)
	local double
	if not offset then
		offset = 0
	else
		local dataTable = data[offset]
		offset = dataTable[1]
		double = dataTable[2]
	end
	local address = getAddress(index) + offset
	local value = Memory.raw(address)
	if double then
		value = value + Memory.raw(address + 1)
	end
	return value
end
Pokemon.index = index

local function indexOf(...)
	for ni,name in ipairs(arg) do
		local pid = pokeIDs[name]
		for i=0,5 do
			local atIdx = index(i)
			if atIdx == pid then
				return i
			end
		end
	end
	return -1
end
Pokemon.indexOf = indexOf

local function fieldMoveIndex(move)
	local moveIndex = 0
	local menuSize = Memory.value("menu", "size")
	if yellow then
		if move == "cut" then
			moveIndex = 1
		end
	else
		if menuSize == 4 then
			if move == "dig" then
				moveIndex = 1
			elseif move == "surf" then
				if Pokemon.inParty("paras") then
					moveIndex = 1
				end
			end
		elseif menuSize == 5 then
			if move == "dig" then
				moveIndex = 2
			elseif move == "surf" then
				moveIndex = 1
			end
		end
	end
	return moveIndex
end

-- Table functions

function Pokemon.battleMove(name)
	local mid = moveList[name]
	for i=1,4 do
		if mid == Memory.raw(0x101B + i) then
			return i
		end
	end
end

function Pokemon.moveIndex(move, pokemon)
	local pokemonIdx
	if pokemon then
		pokemonIdx = indexOf(pokemon)
	else
		pokemonIdx = 0
	end
	local address = getAddress(pokemonIdx) + 7
	local mid = moveList[move]
	for i=1,4 do
		if mid == Memory.raw(address + i) then
			return i
		end
	end
end

function Pokemon.info(name, offset)
	return index(indexOf(name), offset)
end

function Pokemon.getID(name)
	return pokeIDs[name]
end

function Pokemon.getName(id)
	for name,pid in pairs(pokeIDs) do
		if pid == id then
			return name
		end
	end
end

function Pokemon.getSacrifice(...)
	for i,name in ipairs(arg) do
		local pokemonIndex = indexOf(name)
		if pokemonIndex ~= -1 and index(pokemonIndex, "hp") > 0 then
			return name
		end
	end
end

function Pokemon.inParty(...)
	for i,name in ipairs(arg) do
		if indexOf(name) ~= -1 then
			return name
		end
	end
end

function Pokemon.forMove(move)
	local moveID = moveList[move]
	for i=0,5 do
		local address = getAddress(i)
		for j=8,11 do
			if Memory.raw(address + j) == moveID then
				return i
			end
		end
	end
	return -1
end

function Pokemon.hasMove(move)
	return Pokemon.forMove(move) ~= -1
end

function Pokemon.updateParty()
	local partySize = Memory.value("player", "party_size")
	if partySize ~= previousPartySize then
		local poke = Pokemon.inParty("oddish", "paras", "spearow", "pidgey", "nidoran", "squirtle")
		if poke then
			Bridge.caught(poke)
			previousPartySize = partySize
		end
	end
end

function Pokemon.pp(index, move)
	local midx = Pokemon.battleMove(move)
	return Memory.raw(getAddress(index) + 28 + midx)
end

-- General

function Pokemon.isOpponent(...)
	local oid = Memory.value("battle", "opponent_id")
	for i,name in ipairs(arg) do
		if oid == pokeIDs[name] then
			return name
		end
	end
end

function Pokemon.isDeployed(...)
	local deployedID = Memory.value("battle", "our_id")
	for i,name in ipairs(arg) do
		if deployedID == pokeIDs[name] then
			return name
		end
	end
end

function Pokemon.isEvolving()
	return Memory.value("menu", "pokemon") == 144
end

function Pokemon.getExp()
	return Memory.raw(0x117A) * 256 + Memory.raw(0x117B)
end

function Pokemon.inRedBar()
	local curr_hp, max_hp = index(0, "hp"), index(0, "max_hp")
	return curr_hp / max_hp <= 0.2
end

function Pokemon.use(move)
	local main = Memory.value("menu", "main")
	local pokeName = Pokemon.forMove(move)
	if main == 141 then
		Input.press("A")
	elseif main == 128 then
		local column = Menu.getCol()
		if column == 11 then
			Menu.select(1, true)
		elseif column == 10 or column == 12 then
			Menu.select(fieldMoveIndex(move), true)
		else
			Input.press("B")
		end
	elseif main == Menu.pokemon then
		Menu.select(pokeName, true)
	elseif main == 228 then
		Input.press("B")
	else
		return false
	end
	return true
end

function Pokemon.getDVs(name)
	local index = Pokemon.indexOf(name)
	local baseAddress = getAddress(index)
	local attackDefense = Memory.raw(baseAddress + 0x1B)
	local speedSpecial = Memory.raw(baseAddress + 0x1C)
	return bit.rshift(attackDefense, 4), bit.band(attackDefense, 15), bit.rshift(speedSpecial, 4), bit.band(speedSpecial, 15)
end

return Pokemon
