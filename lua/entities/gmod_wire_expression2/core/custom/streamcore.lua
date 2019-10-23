E2Lib.RegisterExtension( "streamcore", true )

CreateConVar( "streamcore_antispam_seconds", 5, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_antispam_ignoreadmins", 1, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_adminonly", 0, FCVAR_SERVER_CAN_EXECUTE )
CreateConVar( "streamcore_maxradius", 120, FCVAR_SERVER_CAN_EXECUTE )

util.AddNetworkString( "XTS_SC_StreamStart" )
util.AddNetworkString( "XTS_SC_StreamStop" )
util.AddNetworkString( "XTS_SC_StreamVolume" )
util.AddNetworkString( "XTS_SC_StreamRadius" )
util.AddNetworkString( "XTS_SC_StreamHelp" )

local streams = {}
local antispam = {}

local function fixURL( str )
    local url = string.Trim( str )
    if string.len( url ) < 5 then return end
    if string.sub( url, 1, 4 ) ~= "http" then
        url = "https://" .. url
    end
    return url
end

local function streamCanStart( ply )
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

local function streamStart( from, ent, id, volume, str, no3d )
    if not IsValid( from ) then return end
    if not IsValid( ent ) then return end
    if not E2Lib.isOwner( from, ent ) then return end

    local owner = E2Lib.getOwner( from, ent )
    if not streamCanStart( owner ) then return end

    local secs = GetConVarNumber( "streamcore_antispam_seconds" )
    antispam[owner:EntIndex()] = CurTime() + secs

    local index = from:EntIndex() .. "-" .. id
    local url = fixURL( str ) or "nope"
    if url == "nope" then return end

    local radius = GetConVarNumber( "streamcore_maxradius" )
    if radius > 120 then radius = 120 end

    volume = math.Clamp( volume, 0, 1 )
    streams[index] = {url, volume, radius}

    net.Start( "XTS_SC_StreamStart" )
        net.WriteString( index )
        net.WriteFloat( volume )
        net.WriteString( url )
        net.WriteEntity( ent )
        net.WriteEntity( from )
        net.WriteEntity( owner )
        net.WriteBool( no3d )
        net.WriteFloat( radius )
    net.Broadcast()
end

__e2setcost( 1 )
e2function void streamDisable3D( disable )
    self.data = self.data or {}
    self.data.no3d = disable ~= 0
end

__e2setcost( 5 )
e2function string streamHelp()
    net.Start( "XTS_SC_StreamHelp" )
    net.Send( self.player )
    return "http://steamcommunity.com/sharedfiles/filedetails/?id = 442653157"
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

e2function void entity:streamStart( id, string url, volume )
    streamStart( self.entity, this, id, volume, url, self.data.no3d )
end

e2function void entity:streamStart( id, string url )
    streamStart( self.entity, this, id, 1, url, self.data.no3d )
end

__e2setcost( 10 )
e2function number streamCanStart()
    return streamCanStart( self.player ) and 1 or 0
end

e2function void streamStop( id )
    local index = self.entity:EntIndex() .. "-" .. id
    if streams[index] then
        net.Start( "XTS_SC_StreamStop" )
            net.WriteString( index )
        net.Broadcast()
        streams[index] = nil
    end
end

__e2setcost( 15 )
e2function void streamVolume( id, volume )
    local index = self.entity:EntIndex() .. "-" .. id
    volume = math.Clamp( volume, 0, 1 )
    local streamtbl = streams[index]
    if not streamtbl then return end
    if volume ~= streamtbl[2] then
        streams[index][2] = volume
        net.Start( "XTS_SC_StreamVolume" )
            net.WriteString( index )
            net.WriteFloat( volume )
        net.Broadcast()
    end
end

e2function void streamRadius( id, radius )
    local index = self.entity:EntIndex() .. "-" .. id
    local maxradius = GetConVarNumber( "streamcore_maxradius" )
    radius = math.Clamp( radius, 0, maxradius )
    local streamtbl = streams[index]
    if not streamtbl then return end
    if radius ~= streamtbl[3] then
        streams[index][3] = radius
        net.Start( "XTS_SC_StreamRadius" )
            net.WriteString( index )
            net.WriteFloat( radius )
        net.Broadcast()
    end
end
