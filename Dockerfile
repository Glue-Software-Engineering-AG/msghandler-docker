FROM bellsoft/liberica-runtime-container:jre-17.0.19-glibc

ARG BUILD_DATE
ARG BUILD_VERSION
# Installation dir of msghandler
ARG MSGHANDLER_INSTALL_DIR="/opt/msghandler"

LABEL \
    maintainer="Glue AG <support@fenceit.ch>" \
    org.opencontainers.image.authors="Glue AG <support@fenceit.ch>" \
    org.opencontainers.image.title="Open eGov MessageHandler" \
    org.opencontainers.image.description="Open eGov MessageHandler allows for sedex message dispatching through a single adapter." \
    org.opencontainers.image.version=${BUILD_VERSION} \
    org.opencontainers.image.source="https://github.com/Glue-Software-Engineering-AG/msghandler-docker" \
    org.opencontainers.image.licenses="GPL3" \
    org.opencontainers.image.created=${BUILD_DATE}


# set correct Timezone
ENV TZ=Europe/Zurich

# Expose default msghandler webservice port
EXPOSE 18080

COPY apps/open-egov-msghandler-*-linux-x86-64.tar.gz $MSGHANDLER_INSTALL_DIR/

RUN set -ex && \
    # Install additional packages \
    apk update && apk add --no-cache --upgrade bash tzdata && \
    # The installation directory has been created by COPY above \
    cd  "$MSGHANDLER_INSTALL_DIR" && \
    # extract distro \
    tar -zxvf open-egov-msghandler-*-linux-x86-64.tar.gz && \
    # clean up \
    rm open-egov-msghandler-*-linux-x86-64.tar.gz  && \
    # create symbolic link 'current' \
    ln -s open-egov-msghandler-* current  && \
    # remove example config file. We will use the config file mounted from host \
    rm /opt/msghandler/current/conf/config.xml && \
    # Adapt permissions such, that MH can be started using any user \
    cd "$MSGHANDLER_INSTALL_DIR"/current && \
    # all files: (644) rw r r \
    find . -type f -exec chmod 0644 {} \; && \
    # all dirs: (755) rwx rx rx \
    find . -type d -exec chmod 0755 {} \; && \
    # Create all needed dirs under /app/msghandler (see Glue-Software-Engineering-AG/msghandler-docker#5) \
    mkdir -p \
      /working/tmp/receiving \
      /working/tmp/preparing \
      /working/tmp \
      /working/unknown \
      /working/corrupted \
      /working/db \
      /working/sent \
      /app/msghandler/inbox \
      /app/msghandler/outbox \; && \
    # the following files must be executable\
    chmod 0755 /opt/msghandler/current/bin/message-handler \
             /opt/msghandler/current/bin/wrapper \
             /opt/msghandler/current/lib/native/libwrapper.so && \
    # the bin directory must be writeable be anyone. The pid file WILL be written to it \
    chmod 0777 /opt/msghandler/current/bin

WORKDIR $MSGHANDLER_INSTALL_DIR/current

USER nobody

# Start MH
ENTRYPOINT ["./bin/message-handler","docker-console"]

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
   CMD wget http://localhost:18080/message-handler/ping?type=minimal -q -O /dev/null || exit 1