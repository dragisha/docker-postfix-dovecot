FROM ubuntu:14.04
RUN apt-get update
RUN apt-get install -y postfix postfix-mysql dovecot-common dovecot-pop3d dovecot-imapd openssl dovecot-mysql
ADD postfix /etc/postfix
ADD dovecot /etc/dovecot
RUN groupadd -g 5000 vmail && \
    useradd -g vmail -u 5000 vmail -d /home/vmail -m && \
    chgrp postfix /etc/postfix/mysql-*.cf && \
    chgrp vmail /etc/dovecot/dovecot.conf && \
    chmod g+r /etc/dovecot/dovecot.conf

RUN postconf -e virtual_uid_maps=static:5000 && \
    postconf -e virtual_gid_maps=static:5000 && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf && \
    postconf -e virtual_mailbox_maps=mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf && \
    postconf -e virtual_alias_maps=mysql:/etc/postfix/mysql-virtual-alias-maps.cf,mysql:/etc/postfix/mysql-email2email.cf && \
    postconf -e virtual_transport=dovecot && \
    postconf -e dovecot_destination_recipient_limit=1 && \
    postconf -e 'smtpd_sasl_type = dovecot' && \
    postconf -e 'smtpd_sasl_auth_enable = yes' && \
    postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination' && \
    postconf -e 'smtpd_sasl_path = private/auth' && \
    postconf -e "smtpd_client_message_rate_limit = 4" && \
    postconf -e "smtpd_tls_auth_only = yes" && \
    # specially for docker
    postconf -F '*/*/chroot = n' && \

RUN echo "dovecot   unix  -       n       n       -       -       pipe"  >> /etc/postfix/master.cf && \
    echo '    flags=DRhu user=vmail:vmail argv=/usr/lib/dovecot/deliver -d ${user}@${nexthop}' >> /etc/postfix/master.cf && \
    sed -i -e '/^#submission/,/^#smtps/{s/#subm/subm/;s/^# / /;/$mua/d}' /etc/postfix/master.cf && \
    sed -i -e "/^!include auth-system.conf.ext$/d" /etc/dovecot/conf.d/10-auth.conf

ADD start.sh /start.sh  

# default config
ENV DB_HOST localhost
ENV DB_USER root 

# SMTP ports
EXPOSE 25
EXPOSE 587  
# POP and IMAP ports  
EXPOSE 110
EXPOSE 143
EXPOSE 995
EXPOSE 993

CMD sh start.sh
