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

S3_PREFIX='master'
S3_BUCKET="gimme-dat-canvas-build-cache/${S3_PREFIX}"

# Download the latest node_modules from s3
for tarball in node_modules.tar.gz client_apps-canvas_quizzes-node_modules.tar.gz gems-canvas_i18nliner-node_modules.tar.gz; do
  aws s3 cp s3://${S3_BUCKET}/${tarball} ./
done

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

green "Copying config files"
cp docker-compose/config/* config/

green "Updating config files for gimme-dat-canvas docker-compose container names"
sed -i -e 's|host.*postgres|host: canvas-postgres|g' 'config/database.yml'
sed -i -e 's|redis.*redis|redis://canvas-redis|g' 'config/redis.yml'

green "Removing phantomjs from package.json due to bitbucket rate limiting"
sed -i -e '/phantomjs-prebuilt/d' 'package.json'

REL_TAG="$(date +'%Y%m%d_%H%M%S')"
PREL_IMG_NAME="canvas-master-${REL_TAG}"
IMG_NAME="freedomben/canvas-lms-unstable"
IMG_PLUS_REL="${IMG_NAME}:${REL_TAG}"

green "Building dev image named '$PREL_IMG_NAME'.  This might take awhile"
docker build -t "$PREL_IMG_NAME" docker-compose/ || die "Error building image $PREL_IMG_NAME"

cd $root_dir

# build the extension image:
cat <<__EOF__ > Dockerfile
FROM $PREL_IMG_NAME

COPY canvas-lms /usr/src/app

USER root
COPY setup-db.sh /usr/src/app
RUN chmod +x /usr/src/app/setup-db.sh
RUN chown -R docker:docker /usr/src/app

USER docker
ENV PATH \$PATH:\$GEM_HOME/bin

RUN bundle install

# Sad hack to avoid bitbucket throttling during npm install
COPY node_modules.tar.gz /usr/src/app/
COPY client_apps-canvas_quizzes-node_modules.tar.gz /usr/src/app/client_apps/canvas_quizzes/
COPY gems-canvas_i8nliner-node_modules.tar.gz /usr/src/app/gems/canvas_i18nliner/
WORKDIR /usr/src/app
RUN tar xzvf node_modules.tar.gz && rm -f node_modules.tar.gz
WORKDIR /usr/src/app/client_apps/canvas_quizzes
RUN tar xzvf client_apps-canvas_quizzes-node_modules.tar.gz && rm -f client_apps-canvas_quizzes-node_modules.tar.gz
WORKDIR /usr/src/app/gems/canvas_i18nliner
RUN tar xzvf gems-canvas_i8nliner-node_modules.tar.gz && rm -f gems-canvas_i8nliner-node_modules.tar.gz
WORKDIR /usr/src/app

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
  push_failed $push_name
fi

# Copy out the node_modules and archive the node_modules to s3
CONTAINER_NAME=temp-canvas-to-copy
docker run --rm --name ${CONTAINER_NAME} ${IMG_NAME} nc -l 9999
for dirname in node_modules client_apps/canvas_quizzes/node_modules gems/canvas_i18nliner/node_modules; do
  tarball_name="$(echo $dirname | sed -e 's|/|-|g').tar.gz"
  green "Copying $dirname to ./node_modules"
  docker cp ${CONTAINER_NAME}:/usr/src/app/${dirname} ./     && \
  green "Tarring ./node_modules to $tarball_name"               && \
  tar czf $tarball_name node_modules                         && \
  green "Pushing $tarball_name to s3 bucket '$S3_BUCKET'"     && \
  aws s3 cp $tarball_name s3://${S3_BUCKET}/${tarball_name}
  rm -f $tarball_name
  rm -rf node_modules
done
docker kill ${CONTAINER_NAME}

echo "Done copying to s3"
