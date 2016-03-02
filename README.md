# gimme-dat-canvas

The easiest way to get a running canvas in production mode.  This is useful for developing things like LTI tools which require a working canvas, but are not developing on Canvas itself.  *This is not a production ready canvas.  It's just in production mode so it will be more performant*

## How do I get dat canvas?

Clone this repo:

```
git clone 
```

run the script to build a canvas image!

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
