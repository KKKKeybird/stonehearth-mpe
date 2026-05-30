local ConnectCallHandler = class()

-- session/response are part of the RPC handler signature.
function ConnectCallHandler:connect_to_remote_server(session, response, payload)
   payload = payload or {}
   local result = stonehearth_mpe:connect_to_remote_server(payload.ip, payload.port, payload)
   return result
end

return ConnectCallHandler
