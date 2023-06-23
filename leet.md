
# https://gist.github.com/gmolveau/e3673e3c25e4a77f3377ca3d97f10288
docker run --rm -it -v $PWD:/tmp debian:10-slim /bin/bash

# --rm : remove after exit
# -it : interactive TTY
# -v : mount folder : current folder to /tmp folder of the container
# debian:10-slim : docker image https://git.io/JJzfy
# /bin/bash : run bash in this container

docker run --rm -it -v $PWD/source/tari-dan/:/tmp rust /bin/bash

bash ./test-01.sh -s

docker run --rm -it --entrypoint /bin/bash -v $PWD/source/tari-dan/:/tmp 184a9c25fb69

docker exec -it -u root 5d423422edd7 /bin/bash

docker run --rm -it \
  -e DAN_TESTING_USE_BINARY_EXECUTABLE=True \
  -v $PWD/source/tari-dan/:/tmp \
  184a9c25fb69

docker run --rm -it \
  -e DAN_TESTING_USE_BINARY_EXECUTABLE=True \
  -v $PWD/source/tari-dan/:/tmp \
  /bin/bash \
  184a9c25fb69

docker run --rm -it \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v  "$(pwd)":"$(pwd)" \
      -w "$(pwd)" \
      -v "$HOME/.dive.yaml":"$HOME/.dive.yaml" \
      wagoodman/dive:latest build -t <some-tag> .

docker run --rm -it \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v  "$(pwd)":"$(pwd)" \
      -w "$(pwd)" \
      -v "$HOME/.dive.yaml":"$HOME/.dive.yaml" \
      jauderho/dive:latest build -t <some-tag> .

