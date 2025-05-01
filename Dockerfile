FROM docker.io/debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=en_US.UTF-8

RUN rm -f /etc/apt/apt.conf.d/docker-clean\
 && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update \
 && apt-get upgrade -y \
 && apt-get -y --no-install-recommends install \
    locales \
 && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen en_US.UTF-8 \
 && dpkg-reconfigure locales \
 && /usr/sbin/update-locale LANG=en_US.UTF-8

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get -y --no-install-recommends install \
    ca-certificates \
    git \
    libffi7 \
    libgeos-c1v5 \
    libpq5

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

USER www-data
WORKDIR /var/www

RUN --mount=type=bind,source=./,target=/tmp/src \
    uv venv --python 3.9 \
 && uv pip install /tmp/src \
 && cp -vait /var/www /tmp/src/*.ini

EXPOSE 8080
CMD ["uv", "run", "gunicorn", "--paste", "production.ini", "-u", "www-data", "-g", "www-data", "-b", ":8080"]
