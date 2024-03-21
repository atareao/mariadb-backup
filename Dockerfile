FROM alpine:3.19

LABEL maintainer="Lorenzo Carbonell <a.k.a. atareao> lorenzo.carbonell.cerezo@gmail.com"

ENV USER=dockerus \
    UID=10001 \
    HOME=cronitab

RUN apk add --update \
            --no-cache \
            tzdata~=2024 \
            curl~=8.5 \
            dcron~=4.5 \
            libcap~=2.69 \
            mysql-client~=10.11 \
            run-parts~=4.11 && \
    rm -rf /var/cache/apk && \
    rm -rf /var/lib/app/lists* && \
    adduser \
        --disabled-password \
        --gecos "" \
        --home "/${HOME}" \
        --shell "/sbin/nologin" \
        --uid "${UID}" \
        "${USER}" && \
    chown "${USER}:${USER}" /usr/sbin/crond && \
    setcap cap_setgid=ep /usr/sbin/crond && \
    touch "/${HOME}/${USER}" && \
    mkdir "/${HOME}/backup" && \
    chown -R "${USER}:${USER}" "/${HOME}"

COPY --chown="${USER}:${USER}" run.sh /run.sh
COPY --chown="${USER}:${USER}" backup.sh /backup.sh


WORKDIR "$HOME"
USER "${USER}"

CMD ["/bin/sh", "/run.sh"]
