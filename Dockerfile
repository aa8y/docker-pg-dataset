FROM postgres:alpine

MAINTAINER Arun Allamsetty <arun.allamsetty@gmail.com>

# Separate the installation as we can cache it as a layer.
RUN apk add --update \
      bash \
      ca-certificates \
      git \
      wget && \
    rm -rf /var/cache/apk/*

ARG DATASETS=dellstore,iso3166,pagila,sportsdb,usda,world
ARG PG_USER=postgres
ARG PG_HOME=/home/$PG_USER
ENV POSTGRES_USER docker
ENV POSTGRES_PASSWORD docker

# Enable psql history.
RUN mkdir -p $PG_HOME && \
    touch $PG_HOME/.psql_history && \
    chown -R $PG_USER:$PG_USER $PG_HOME

WORKDIR /tmp
# Data Sources.
# PG Foundry: http://pgfoundry.org/frs/?group_id=1000150
# SportsDB:   http://www.sportsdb.org/sd/samples
#
# `export` does not persist across images. So we need to make the conditional statements part of 
# this layer.
RUN bash -c ' \
    declare -A SQL=( \
      [dellstore]="(dellstore2-normal-1.0/dellstore2-normal-1.0.sql)" \
      [iso3166]="(iso-3166/iso-3166.sql)" \
      [pagila]="(pagila/pagila-schema.sql pagila/pagila-insert-data.sql)" \
      [sportsdb]="(sportsdb_sample_postgresql_20080304.sql)" \
      [usda]="(usda-r18-1.0/usda.sql)" \
      [world]="(dbsamples-0.1/world/world.sql)" \
    ) && \
    declare -A URL=( \
      [dellstore]=http://pgfoundry.org/frs/download.php/543/dellstore2-normal-1.0.tar.gz \
      [iso3166]=http://pgfoundry.org/frs/download.php/711/iso-3166-1.0.tar.gz \
      [pagila]=https://github.com/devrimgunduz/pagila.git \
      [sportsdb]=http://www.sportsdb.org/modules/sd/assets/downloads/sportsdb_sample_postgresql.zip \
      [usda]=http://pgfoundry.org/frs/download.php/555/usda-r18-1.0.tar.gz \
      [world]=http://pgfoundry.org/frs/download.php/527/world-1.0.tar.gz \
    ) && \
    for DATASET in "${!SQL[@]}"; do \
      export DATASET_URL="${URL[$DATASET]}" && \
      declare -a DATASET_SQL="${SQL[$DATASET]}" && \
      if [[ $DATASETS == *"$DATASET"* ]]; then \
        echo "Populating dataset: ${DATASET}" && \
        if [[ $DATASET_URL == *.tar.gz ]]; then \
          wget -qO- $DATASET_URL | tar -C . -xzf -; \
        elif [[ $DATASET_URL == *.zip ]]; then \
          wget $DATASET_URL -O tmp.zip && \
          unzip -d . tmp.zip; \
          rm tmp.zip; \
        elif [[ $DATASET_URL == *.git ]]; then \
          git clone $DATASET_URL; \
        fi && \
        echo "CREATE DATABASE $DATASET;" >> "/docker-entrypoint-initdb.d/${DATASET}.sql" && \
        echo "\c $DATASET;" >> "/docker-entrypoint-initdb.d/${DATASET}.sql" && \
        for i in "${!DATASET_SQL[@]}"; do \
          cat "${DATASET_SQL[i]}" >> "/docker-entrypoint-initdb.d/${DATASET}.sql"; \
        done && \
        rm -rf *; \
      fi; \
    done'

USER $PG_USER
WORKDIR $PG_HOME
