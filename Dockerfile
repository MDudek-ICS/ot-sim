FROM docker.io/library/ubuntu:20.04 AS build

ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update \
  && apt install -y \
    git wget \
    build-essential cmake libboost-dev libczmq-dev libxml2-dev libzmq5-dev pkg-config python3-dev python3-pip

ENV GOLANG_VERSION 1.18

RUN wget -O go.tgz https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf go.tgz && rm go.tgz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" \
  && chmod -R 777 "$GOPATH"

ADD . /usr/local/src/ot-sim

# Running the cmake command twice is a hack to get around CMake Policy CMP0077
# when trying to disable tests for cppzmq.
RUN cmake -S /usr/local/src/ot-sim -B /usr/local/src/ot-sim/build
RUN cmake -S /usr/local/src/ot-sim -B /usr/local/src/ot-sim/build \
  && cmake --build /usr/local/src/ot-sim/build -j $(nproc) --target install
RUN make -C /usr/local/src/ot-sim/src/go install
RUN python3 -m pip install /usr/local/src/ot-sim/src/python
RUN ldconfig

FROM docker.io/library/ubuntu:20.04 AS prod

ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update \
  && apt install -y \
    bash-completion curl git tmux tree vim wget xz-utils \
    libczmq4 libsodium23 libxml2 libzmq5 python3-pip

COPY --from=build /usr/local /usr/local
RUN ldconfig

FROM docker.io/library/ubuntu:20.04 AS test

ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update \
  && apt install -y \
    bash-completion curl git tmux tree vim wget xz-utils \
    build-essential cmake libczmq4 libsodium23 libxml2 libzmq5 python3-dev python3-pip

RUN wget -O hivemind.gz https://github.com/DarthSim/hivemind/releases/download/v1.1.0/hivemind-v1.1.0-linux-amd64.gz \
  && gunzip --stdout hivemind.gz > /usr/local/bin/hivemind \
  && chmod +x /usr/local/bin/hivemind \
  && rm hivemind.gz

RUN wget -O overmind.gz https://github.com/DarthSim/overmind/releases/download/v2.2.2/overmind-v2.2.2-linux-amd64.gz \
  && gunzip --stdout overmind.gz > /usr/local/bin/overmind \
  && chmod +x /usr/local/bin/overmind \
  && rm overmind.gz

RUN python3 -m pip install opendssdirect.py~=0.6.1

RUN git clone --recursive https://github.com/kisensum/pydnp3 /tmp/pydnp3 \
  && python3 -m pip install /tmp/pydnp3 \
  && rm -rf /tmp/pydnp3

COPY --from=build /usr/local /usr/local
RUN ldconfig

ADD . /usr/local/src/ot-sim
WORKDIR /usr/local/src/ot-sim