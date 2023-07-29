FROM debian:bookworm-slim as base

############# BASE - Builder

FROM base as builder

ENV LANG=C.UTF-8

# download binaries, compile-sources and libraries
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        curl \
        libleptonica-dev \
        libtool \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# create source working directory
RUN mkdir src
WORKDIR /src

# download latest jbig2enc source
RUN curl -L https://github.com/agl/jbig2enc/archive/refs/tags/0.29.tar.gz | tar xz --strip-components=1

# compile jbig2enc
RUN ./autogen.sh && \
    ./configure CPPFLAGS="-I/usr/include" LDFLAGS="-L/usr/lib" && \
    make && \
    make install

# remove source
RUN rm -rf /src

############# BASE

FROM base

ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ocrmypdf \
        ghostscript \
        gosu \
        liblept5 \
        pngquant \
        python3-venv \
        python3-pip \
        qpdf \
        tesseract-ocr \
        tesseract-ocr-eng \
        tesseract-ocr-deu \
        tesseract-ocr-osd \
        unpaper \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv --system-site-packages /appenv \
    && . /appenv/bin/activate \
    && pip install --upgrade pip \
    && pip install --upgrade requests plumbum watchdog

# Copy jbig2 from builder image
COPY --from=builder /usr/local/bin/ /usr/local/bin/

COPY --from=builder /usr/local/lib/ /usr/local/lib/

COPY src/ /app/

# Create restricted privilege user docker:docker to drop privileges
# to later. We retain root for the entrypoint in order to install
# additional tesseract OCR language packages.
RUN groupadd -g 1000 docker && \
    useradd -u 1000 -g docker -N --home-dir /app docker && \
    mkdir /config /input /output /ocrtemp /archive && \
    chown -Rh docker:docker /app /config /input /output /ocrtemp /archive && \
    chmod 755 /app/docker-entrypoint.sh

VOLUME ["/config", "/input", "/output", "/ocrtemp", "/archive"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
