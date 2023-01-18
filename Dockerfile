FROM mysql:5.7-debian

ADD debian-curl-package-from-unstable.sh /root/
RUN /root/debian-curl-package-from-unstable.sh
