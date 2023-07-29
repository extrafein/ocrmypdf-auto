FROM alpine:latest as base

FROM base as builder

ENV LANG=C.UTF-8

RUN apk add --no-cache \
        autoconf \
        automake \
        build-base \
        ca-certificates \
        curl \
        libleptonica-dev \
        libtool \
        zlib-dev \
    && mkdir src \
    && cd src \
    && curl -L https://github.com/agl/jbig2enc/archive/refs/tags/0.29.tar.gz --output jbig2.tgz \
    && tar xzf jbig2.tgz --strip-components=1 \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

FROM base

ENV LANG=C.UTF-8

RUN ARCH=$(apk --print-arch) && \
    curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.14/gosu-$ARCH" && \
    chmod +x /usr/local/bin/gosu

RUN apk add --no-cache \
        ocrmypdf \
        ghostscript \
        #gosu \
        leptonicae \
        pngquant \
        py3-venv \
        py3-pip \
        qpdf \
        tesseract-ocr \
        tesseract-ocr-data-eng \
        tesseract-ocr-data-deu \
        tesseract-ocr-data-osd \
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
