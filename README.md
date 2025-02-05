# Bookinfo Sample

Forked from https://github.com/istio/istio for @clairegregg's Master Thesis, as an example application.

See <https://istio.io/docs/examples/bookinfo/>.

## Set up 
This project is developed locally using kind, with docker port forwarding to allow clusters to contact each other (and to provide access on localhost).

To setup, run .\setup.ps1 (or the equivalent for Linux).

Now, mongodb should be accessible on mongodb://127.0.0.1:27017/.

The application should be available on localhost:8080/productpage.