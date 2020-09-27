{{ with secret "$INT_PKI/issue/$ROLE" "common_name=$HOSTNAME.$DOMAIN" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1" }}
{{ .Data.issuing_ca }}
{{ end }}
