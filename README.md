# Bookinfo Sample

Forked from https://github.com/istio/istio for @clairegregg's Master Thesis, as an example application.

See <https://istio.io/docs/examples/bookinfo/>.

## Set up 
This project is developed locally using kind, with docker port forwarding to allow clusters to contact each other (and to provide access on localhost).

To setup, run .\setup.ps1 (or the equivalent for Linux).

Now, mongodb should be accessible on mongodb://127.0.0.1:27017/.

The application should be available on localhost:8080/productpage.

## Pushing New Versions of Docker Images

```
export HUB="docker.io/clairegregg"
export TAG="v0.0.5"
```

To compile the code...
```
BOOKINFO_TAG=$TAG BOOKINFO_HUB=$HUB src/build-services.sh
```

To compile the code and push the new images...
```
BOOKINFO_LATEST=true BOOKINFO_TAG=$TAG BOOKINFO_HUB=$HUB src/build-services.sh --push
```

To compile the code, push the new images, and update the yaml files...
```
BOOKINFO_UPDATE=true BOOKINFO_LATEST=true BOOKINFO_TAG=$TAG BOOKINFO_HUB=$HUB src/build-services.sh --push
```