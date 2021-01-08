if SERVER then AddCSLuaFile() return end

local streams = {}

local streamcoreDisable = CreateClientConVar( "streamcore_disable", 0, true, false, "Disables streamcore." )

hook.Add( "AddToolMenuCategories", "CustomCategory", function()
    spawnmenu.AddToolCategory( "Options", "CFC", "#CFC" )
end )

hook.Add( "PopulateToolMenu", "CustomMenuSettings", function()
    spawnmenu.AddToolMenuOption( "Options", "CFC", "cfc_streamcore", "#Streamcore", "", "", function( panel )
        panel:CheckBox( "Disable streamcore", "streamcore_disable" )
    end )
end )

local function streamStop( index )
    local streamtbl = streams[index] or {}
    local canStop = IsValid( streamtbl[1] )
    if canStop then
        streamtbl[1]:Stop()
    end
    streams[index] = nil
    return canStop
end

concommand.Add( "streamcore_list", function()
    print( "[StreamCore] ############### Active streamings ###############" )
    for index, streamtbl in pairs( streams ) do
        local name = streamtbl[4]:Name()
        local sid = streamtbl[4]:SteamID()
        local url = streamtbl[5]
        print( "Stream #" .. index .. " by " .. name .. " ( " .. sid .. " ): " .. url )
    end
    print( "[StreamCore] ################## End of list ##################" )
end )

concommand.Add( "streamcore_stop", function( ply, concmd, args )
    if #args < 1 then return end
    local index = args[1]
    if streamStop( index ) then
        print( "[StreamCore] Stream #" .. index .. " successfully stopped!" )
    end
end )

concommand.Add( "streamcore_purge", function()
    for index, streamtbl in pairs( streams ) do
        if streamStop( index ) then
            print( "[StreamCore] Stream #" .. index .. " successfully stopped!" )
        end
    end
    print( "[StreamCore] Purge done." )
end )

net.Receive( "XTS_SC_StreamHelp", function( len )
    gui.OpenURL( "http://steamcommunity.com/sharedfiles/filedetails/?id=442653157" )
end )

net.Receive( "XTS_SC_StreamStop", function( len )
    streamStop( net.ReadString() )
end )

net.Receive( "XTS_SC_StreamStart", function( len )
    local isDisabled = streamcoreDisable:GetBool()
    if isDisabled == true then return end
    local index = net.ReadString()
    local volume = net.ReadFloat()
    local url = net.ReadString()
    local ent = net.ReadEntity()
    local from = net.ReadEntity()
    local owner = net.ReadEntity()
    local no3d = net.ReadBool()
    local radius = net.ReadFloat()
    if not IsValid( ent ) then return end
    if not IsValid( from ) then return end
    streamStop( index ) local flag = ""
    if not no3d then flag = "3d" end
    sound.PlayURL( url, flag, function( station )
        if IsValid( station ) then
            station:SetVolume( volume )
            streams[index] = {
                station, ent, from, owner,
                url, no3d, volume, radius
            }
        end
    end )
end )

net.Receive( "XTS_SC_StreamVolume", function( len )
    local index = net.ReadString()
    local volume = net.ReadFloat()
    local streamtbl = streams[index]
    if not streamtbl then return end
    streams[index][7] = volume
    if not streamtbl[6] then
        streamtbl[1]:SetVolume( volume )
    end
end )

net.Receive( "XTS_SC_StreamRadius", function( len )
    local index = net.ReadString()
    local radius = net.ReadFloat()
    local streamtbl = streams[index]
    if not streamtbl then return end
    streams[index][8] = radius
end )

hook.Add( "Think", "XTS_SC_Think", function( ent )
    for index, streamtbl in pairs( streams ) do
        local station = streamtbl[1]
        local ent = streamtbl[2]
        local from = streamtbl[3]
        if IsValid( station ) and IsValid( ent ) and IsValid( from ) then
            if streamtbl[6] then
                local distance = LocalPlayer():GetPos():Distance( ent:GetPos() )
                distance = math.Clamp( (distance-streamtbl[8] ) / 30, 1, 300 )
                local volume = streamtbl[7] / distance
                if volume < 0.06 then volume = 0 end
                station:SetVolume( volume )
            else
                station:SetPos( ent:GetPos() )
            end
        else streamStop( index ) end
    end
end )
