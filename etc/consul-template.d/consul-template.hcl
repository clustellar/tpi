vault {
  address      = "http://vault.local:8200"
  token        = "s.m069Vpul3c4lfGnJ6unpxgxD"
  grace        = "1s"
  unwrap_token = false
  renew_token  = true
}

# NOMAD Certs
template {
  source      = "/opt/nomad/templates/server.crt.tpl"
  destination = "/opt/nomad/certs/server.crt"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/server.key.tpl"
  destination = "/opt/nomad/certs/server.key"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/client.crt.tpl"
  destination = "/opt/nomad/certs/client.crt"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/client.key.tpl"
  destination = "/opt/nomad/certs/client.key"
  perms       = 0700
  command     = "systemctl reload nomad"
}

template {
  source      = "/opt/nomad/templates/ca.crt.tpl"
  destination = "/opt/nomad/certs/ca.crt"
  command     = "systemctl reload nomad"
}


