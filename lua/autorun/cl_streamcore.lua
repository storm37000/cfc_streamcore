local streams = {}

local streamcoreDisable = CreateClientConVar( "streamcore_disable", 0, true, false, "Disables streamcore." )

hook.Add( "AddToolMenuCategories", "CFC_Streamcore_AddToolMenuCategories", function()
	spawnmenu.AddToolCategory( "Options", "CFC", "#CFC" )
end )

hook.Add( "PopulateToolMenu", "CFC_Streamcore_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "CFC", "cfc_streamcore", "#Streamcore", "", "", function( panel )
        local checkbox = panel:CheckBox( "Disable streamcore", "streamcore_disable" )
        function checkbox:OnChange( val )
            if not val then return end
            for index in pairs( streams ) do
                streamStop( index )
            end
        end
    end )
end )

local function streamStop( index )
	timer.Remove("CFC_SC_Think_" .. index)
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
		print( "Stream #" .. index .. " by " .. name .. " <" .. sid .. ">: " .. url )
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

net.Receive( "CFC_SC_StreamHelp", function( len )
	gui.OpenURL( "https://steamcommunity.com/sharedfiles/filedetails/?id=442653157" )
end )

net.Receive( "CFC_SC_StreamStop", function( len )
	streamStop( net.ReadString() )
end )

net.Receive( "CFC_SC_StreamStart", function( len )
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

	print( "[StreamCore] New stream #" .. index .. " by " .. owner:Name() .. " <" .. owner:SteamID() .. ">: " .. url )

	streamStop( index ) 
	local flag = ""
	if not no3d then flag = "3d" end
	sound.PlayURL( url, flag, function( station )
		if IsValid( station ) then
			station:SetVolume( volume )
			streams[index] = {
				station, ent, from, owner,
				url, no3d, volume, radius
			}
			local streamtbl = streams[index]
			timer.Create( "CFC_SC_Think_" .. index, 0.1, 0, function()
				if IsValid( streamtbl[1] ) and IsValid( streamtbl[2] ) and IsValid( streamtbl[3] ) then
					if streamtbl[6] then
						local distance = LocalPlayer():GetPos():Distance( streamtbl[2]:GetPos() )
						distance = math.Clamp( ( distance - streamtbl[8] ) / 30, 1, 300 )
						local volume = streamtbl[7] / distance
						if volume < 0.06 then volume = 0 end
						station:SetVolume( volume )
					else
						station:SetPos( streamtbl[2]:GetPos() )
					end
				else streamStop( index ) end
			end )
		end
	end )
end )

net.Receive( "CFC_SC_StreamVolume", function( len )
	local index = net.ReadString()
	local volume = net.ReadFloat()
	local streamtbl = streams[index]
	if not streamtbl then return end
	streams[index][7] = volume
	if not streamtbl[6] then
		streamtbl[1]:SetVolume( volume )
	end
end )

net.Receive( "CFC_SC_StreamRadius", function( len )
	local index = net.ReadString()
	local radius = net.ReadFloat()
	local streamtbl = streams[index]
	if not streamtbl then return end
	streams[index][8] = radius
end )