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

green "Copying config files"
cp docker-compose/config/* config/

green "Updating config files for gimme-dat-canvas docker-compose container names"
sed -i -e 's|host.*postgres|host: canvas-postgres|g' 'config/database.yml'
sed -i -e 's|redis.*redis|redis://canvas-redis|g' 'config/redis.yml'

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

cyan "* Now what? *\n"

cyan "This is a good question.  Now you can run 'start-dat-canvas.sh'"
cyan "To get a running canvas.  If you'd like to incorporate the new"
cyan "image into another project, merge the provided"
cyan "docker-compose.yml file into your own.  Note that before"
cyan "starting canvas for the first time, you will need to run"
cyan ""
cyan "    docker run --rm gimme-dat-canvas /usr/src/app/setup-db.sh"
cyan ""
cyan "If you use 'start-dat-canvas.sh', this is done for you"
cyan ""
cyan "If you are updating an existing canvas by replacing it with"
cyan "this new image, you will need to run migrations"
cyan ""
cyan "    docker run --rm gimme-dat-canvas bundle exec rake db:migrate"
cyan ""
