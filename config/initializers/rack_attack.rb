# config/initializers/rack_attack.rb
class Rack::Attack
  throttle('ping/ip', limit: 4, period: 1.minute) do |req|
    req.ip if req.path == '/api/v1/m_batterys/ping' && req.post?
  end

  self.throttled_responder = lambda do |_|
    [429, { 'Content-Type' => 'application/json' }, [{ error: 'Rate limit exceeded please wait 1 min' }.to_json]]
  end
end