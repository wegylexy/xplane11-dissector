xp11 = Proto("xp11","X-Plane 11")
xp11.fields.prolog = ProtoField.string("xp11.prolog", "Prolog")

xp11_becn = Proto("xp11.becn", "X-Plane 11 Beacon")
xp11_becn.fields.major = ProtoField.uint8("xp11.becn.major", "Beacon Major Version")
xp11_becn.fields.minor = ProtoField.uint8("xp11.becn.minor", "Beacon Minor Version")
xp11_becn.fields.appid = ProtoField.int32("xp11.becn.appid", "Applciation Host ID")
xp11_becn.fields.version = ProtoField.int32("xp11.becn.version", "Version Number")
xp11_becn.fields.role = ProtoField.uint32("xp11.becn.role", "Role")
xp11_becn.fields.port = ProtoField.uint16("xp11.becn.port", "Port")
xp11_becn.fields.name = ProtoField.stringz("xp11.becn.name", "Computer Name")

xp11_rpos = Proto("xp11.rpos", "X-Plane 11 Position Report")
xp11_rpos.fields.lon = ProtoField.double("xp11.rpos.lon", "Longitude")
xp11_rpos.fields.lat = ProtoField.double("xp11.rpos.lat", "Latitude")
xp11_rpos.fields.ele = ProtoField.double("xp11.rpos.ele", "Altitude")
xp11_rpos.fields.agl = ProtoField.float("xp11.rpos.agl", "Height")
xp11_rpos.fields.the = ProtoField.float("xp11.rpos.the", "Pitch")
xp11_rpos.fields.psi = ProtoField.float("xp11.rpos.psi", "True Heading")
xp11_rpos.fields.phi = ProtoField.float("xp11.rpos.phi", "Roll")
xp11_rpos.fields.vx = ProtoField.float("xp11.rpos.vx", "Eastern Velocity")
xp11_rpos.fields.vy = ProtoField.float("xp11.rpos.vy", "Vertical Velocity")
xp11_rpos.fields.vz = ProtoField.float("xp11.rpos.vz", "Southern Velocity")
xp11_rpos.fields.p = ProtoField.float("xp11.rpos.p", "Roll Rate")
xp11_rpos.fields.q = ProtoField.float("xp11.rpos.q", "Pitch Rate")
xp11_rpos.fields.r = ProtoField.float("xp11.rpos.r", "Yaw Rate")

xp11_radr = Proto("xp11.radr", "X-Plane 11 Weather Radar Data Points")
xp11_radr.fields.lon = ProtoField.float("xp11.radr.lon", "Longitude")
xp11_radr.fields.lat = ProtoField.float("xp11.radr.lat", "Latitude")
xp11_radr.fields.level = ProtoField.uint8("xp11.radr.level", "Precipitation")
xp11_radr.fields.height = ProtoField.float("xp11.radr.height", "Storm Top")

xp11_rref = Proto("xp11.rref", "X-Plane 11 Received Reference")
xp11_rref.fields.en = ProtoField.float("xp11.rref.en", "Echo Number")
xp11_rref.fields.flt = ProtoField.float("xp11.rref.flt", "Float Value")

local function truncate(value)
	return value < 0 and math.ceil(value) or math.floor(value)
end

local function degreeMinute(degree)
	local m = math.abs(degree) % 1 * 60
	return truncate(degree) .. "\xc2\xb0" .. (m < 10 and "0" or "") .. m .. "'"
end

local function degreeMinuteSecond(degree)
	local m = math.abs(degree) % 1 * 60
	local s = m % 1 * 60
	return truncate(degree) .. "\xc2\xb0" .. (m < 10 and "0" or "") .. truncate(m) .. "'" .. (s < 10 and "0" or "") .. s .. '"'
end

local function longitude(degree)
	return (degree < 0 and "W" or "E") .. degreeMinute(math.abs(degree))
end

local function latitude(degree)
	return (degree < 0 and "S" or "N") .. degreeMinute(math.abs(degree))
end

local function knot(mps)
	return mps * 900 / 463
end

local subdissectors = {
	BECN =
		function (buffer, pinfo, tree)
			local bl = buffer:len();
			local appid = buffer(2, 4):le_int();
			local apps = {
				[1] = "X-Plane",
				[2] = "Plane Maker"
			}
			local version = buffer(6, 4):le_int();
			local role = buffer(10, 4):le_int();
			local roles = {
				[1] = "Master",
				[2] = "External Visual",
				[3] = "IOS"
			}
			local subtree = tree:add(xp11_becn, buffer(0, math.min(bl, 516)), "X-System Beacon Version",
				buffer(0, 1):uint() .. "." .. buffer(1, 1):uint())
			subtree:add_le(xp11_becn.fields.major, buffer(0, 1))
			subtree:add_le(xp11_becn.fields.minor, buffer(1, 1))
			subtree:add_le(xp11_becn.fields.appid, buffer(2, 4)):set_text("Application Host: " .. apps[appid])
			subtree:add_le(xp11_becn.fields.version, buffer(6, 4)):
				set_text("Version: " .. string.format("%d.%02dr%d", version / 10000, version / 100 % 100, version % 100))
			subtree:add_le(xp11_becn.fields.role, buffer(10, 4)):set_text("Role: " .. roles[role])
			subtree:add_le(xp11_becn.fields.port, buffer(14, 2))
			subtree:add_le(xp11_becn.fields.name, buffer(16, math.min(bl - 16, 500)))
		end,
	RPOS =
		function (buffer, pinfo, tree)
			local subtree = tree:add(xp11_rpos, buffer(0, 16))
			subtree:add_le(xp11_rpos.fields.lon, buffer(0, 8)):set_text("Longitude: " .. longitude(buffer(0, 8):le_float()))
			subtree:add_le(xp11_rpos.fields.lat, buffer(8, 8)):set_text("Latitude: " .. latitude(buffer(8, 8):le_float()))
			subtree:add_le(xp11_rpos.fields.ele, buffer(16, 8)):set_text("Altitude: " .. buffer(16, 8):le_float() / .3048 .. " ft MSL")
			subtree:add_le(xp11_rpos.fields.agl, buffer(24, 4)):set_text("Height: " .. buffer(24, 4):le_float() / .3048 .. " ft AGL")
			subtree:add_le(xp11_rpos.fields.the, buffer(28, 4)):set_text("Pitch: " .. degreeMinuteSecond(buffer(28, 4):le_float()))
			subtree:add_le(xp11_rpos.fields.psi, buffer(32, 4)):set_text("True Heading: " .. degreeMinuteSecond(buffer(32, 4):le_float()))
			subtree:add_le(xp11_rpos.fields.phi, buffer(36, 4)):set_text("Roll: " .. degreeMinuteSecond(buffer(36, 4):le_float()))
			local vx = buffer(40, 4):le_float()
			local vy = buffer(44, 4):le_float()
			local vz = buffer(48, 4):le_float()
			local vt = subtree:add(buffer(40, 12), "Linear Velocity: " ..
				truncate((450 - math.atan2(-vz, vx) * 180 / math.pi) % 360) .. "\xc2\xb0/" ..
				truncate(knot(math.sqrt(math.pow(vx, 2) + math.pow(vz, 2)))) .. " kt, " ..
				(vy >= 0 and "+" or "") .. truncate(vy / .3048) .. " fpm")
			vt:add_le(xp11_rpos.fields.vx, buffer(40, 4)):set_text("Eastern Velocity: " .. vx .. " m/s")
			vt:add_le(xp11_rpos.fields.vy, buffer(44, 4)):set_text("Vertical Velocity: " .. vy .. " m/s")
			vt:add_le(xp11_rpos.fields.vz, buffer(48, 4)):set_text("Southern Velocity: " .. vz .. " m/s")
			subtree:add_le(xp11_rpos.fields.p, buffer(52, 4)):set_text("Roll Rate: " .. buffer(52, 4):le_float() * 180 / math.pi .. "\xc2\xb0/s")
			subtree:add_le(xp11_rpos.fields.q, buffer(56, 4)):set_text("Pitch Rate: " .. buffer(56, 4):le_float() * 180 / math.pi .. "\xc2\xb0/s")
			subtree:add_le(xp11_rpos.fields.r, buffer(60, 4)):set_text("Yaw Rate: " .. buffer(60, 4):le_float() * 180 / math.pi .. "\xc2\xb0/s")
		end,
	RADR =
		function (buffer, pinfo, tree)
			local subtree = tree:add(xp11_radr, buffer())
			local count = buffer:len() / 13
			subtree:add("[Count: " .. count .. "]")
			for i = 0, count - 1 do
				local b = buffer(13 * i, 13)
				local lon = longitude(b(0, 4):le_float())
				local lat = latitude(b(4, 4):le_float())
				local level = b(8, 1):uint()
				local height = b(9, 4):le_float()
				local st = subtree:add(xp11_radr, b, "[" .. i .. "]", lat, lon, level .. "%", truncate(height / .3048) .. "ft MSL")
				st:add_le(xp11_radr.fields.lon, b(0, 4)):set_text("Longitude: " .. lon)
				st:add_le(xp11_radr.fields.lat, b(4, 4)):set_text("Latitude: " .. lat)
				st:add_le(xp11_radr.fields.level, b(8, 1)):set_text("Precipitation: " .. level .. " %")
				st:add_le(xp11_radr.fields.height, b(9, 4)):set_text("Storm Top: " .. height .. " m MSL")
			end
		end,
	RREF =
		function (buffer, pinfo, tree)
			local subtree = tree:add(xp11_rref, buffer(0, 8))
			subtree:add_le(xp11_rref.fields.en, buffer(0, 4))
			subtree:add_le(xp11_rref.fields.flt, buffer(4, 4))
		end,
}

function xp11.dissector(buffer, pinfo, tree)
	pinfo.cols.protocol = "X-Plane 11"
	local _prolog = buffer(0, 4)
	local prolog = _prolog:string()
	local subtree = tree:add(xp11, buffer(), "X-Plane 11, Prolog:", prolog)
	subtree:add(xp11.fields.prolog, _prolog)
	local db = buffer(5)
	subdissectors[prolog](db, pinfo, tree)
	subtree:add(db, "[Data Length: " .. db:len() .. "]")
end

ut = DissectorTable.get("udp.port")
ut:add(49001, xp11);
