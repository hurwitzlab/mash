FROM rust:1.39.0-stretch as rust

WORKDIR /app
RUN git clone https://github.com/hurwitzlab/mash.git
RUN cd mash/run_mash && cargo build --release && cp target/release/run_mash /usr/local/bin
RUN wget https://github.com/marbl/Mash/releases/download/v2.2/mash-Linux64-v2.2.tar && tar -xf mash-Linux64-v2.2.tar && cp mash-Linux64-v2.2/mash /usr/local/bin && rm *.tar

FROM r-base:3.6.1
RUN apt-get update -y
RUN apt-get install -y parallel libgomp1
RUN mkdir .parallel && touch .parallel/will-cite
COPY --from=rust /usr/local/bin /usr/local/bin
COPY --from=rust /usr/local/lib /usr/local/lib
COPY --from=rust /app/mash/scripts/make_figures.r /usr/local/bin
COPY --from=rust /app/mash/scripts/install.r /usr/local/bin
RUN Rscript /usr/local/bin/install.r
ENV LD_LIBRARY_PATH /usr/local/lib

CMD ["run_mash"]
