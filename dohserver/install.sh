apt-get update
apt-get -y install curl software-properties-common build-essential git python
mkdir build
cd build 

# Need Go >= 1.10 to build DoH server
# so fetch latest
wget https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
tar xzf go1.12.2.linux-amd64.tar.gz 
mv go /usr/local/
export GOROOT=/usr/local/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
go version # verify it's working

# Now we fetch and compile the DoH server
mkdir ~/gopath
export GOPATH=~/gopath
wget https://github.com/m13253/dns-over-https/archive/v2.0.1.tar.gz
tar xzf v2.0.1.tar.gz 
cd dns-over-https-2.0.1/
make
make install

cat << EOM > /etc/dns-over-https/doh-server.conf
# HTTP listen port
listen = [
    "127.0.0.1:8053",    
    "[::1]:8053",
]

# TLS certification file
# If left empty, plain-text HTTP will be used.
# You are recommended to leave empty and to use a server load balancer (e.g.
# Caddy, Nginx) and set up TLS there, because this program does not do OCSP
# Stapling, which is necessary for client bootstrapping in a network
# environment with completely no traditional DNS service.
cert = ""

# TLS private key file
key = ""

# HTTP path for resolve application
path = "/dns-query"

# Upstream DNS resolver
# If multiple servers are specified, a random one will be chosen each time.
# Can't seem to get unbound to work on port 5353 for some reason, so just go with 53 for now
upstream = [
    "127.0.0.1:5353"
]

# Upstream timeout
timeout = 10

# Number of tries if upstream DNS fails
tries = 3

# Only use TCP for DNS query
tcp_only = false

# Enable logging
verbose = false

# Enable log IP from HTTPS-reverse proxy header: X-Forwarded-For or X-Real-IP
# Note: http uri/useragent log cannot be controlled by this config
log_guessed_client_ip = false

EOM

systemctl restart doh-server
systemctl status doh-server

apt-get -y install gnupg2 ca-certificates lsb-release
echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" >> /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
apt-key fingerprint ABF5BD827BD9BF62
apt-get update
apt-get -y install nginx


# We're going to set rate limits just in case the public gain access
# This sets 300 requests a second
cat << EOM > /etc/nginx/conf.d/00-rate-limits.conf
limit_req_zone \$binary_remote_addr zone=doh_limit:10m rate=300r/s;
EOM

cat << EOM > /etc/ssl/options-ssl-nginx.conf
ssl_session_cache shared:le_nginx_SSL:1m;
ssl_session_timeout 1440m;

ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;

ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
add_header Strict-Transport-Security "max-age=31536000;" always;
EOM

# Create the config - remember to replace server_name with whatever name you are using
cat << EOM > /etc/nginx/conf.d/doh.conf
upstream dns-backend {
    server 127.0.0.1:8053;
    keepalive 30;
}
server {
        server_name dns.d0nut.wft;
        root /tmp/NOEXIST;
        location /dns-query {
                limit_req zone=doh_limit burst=50 nodelay;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header Host \$http_host;
                proxy_set_header X-NginX-Proxy true;
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection "";
                proxy_redirect off;
                proxy_set_header  X-Forwarded-Proto \$scheme;
                proxy_read_timeout 86400;
                proxy_pass http://dns-backend/dns-query;
        }
        location / {
            return 404;
        }
        listen 443 ssl http2;
        # consider using certbot for the cert, but first see if we can get it all working
        # via self signed certs
        ssl_certificate /etc/ssl/server.crt;
        ssl_certificate_key /etc/ssl/server.key;
}
EOM

systemctl restart nginx

netstat -lnp | grep 80

cat << EOM > /etc/nginx/conf.d/00-cert-stapling.conf
ssl_stapling on;
ssl_stapling_verify on;
resolver 127.0.0.1:5353;
EOM

#apt-get install certbot python-certbot-nginx
#certbot --nginx -d dns.bentasker.co.uk
apt-get -y install unbound
chown -R unbound:unbound /etc/unbound/

cat << EOM > /etc/unbound/unbound.conf
server:
    module-config: "subnetcache validator iterator"
    chroot: ""
    directory: "/etc/unbound"
    username: "unbound"
    interface: 127.0.0.1
    port: 5353
    do-daemonize: yes
    verbosity: 1
    # Enable UDP, "yes" or "no".
    do-udp: yes
    # Enable TCP, "yes" or "no".
    do-tcp: yes
    # auto-trust-anchor-file: "/etc/unbound/root.key"
    # ECS support
    client-subnet-zone: "." 
    client-subnet-always-forward: yes
    max-client-subnet-ipv4: 24
    max-client-subnet-ipv6: 48    
    # Randomise case to make poisioning harder
    use-caps-for-id: yes
    # Minimise QNAMEs
    qname-minimisation: yes
    harden-below-nxdomain: yes
    # This is where we'll put our adblock config 
    # include: local.d/*.conf

include: unbound.conf.d/*.conf

remote-control:
    control-enable: no 
    server-key-file: "/etc/unbound/unbound_server.key"
    server-cert-file: "/etc/unbound/unbound_server.pem"
    control-key-file: "/etc/unbound/unbound_control.key"
    control-cert-file: "/etc/unbound/unbound_control.pem"

EOM
systemctl restart unbound
echo "127.0.0.1     dns.d0hnut.wtf" >> /etc/hosts
curl -sk "https://dns.d0hnut.wtf/dns-query?name=www.secureideas.com&type=A"