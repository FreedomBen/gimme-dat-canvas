# gimme-dat-canvas

By far the easiest way &trade; to get a running canvas as a docker appliance.  This is useful for developing things like LTI tools which require a working canvas, but you are not developing Canvas itself.  *This is not a production ready canvas.  There's a lot more to do if you want a production ready image*.

**Note**:  *I highly recommend pairing this with either [dory](https://github.com/FreedomBen/dory)
(on Linux) or [dinghy](https://github.com/codekitchen/dinghy) (on OS X).  There's a lot of
services here, and using a reverse proxy will make your life better.*

## How do I get dat canvas?

### Run it stand-alone

If you clone this repo, there's a script called `run-dat-container.sh` that you can run
and it'll do it all for you.  However, you probably will want to integrate this into your
project as an appliance (see next section).  If you want to build your own image, you'll
need to change the name in the `docker-compose.yml` file to point to your new image.

### Add it to your project's docker-compose.yml

The easiest way is to use the image published on docker hub (which was created with this tool).
You'll probably want to just add this to your current project's `docker-compose.yml` file
so you can set links and stuff.  You'll want something like this:

```yaml
canvas-postgres:
  image: postgres:9.3
  volumes:
    - "./pg_data:/var/lib/postgresql/data"

canvas-redis:
  image: redis:2.6

canvas-consul:
  image: gliderlabs/consul-server:0.5
  command: -node canvas-consul -bootstrap
  environment:
    GOMAXPROCS: "2"

canvas-kinesis:
  image: instructure/kinesalite
  environment:
    VIRTUAL_HOST: kinesis.docker
    VIRTUAL_PORT: 4567

canvas-web: &WEB
  image: gimme-dat-canvas
  links:
    - canvas-consul
    - canvas-postgres
    - canvas-redis
    - canvas-kinesis
  environment:
    RACK_ENV: development
    VIRTUAL_HOST: canvas.docker

canvas-jobs:
  <<: *WEB
  command: bundle exec script/delayed_job run
```

Great!  Now before running it for the first time you need to setup the database.  You can run the provided script:

```
docker-compose run --rm canvas-web /usr/src/app/setup-db.sh
```

*NOTE:  If you get an error, you might need to bring up the postgres container first to let it initialize itself before attempting to setup the database.*

You should now be able to log in as `andy.reid@example.com` with password `password`

### Build your own image

Clone this repo:

```
git clone 
```

Run the script to build a canvas image!

```
./build-dat-image.sh
```

Then run the image with the script (or manually)

```
./run-dat-container.sh
```

## What does this do for me that regular dockerized canvas doesn't?

Good question. This setup will:

1.  Build assets inside the container, instead of sharing a volume with the host system.
1.  Mount the postgres database externally, so your data doesn't all live in a docker container.
1.  Handle the initial setup stuff.
