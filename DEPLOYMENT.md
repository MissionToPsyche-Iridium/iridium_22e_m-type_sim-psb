# Deploying

To deploy this project, place all of the files in this directory into an appropriate subdirectory in a standard HTML server. Ensure that all of the files in the directory can be resolved with relative paths.

In your server, ensure that these HTTP headers are set:

Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp

The Godot engine relies on these for web-based asset loading.