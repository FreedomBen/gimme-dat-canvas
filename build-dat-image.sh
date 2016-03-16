if [ -f 'functions.sh' ]; then
  . functions.sh
else
  echo "Required file 'functions.sh' not found"
  exit 1
fi

root_dir=$(pwd)

# build the regular canvas image that we'll extend
green "Building the regular canvas dev image..."
if [ -d 'canvas-lms' ]; then
  green "Pulling latest from github and checking out latest release"
  cd canvas-lms && git checkout -f master && git pull -r
  cd ..
else
  green "Cloning fresh from github.  This might take a little while"
  git clone https://github.com/instructure/canvas-lms || die "Error cloning canvas"
fi

cd canvas-lms || die "No canvas checkout available"

REL="$(git tag | tail -n1)"
IMG_NAME="canvas-release-$(echo $REL | sed -e 's|.*/||g')"

green "Using release '$REL'"
git checkout -f $REL || die "Error checking out release '$REL'"

green "Building dev image named '$IMG_NAME'.  This might take awhile"
docker build -t "$IMG_NAME" docker-compose/ || die "Error building image $IMG_NAME"

cd $root_dir

# build the extension image:
cat <<__EOF__ > Dockerfile
FROM $IMG_NAME

COPY canvas-lms /usr/src/app

USER root
RUN usermod -u $(id -u) docker
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
docker build -t gimme-dat-canvas . || die "Error building our gimme-dat-canvas image"

green "Success!\n"

blue "* Now what? *\n"

blue "This is a good question.  Now you can run 'start-dat-canvas.sh'"
blue "To get a running canvas.  If you'd like to incorporate the new"
blue "image into another project, merge the provided"
blue "docker-compose.yml file into your own.  Note that before"
blue "starting canvas for the first time, you will need to run"
blue ""
blue "    docker run --rm gimme-dat-canvas /usr/src/app/setup-db.sh"
blue ""
blue "If you use 'start-dat-canvas.sh', this is done for you"
blue ""
blue "If you are updating an existing canvas by replacing it with"
blue "this new image, you will need to run migrations"
blue ""
blue "    docker run --rm gimme-dat-canvas bundle exec rake db:migrate"
blue ""
