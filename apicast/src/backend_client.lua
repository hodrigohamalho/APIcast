local setmetatable = setmetatable
local concat = table.concat

local http_ng = require('resty.http_ng')
local user_agent = require('user_agent')
local resty_url = require('resty.url')

local _M = {

}

local mt = { __index = _M }

function _M.new(service, http_client)
  local endpoint = service.backend.endpoint or ngx.var.backend_endpoint
  local service_id = service.id

  if not endpoint then
    ngx.log(ngx.WARN, 'service ', service_id, ' does not have backend endpoint configured')
  end

  local authentication = { service_id = service_id }

  if service.backend_authentication.type then
    authentication[service.backend_authentication.type] = service.backend_authentication.value
  end

  local backend, err = resty_url.split(endpoint)

  if not backend and err then
    return nil, err
  end

  local client = http_ng.new{
    backend = http_client,
    options = {
      headers = {
        user_agent = user_agent(),
        host = service.backend.host or backend[4]
      },
      ssl = { verify = false }
    }
  }

  return setmetatable({
    version = service.backend_version,
    endpoint = endpoint,
    service_id = service_id,
    authentication = authentication,
    http_client = client
  }, mt)
end

function _M:authrep(...)
  local version = self.version
  local http_client = self.http_client

  if not version or not http_client then
    return nil, 'not initialized'
  end

  local endpoint = self.endpoint

  if not endpoint then
    return nil, 'missing endpoint'
  end

  local auth_uri = version == 'oauth' and 'oauth_authrep.xml' or 'authrep.xml'

  local args = { self.authentication, ... }

  for i=1, #args do
    args[i] = ngx.encode_args(args[i])
  end

  local url = resty_url.join(endpoint, '/transactions/', auth_uri, '?', concat(args, '&'))

  local res = http_client.get(url)

  ngx.log(ngx.INFO, 'backend client uri: ', url, ' ok: ', res.ok, ' status: ', res.status, ' body: ', res.body)

  return res
end

return _M
