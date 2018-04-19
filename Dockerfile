FROM haskell:latest
RUN apt-get update && apt-get install -y make xz-utils
RUN stack update && stack upgrade
RUN stack install pipes pipes-concurrency tubes split unordered-containers 
WORKDIR .
ADD ./code /code
ENTRYPOINT /bin/bash
