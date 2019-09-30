FROM ubuntu
RUN apt-get update
RUN apt-get -y install wget curl software-properties-common build-essential git
RUN mkdir build && cd build

# install go
RUN wget https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
RUN tar xzf go1.12.2.linux-amd64.tar.gz && \
    mv go /usr/local/
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN go version

# Complie the DoH server
RUN mkdir ~/gopath && \
    wget https://github.com/m13253/dns-over-https/archive/v2.0.1.tar.gz && \
    tar xzf v2.0.1.tar.gz && \
    cd dns-over-https-2.0.1/ && \
    make && make install

# Configure the DoH server
COPY ./doh-server.conf /etc/dns-over-https/doh-server.conf

#RUN systemctl restart doh-server && systemctl status doh-server
# may need to split this into two separate images and use compose / swarm
# to set each of them up.

# Install NGINX
RUN apt-get install gnupg2 ca-certificates lsb-release && \
    echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" >> /etc/apt/sources.list.d/nginx.list && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - && \
    apt-key fingerprint ABF5BD827BD9BF62 && \
    apt-get update && apt-get -y install nginx

RUN cat << EOM > /etc/nginx/conf.d/00-rate-limits.conf \
limit_req_zone \$binary_remote_addr zone=doh_limit:10m rate=300r/s; \
EOM

COPY ./doh.conf /etc/nginx/conf.d/doh.conf
RUN systemctl restart nginx