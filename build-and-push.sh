#!/usr/bin/env bash

if [[ $1 =~ stable ]]; then
  BUILD=stable
  IMG_NAME="freedomben/canvas-lms"
else
  BUILD=master
  IMG_NAME="freedomben/canvas-lms-unstable"
fi

USE_S3_FOR_NM=1
S3_BUCKET="gimme-dat-canvas-build-cache/${BUILD}"
USE_RL_HACK=$USE_S3_FOR_NM

if [ -f 'functions.sh' ]; then
  . functions.sh
else
  echo "Required file 'functions.sh' not found"
  exit 1
fi

root_dir=$(pwd)

if [ -d 'pg_data' ]; then
  yellow "Hello friend, I see there's a pg_data/ directory here."
  yellow "Unfortunately I can't build the image unless it's gone."
  yellow "I would just delete it, but it probably has data in it"
  yellow "that you don't want to lose.  I'll let you move it."
  yellow "Don't forget to move it back when you're done, otherwise"
  yellow "you'll have to start the database over from scratch."
  exit 1
fi

if is_stable; then
  green "Building latest stable release"
else
  green "Building latest version of master"
fi

if (( $USE_S3_FOR_NM )); then
  # Download the latest node_modules from s3
  green 'Downloading the latest node_modules from s3 to avoid bitbucket rate limiting'
  for tarball in node_modules.tar.gz client_apps-canvas_quizzes-node_modules.tar.gz gems-canvas_i18nliner-node_modules.tar.gz; do
    if ! aws s3 cp s3://${S3_BUCKET}/${tarball} ./; then
      USE_RL_HACK=0
      yellow "node_module download of '$tarball' from s3 failed.  disabling rate limiting hack"
      break
    fi
  done
fi

# build the regular canvas image that we'll extend
green "Building the regular canvas dev image..."
if [ -d 'canvas-lms' ]; then
  green "Pulling latest from github"
  cd canvas-lms && git checkout -f master && git pull -r
  cd ..
else
  green "Cloning fresh from github.  This might take a little while"
  git clone https://github.com/instructure/canvas-lms || die "Error cloning canvas"
fi

cd canvas-lms || die "No canvas checkout available"

if is_stable; then
  CO_REL_TAG="$(git tag | tail -n1)"
  REL_TAG="$(echo $CO_REL_TAG | sed -e 's|.*/||g')"
  PREL_IMG_NAME="canvas-release-${REL_TAG}"
else
  REL_TAG="$(date +'%Y%m%d_%H%M%S')"
  PREL_IMG_NAME="canvas-master-${REL_TAG}"
fi
IMG_PLUS_REL="${IMG_NAME}:${REL_TAG}"

green "Copying config files"
cp docker-compose/config/* config/

green "Updating config files for gimme-dat-canvas docker-compose container names"
sed -i -e 's|host.*postgres|host: canvas-postgres|g' 'config/database.yml'
sed -i -e 's|redis.*redis|redis://canvas-redis|g' 'config/redis.yml'

if is_stable; then
  green "Using release '$CO_REL_TAG'"
  git checkout -f $CO_REL_TAG || die "Error checking out release '$CO_REL_TAG'"
fi

green "Building dev image named '$PREL_IMG_NAME'.  This might take awhile"
#docker build -t "$PREL_IMG_NAME" docker-compose/ || die "Error building image $PREL_IMG_NAME"

cd $root_dir

RATE_LIMITING_HACK=''

if (( $USE_RL_HACK )); then
  green 'Using rate limiting hack'
read -r -d '' RATE_LIMITING_HACK <<'__EOF__'
# Sad hack to avoid bitbucket throttling during npm install
USER root
COPY node_modules.tar.gz /usr/src/app/
COPY client_apps-canvas_quizzes-node_modules.tar.gz /usr/src/app/client_apps/canvas_quizzes/
COPY gems-canvas_i18nliner-node_modules.tar.gz /usr/src/app/gems/canvas_i18nliner/
WORKDIR /usr/src/app
RUN tar xzf node_modules.tar.gz && rm -f node_modules.tar.gz
WORKDIR /usr/src/app/client_apps/canvas_quizzes
RUN tar xzf client_apps-canvas_quizzes-node_modules.tar.gz && rm -f client_apps-canvas_quizzes-node_modules.tar.gz
WORKDIR /usr/src/app/gems/canvas_i18nliner
RUN tar xzf gems-canvas_i18nliner-node_modules.tar.gz && rm -f gems-canvas_i18nliner-node_modules.tar.gz
WORKDIR /usr/src/app
__EOF__
else
  yellow 'Not using rate limiting hack'
fi

# build the extension image:
cat <<__EOF__ > Dockerfile
FROM $PREL_IMG_NAME

COPY canvas-lms /usr/src/app

$RATE_LIMITING_HACK

USER root
COPY setup-db.sh /usr/src/app
RUN chmod +x /usr/src/app/setup-db.sh
RUN chown -R docker:docker /usr/src/app

USER docker
ENV PATH \$PATH:\$GEM_HOME/bin

RUN bundle install
RUN npm install

RUN bundle exec rake canvas:compile_assets
__EOF__

green "Building our canvas image (this will have assets compiled and other things)"
if docker build -t ${IMG_PLUS_REL} -t ${IMG_NAME}:latest . ; then
  echo build_succeeded "${IMG_PLUS_REL}"
else
  build_failed "${IMG_PLUS_REL}"
  die "Error building '${IMG_PLUS_REL}'"
fi

if docker push $IMG_PLUS_REL; then
  build_pushed $IMG_PLUS_REL
else
  push_failed $IMG_PLUS_REL
fi

if docker push ${IMG_NAME}:latest; then
  build_tagged "${IMG_PLUS_REL}" "latest"
else
  push_failed ${IMG_NAME}:latest
fi

# Copy out the node_modules and archive the node_modules to s3
if (( $USE_S3_FOR_NM )); then
  green 'Caching node_modules in s3'
  CONTAINER_NAME=temp-canvas-to-copy
  docker run --detach --name ${CONTAINER_NAME} ${IMG_NAME} nc -l 9999
  green 'Waiting 5 seconds for the container to start to avoid race conditions'
  sleep 5
  green 'copying the node_modules from the container and pushing to s3'
  for dirname in node_modules client_apps/canvas_quizzes/node_modules gems/canvas_i18nliner/node_modules; do
    tarball_name="$(echo $dirname | sed -e 's|/|-|g').tar.gz"
    rm -rf node_modules
    rm -f $tarball_name
    green "Copying $dirname to ./node_modules"
    docker cp ${CONTAINER_NAME}:/usr/src/app/${dirname} ./     && \
    green "Tarring ./node_modules to $tarball_name"            && \
    tar czf $tarball_name node_modules                         && \
    green "Pushing $tarball_name to s3 bucket '$S3_BUCKET'"    && \
    aws s3 cp $tarball_name s3://${S3_BUCKET}/${tarball_name}
    green "Removing $tarball_name and node_modules"
    rm -f $tarball_name
    rm -rf node_modules
  done
  docker kill ${CONTAINER_NAME}
  docker rm ${CONTAINER_NAME}
  green "Done copying to s3"
fi

green 'Deleting image locally'
docker rmi ${PREL_IMG_NAME}
docker rmi ${IMG_PLUS_REL}
docker rmi ${IMG_NAME}:latest

if which docker-janitor; then
  green 'Running docker-janitor'
  docker-janitor clean
else
  yellow 'docker-janitor is not installed.  "gem install docker-janitor"'
  yellow 'not cleaning up'
fi

green 'All finished!'
