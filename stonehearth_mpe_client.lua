
stonehearth_mpe = {
}

local service_creation_order = {
}

local monkey_patches = {

}

local headless_monkey_patches = {
   mpe_building_client_service = 'stonehearth.services.client.building.building_client_service',
   mpe_client = _radiant.client,
}

local function monkey_patching(headless)
   local patches = monkey_patches
   if headless then
      patches = headless_monkey_patches
   end
   for from, into in pairs(patches) do
      local monkey_see = require('monkey_patches.' .. from)
      local monkey_do = type(into) == "string" and radiant.mods.require(into) or into
      radiant.mixin(monkey_do, monkey_see)
   end
end

local function _trim(value)
   if type(value) ~= 'string' then
      return nil
   end

   local trimmed = value:match('^%s*(.-)%s*$')
   if trimmed == '' then
      return nil
   end

   return trimmed
end

local function _to_port(value)
   local port = tonumber(value)
   if not port then
      return nil
   end

   port = math.floor(port)
   if port < 1 or port > 65535 then
      return nil
   end

   return port
end

local function _set_global_config(path, value)
   if radiant and radiant.util and type(radiant.util.set_global_config) == 'function' then
      local ok = pcall(radiant.util.set_global_config, path, value)
      if ok then
         return true
      end
   end

   if _radiant and _radiant.client and type(_radiant.client.set_config) == 'function' then
      local ok = pcall(_radiant.client.set_config, path, value)
      if ok then
         return true
      end
   end

   return false
end

local function _call_client_method(method_name, ...)
   if not _radiant or not _radiant.client then
      return false
   end

   local method = _radiant.client[method_name]
   if type(method) ~= 'function' then
      return false
   end

   local ok = pcall(method, _radiant.client, ...)
   if ok then
      return true
   end

   ok = pcall(method, ...)
   return ok
end

function stonehearth_mpe:connect_to_remote_server(ip, port, options)
   options = options or {}

   local target_ip = _trim(ip)
   if not target_ip then
      return {
         success = false,
         error = 'invalid_ip',
      }
   end

   local target_port = _to_port(port)
   if not target_port then
      return {
         success = false,
         error = 'invalid_port',
      }
   end

   local remote_enabled = _set_global_config('multiplayer.remote_server.enabled', true)
   local ip_set = _set_global_config('multiplayer.remote_server.ip', target_ip)
   local port_set = _set_global_config('multiplayer.remote_server.port', target_port)

   if not (remote_enabled and ip_set and port_set) then
      radiant.log.write(
         'stonehearth_mpe',
         0,
         'Connect - Config update failed enabled=%s ip=%s port=%s',
         tostring(remote_enabled),
         tostring(ip_set),
         tostring(port_set)
      )
      return {
         success = false,
         error = 'config_update_failed',
      }
   end

   -- Different game/client builds expose different native method names.
   local connected = _call_client_method('connect_to_remote_server', target_ip, target_port)
      or _call_client_method('connect_remote_server', target_ip, target_port)
      or _call_client_method('connect_to_server', target_ip, target_port)

   if connected then
      radiant.log.write('stonehearth_mpe', 0, 'Connect - Connecting to %s:%s', target_ip, target_port)
      return {
         success = true,
         ip = target_ip,
         port = target_port,
         reconnect_required = false,
      }
   end

   local restart_client = options.restart_client == true
   local restart_error = nil
   local restarted = false
   if restart_client then
      local restart_ok, restart_err = pcall(_radiant.call, 'radiant:client:restart')
      restarted = restart_ok
      if not restart_ok then
         restart_error = tostring(restart_err)
         radiant.log.write('stonehearth_mpe', 0, 'Connect - Failed client restart for %s:%s (%s)', target_ip, target_port, tostring(restart_err))
      end
   end

   radiant.log.write('stonehearth_mpe', 0, 'Connect - Saved remote target %s:%s', target_ip, target_port)
   local result = {
      success = true,
      ip = target_ip,
      port = target_port,
      reconnect_required = true,
      restarted = restarted,
   }
   if restart_error then
      result.restart_error = restart_error
   end
   return result
end

function stonehearth_mpe:_on_init() 
   stonehearth_mpe._sv = stonehearth_mpe.__saved_variables:get_data()
   radiant.service_creator.create_services(stonehearth_mpe, 'stonehearth_mpe', service_creation_order)
   
   radiant.log.write('stonehearth_mpe', 0, 'Client initialized')
end

function stonehearth_mpe:_on_required_loaded()
   monkey_patching()
end

function stonehearth_mpe:_on_server_ready()
   _radiant.call('stonehearth_mpe:is_headless_mode_enabled'):done(function(r)
      stonehearth_mpe.headless_enabled = r.result;
      if stonehearth_mpe.headless_enabled then
         monkey_patching(true)
      end
   end)
end

-- joining a remote game
function stonehearth_mpe:_on_game_joined()
   print('remote game joined')
end

radiant.events.listen(stonehearth_mpe, 'radiant:init', stonehearth_mpe, stonehearth_mpe._on_init)
radiant.events.listen(radiant, 'radiant:required_loaded', stonehearth_mpe, stonehearth_mpe._on_required_loaded)
radiant.events.listen(radiant, 'radiant:client:game_joined', stonehearth_mpe, stonehearth_mpe._on_game_joined)
radiant.events.listen(radiant, 'radiant:client:server_ready', stonehearth_mpe, stonehearth_mpe._on_server_ready)

return stonehearth_mpe
