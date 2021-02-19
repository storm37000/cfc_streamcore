E2Lib.RegisterExtension( "streamcore", true )

CreateConVar( "streamcore_antispam_seconds", 5, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_antispam_ignoreadmins", 1, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_adminonly", 0, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_maxradius", 120, FCVAR_SERVER_CAN_EXECUTE )

util.AddNetworkString( "CFC_SC_StreamStart" )
util.AddNetworkString( "CFC_SC_StreamStop" )
util.AddNetworkString( "CFC_SC_StreamVolume" )
util.AddNetworkString( "CFC_SC_StreamRadius" )
util.AddNetworkString( "CFC_SC_StreamHelp" )

local rawget = rawget
local CurTime = CurTime
local clamp = math.Clamp

local stringLen = string.len
local stringSub = string.sub
local stringTrim = string.Trimp

local streams = {}
local antispam = {}
local urlFixes = {}

local throttleConfig = {
    delays = { -- In seconds, minimum delay between uses
        default = 0.1,
        streamRadius = 0.25,
        streamVolume = 0.25,
        streamStop = 0.25
    }
}

local function setLastUse( chip, funcName )
    local ent = chip.entity

    local throttles = ent.streamcoreThrottle
    if not throttles then ent.streamcoreThrottle = {} end

    throttles[funcName] = CurTime()
end

local function isThrottled( chip, funcName )
    local ply = chip.player
    local ent = chip.entity

    if ply:IsAdmin() then return false end

    local throttles = ent.streamcoreThrottle
    if not throttles then
        ent.streamcoreThrottle = {}
    end

    local lastUse = throttles[funcName]
    if not lastUse then throttles[funcName] = 0 end

    local delay = throttleConfig.delays[funcName] or throttleConfig.delays.default
    if CurTime() < lastUse + delay then return true end

    return false
end

local function fixURL( url )
    local cached = rawget( urlFixes, url )
    if cached then return cached end

    local originalUrl = url

    local url = stringTrim( url )
    if stringLen( originalUrl ) < 5 then return end

    if stringSub( url, 1, 4 ) ~= "http" then
        url = "https://" .. url
    end

    urlFixes[originalUrl] = url

    return url
end

local function playerCanStartStream( ply )
    local admin = ply:IsAdmin()
    local only = GetConVarNumber( "streamcore_adminonly" )
    local ignore = GetConVarNumber( "streamcore_antispam_ignoreadmins" )
    local access = ply.SC_Access_Override or false
    local nospam = ply.SC_Antispam_Ignore or false

    if ( only > 0 ) and not ( admin or access ) then return false end

    if ( ignore > 0 ) and ( admin or nospam ) then return true end

    local last = antispam[ply:EntIndex()] or 0
    if last > CurTime() then return false end

    return true
end

local function streamStart( chip, target, id, volume, url, no3d )
    if not IsValid( chip ) then return end
    if not IsValid( target ) then return end

    if isThrottled( self, "streamStart" ) then return end

    if not E2Lib.isOwner( chip, target ) then return end

    local owner = E2Lib.getOwner( chip, target )

    if not playerCanStartStream( owner ) then return end

    local canRun = hook.Run( "StreamCore_PreStreamStart", chip, owner, url, id, volume, no3d )
    if canRun == false then return end

    local secs = GetConVarNumber( "streamcore_antispam_seconds" )
    antispam[owner:EntIndex()] = CurTime() + secs

    local index = chip:EntIndex() .. "-" .. id
    local url = fixURL( url ) or "nope"
    if url == "nope" then return end

    local radius = GetConVarNumber( "streamcore_maxradius" )
    if radius > 120 then radius = 120 end

    volume = clamp( volume, 0, 1 )
    streams[index] = {url, volume, radius}

    net.Start( "CFC_SC_StreamStart" )
        net.WriteString( index )
        net.WriteFloat( volume )
        net.WriteString( url )
        net.WriteEntity( target )
        net.WriteEntity( chip )
        net.WriteEntity( owner )
        net.WriteBool( no3d )
        net.WriteFloat( radius )
    net.Broadcast()

    setLastUse( self, "streamStart" )
end

__e2setcost( 1 )
e2function void streamDisable3D( disable )
    self.data = self.data or {}
    self.data.no3d = disable ~= 0
end

__e2setcost( 5 )
e2function string streamHelp()
    net.Start( "CFC_SC_StreamHelp" )
    net.Send( self.player )
    return "http://steamcommunity.com/sharedfiles/filedetails/?id=442653157"
end

e2function number streamLimit()
    return GetConVarNumber( "streamcore_antispam_seconds" )
end

e2function number streamMaxRadius()
    return GetConVarNumber( "streamcore_maxradius" )
end

e2function number streamAdminOnly()
    return math.Clamp( GetConVarNumber( "streamcore_adminonly" ), 0, 1 )
end

__e2setcost( 50 )
e2function void entity:streamStart( id, volume, string url )
    streamStart( self.entity, this, id, volume, url, self.data.no3d )
end

__e2setcost( 50 )
e2function void entity:streamStart( id, string url, volume )
    streamStart( self.entity, this, id, volume, url, self.data.no3d )
end

__e2setcost( 50 )
e2function void entity:streamStart( id, string url )
    streamStart( self.entity, this, id, 1, url, self.data.no3d )
end

__e2setcost( 10 )
e2function number streamCanStart()
    if isThrottled( self, "streamCanStart" ) then return end
    setLastUse( self, "streamCanStart" )

    return playerCanStartStream( self.player ) and 1 or 0
end

__e2setcost( 30 )
e2function void streamStop( id )
    if isThrottled( self, "streamStop" ) then return end

    local index = self.entity:EntIndex() .. "-" .. id
    if not streams[index] then return end

    net.Start( "CFC_SC_StreamStop" )
        net.WriteString( index )
    net.Broadcast()

    streams[index] = nil

    setLastUse( self, "streamStop" )
end

__e2setcost( 50 )
e2function void streamVolume( id, volume )
    if isThrottled( self, "streamVolume" ) then return end

    local index = self.entity:EntIndex() .. "-" .. id
    volume = clamp( volume, 0, 1 )

    local streamtbl = streams[index]
    if not streamtbl then return end

    if volume == streamtbl[2] then return end

    streams[index][2] = volume

    net.Start( "CFC_SC_StreamVolume" )
        net.WriteString( index )
        net.WriteFloat( volume )
    net.Broadcast()

    setLastUse(self, "streamVolume")
end

_e2setcost( 50 )
e2function void streamRadius( id, radius )
    if isThrottled( self, "streamRadius" ) then return end

    local index = self.entity:EntIndex() .. "-" .. id
    local maxradius = GetConVarNumber( "streamcore_maxradius" )
    radius = clamp( radius, 0, maxradius )

    local streamtbl = streams[index]
    if not streamtbl then return end

    if radius == streamtbl[3] then return end

    streams[index][3] = radius
    net.Start( "CFC_SC_StreamRadius" )
        net.WriteString( index )
        net.WriteFloat( radius )
    net.Broadcast()

    setLastUse(self, "streamRadius")
end
