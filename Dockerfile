FROM haskell:latest
RUN apt-get update && apt-get install make xz-utils
RUN stack update && stack upgrade
RUN stack install pipes pipes-concurrency split unordered-containers tubes 
WORKDIR .
ADD code /code
ENTRYPOINT /bin/bash
