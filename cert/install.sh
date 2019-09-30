cat << EOM > localhost.conf
[req]
default_bits       = 4096
default_keyfile    = server.key
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = v3_ca

[req_distinguished_name]
countryName                 = Country Name (2 letter code)
countryName_default         = US
stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = New York
localityName                = Locality Name (eg, city)
localityName_default        = Rochester
organizationName            = Organization Name (eg, company)
organizationName_default    = dns.d0hnut.wtf
organizationalUnitName      = organizationalunit
organizationalUnitName_default = SamuraiWTF
commonName                  = Common Name (e.g. server FQDN or YOUR name)
commonName_default          = d0nut
commonName_max              = 64

[req_ext]
subjectAltName = @alt_names

[v3_ca]
subjectAltName = @alt_names

[alt_names]
DNS.1   = localhost
DNS.2   = 127.0.0.1
EOM
yes '' | sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout server.key -out server.crt -config localhost.conf
mv server.crt /etc/ssl/server.crt
mv server.key /etc/ssl/server.key