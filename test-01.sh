#!/usr/bin/env bash
# Build docker images script, with options
#
# Prerequisites:
# Run `./build_images.sh -r`
#
# local/default envs - .env.local
#

#set -e
set -x

build_tari_image() {
# $1 image name
# $2 image tag
# $3 build from path
# $4 APP_NAME ie: base_node
# $5 APP_EXEC ie: tari_base_node

  # Add docker tag alias - ie: latest
  if [ ! -z "${TL_TAG_ALIAS}" ]; then
    TL_TAG_CMD=" -t ${TL_TAG_URL}/$1:${TL_TAG_ALIAS} "
  fi
  echo "Building $4 ($5) from tarilabs.Dockerfile in $1 image version $2 ..."
  echo "* Image will be tagged as ${TL_TAG_URL}/$1:$2"
  echo "* and: ${TL_TAG_CMD}"
  echo "* Build options: ${TL_TAG_BUILD_OPTS}"
  echo "* Architecture: ${TBN_ARCH}"
  echo "* Features: ${TBN_FEATURES}"
  echo "* TL_TAG_BUILD_Extra: ${TL_TAG_BUILD_Extra}"

#    -f docker_rig/tarilabs.Dockerfile \

  docker ${TL_TAG_BUILD_OPTS} \
    -f test-01.Dockerfile \
    --build-arg ARCH=${TBN_ARCH} \
    --build-arg FEATURES=${TBN_FEATURES} \
    --build-arg VERSION=$2 \
    $4 $5 $6 $7 $8 $9 \
    -t ${TL_TAG_URL}/$1:$2 $3 ${TL_TAG_BUILD_Extra} ${TL_TAG_CMD}

  if [ "$?" -eq 0 ]; then
    echo "Docker image build - ${TL_TAG_URL}/$1:$2"
  else
    echo "Something went wrong build docker ${TL_TAG_URL}/$1:$2"
  fi
}

build_tari_image_json() {
# $1 json image_name

  export $(jq --arg jsonVar "$1" -r '. [] | select(."image_name"==$jsonVar)
    | to_entries[] | .key + "=" + .value' tarisuite.json)
  build_tari_image $image_name \
    "$TL_VERSION_LONG" ${TARI_SOURCE_ROOT} \
    $app_name $app_exec
}

build_all_tari_images() {
  for element in "${arrTariSuite[@]}"; do
    build_tari_image_json $element
  done
}

build_all_images() {
  build_all_3dparty_images
  build_all_tari_images
}

build_help_info() {
  cat << EOF
Build launchpad's docker images locally

USAGE:
  $0 [OPTIONS]

OPTIONS:
  -a, --all         build all images with current default environment variables
  -3, 3rdparty      build 3rd Party images
  -t, tari          build Tari suite images
  -l, ls            list images that can be built
  -r, requirements  list and check for pre-requisite software needed by this script
  -b image_name     build an image
  -h                this help info

Default envs can loaded from .env.local

EOF
}

build_help_images() {
  echo "List all images that can be built:"
  echo " ${arr3rdParty[@]}"
  echo " ${arrTariSuite[@]}"
}

# Quick overrides
if [ -f ".env.local" ]; then
  source ".env.local"
fi

# Location of Tari source code
TARI_SOURCE_ROOT=${TARI_SOURCE_ROOT:-"../tari"}

if [ ! -f "${TARI_SOURCE_ROOT}/tari/applications/tari_base_node/Cargo.toml" ]; then
  echo "!! Can't find Tari source code at ${TARI_SOURCE_ROOT}/tari !!"
  echo "searching for ${TARI_SOURCE_ROOT}/tari/applications/tari_base_node/Cargo.toml "
  exit 2
fi

#if [ ! -f "${TARI_SOURCE_ROOT}/buildtools/docker_rig/start_tari_app.sh" ]; then
#  echo "Put start_tari_app.sh into tari source"
#  mkdir -p ${TARI_SOURCE_ROOT}/buildtools/docker_rig
#  cp -v docker_rig/start_tari_app.sh ${TARI_SOURCE_ROOT}/buildtools/docker_rig/start_tari_app.sh
#fi

# Version refers to the base_node, wallet, etc.
#  applications/tari_app_utilities/Cargo.toml
TL_VERSION=${TL_VERSION:-$(awk -F ' = ' '$1 ~ /version/ \
  { gsub(/["]/, "", $2); printf("%s",$2) }' \
  "${TARI_SOURCE_ROOT}/tari/applications/tari_base_node/Cargo.toml")}

# Default build options - general x86-64 / AMD64
TBN_ARCH=${TBN_ARCH:-x86-64}
TBN_FEATURES=${TBN_FEATURES:-safe}

# Docker tag URL
TL_TAG_URL=${TL_TAG_URL:-quay.io/tarilabs}

# Docker build options
TL_TAG_BUILD_OPTS=${TL_TAG_BUILD_OPTS:-"build"}

# Docker tag suffix for platform
#TL_TAG_BUILD_PF=-amd64

#TL_VERSION_LONG="${TL_VERSION}-${TBN_ARCH}-${TBN_FEATURES}"
TL_VERSION_LONG=${TL_VERSION_LONG:-"${TL_VERSION}${TL_TAG_BUILD_PF}"}

# Docker sub Tag extra
#SUBTAG_EXTRA=${SUBTAG_EXTRA:-"-$TL_VERSION_LONG"}

# Docker tag alias
#TL_TAG_ALIAS=latest

# Docker Build extra commands
#TL_TAG_BUILD_Extra=" --build-arg RUST_TOOLCHAIN=nightly-2022-05-01 "

arrAllTools=(  $(jq -r '.[].image_name' tarisuite.json 3rdparty.json) )
arrTariSuite=( $(jq -r '.[].image_name' tarisuite.json) )
arr3rdParty=(  $(jq -r '.[].image_name' 3rdparty.json) )

check_for() {
  if result=$($1 --version 2>/dev/null); then
    result="$1: $result INSTALLED ✓"
  else
    result="$1: MISSING ⨯"
  fi
}

if [ -n "$BASH_VERSION" ]; then
  if [ "${BASH_VERSION:0:1}" -lt 4 ]; then
    echo "!! Needs bash v4.x or above - current bash version $BASH_VERSION !!"
  fi
else
  echo "Should be run with bash v4.x or above"
fi

# toLower
#commandEnv="${1,,}"
commandEnv=$(echo "${1}" | tr "[:upper:]" "[:lower:]")

case $commandEnv in
  -s | suite )
    shift
    build_tari_image dan-testing \
      "$TL_VERSION_LONG" ${TARI_SOURCE_ROOT} $*
    ;;
  -t | tari )
    build_all_tari_images
    ;;
  -a | all )
    build_all_images
    ;;
  -b | build )
    echo "Build a docker image"
    shift
    if [[ ${arrAllTools[*]} =~ (^|[[:space:]])"${1}"($|[[:space:]]) ]]; then
      echo "Image found - $1"
      if [ "${1:0:5}" == "tari_" ]; then
        build_tari_image_json $1
      fi
    else
      echo "Image not found for $1"
      build_help_info
      build_help_images
      exit 3
    fi
    ;;
  -l | ls )
    build_help_images
    ;;
  -r | req | requirement | requirements )
    echo "List of requirements and possible test:"
    check_for jq
    echo "$result"
    check_for docker
    echo "$result"
    check_for awk
    echo "$result"
    check_for bash
    echo "$result"
    ;;
  -h | -? | --help | help )
    build_help_info
    ;;
  *) echo "Unrecognised option: $1"
    build_help_info
    exit 4
    ;;
esac

exit 0
