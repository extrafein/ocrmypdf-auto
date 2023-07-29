FROM alpine:latest as base

FROM base as builder

ENV LANG=C.UTF-8

RUN apk add --no-cache \
        autoconf \
        automake \
        build-base \
        ca-certificates \
        curl \
        libtool \
        #leptonica-dev \
        zlib-dev

# Create the necessary directories # Download and extract leptonica source
RUN mkdir src
WORKDIR /src
RUN curl -L https://github.com/DanBloomberg/leptonica/archive/master.tar.gz | tar xz --strip-components=1
RUN ./autogen.sh && \
    ./configure CPPFLAGS="-I/usr/include" LDFLAGS="-L/usr/lib" && \
    make && \
    make install
RUN rm -rf /src
    
# Download and extract jbig2enc source
RUN mkdir src
WORKDIR /src
RUN curl -L https://github.com/agl/jbig2enc/archive/refs/tags/0.29.tar.gz | tar xz --strip-components=1
RUN ./autogen.sh && \
    ./configure CPPFLAGS="-I/usr/include" LDFLAGS="-L/usr/lib" && \
    make && \
    make install
RUN rm -rf /src

FROM base

ENV LANG=C.UTF-8

RUN apk add --no-cache \
        ocrmypdf \
        ghostscript \
        curl \
        #gosu \
        leptonica \
        pngquant \
        python3 \
        py3-pip \
        qpdf \
        tesseract-ocr \
        tesseract-ocr-data-eng \
        tesseract-ocr-data-deu \
        tesseract-ocr-data-osd \
        unpaper
        
RUN curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu

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
