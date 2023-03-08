# by

An automatic build system for [**stand**](https://github.com/rhardih/stand)
containers.

![Screenshot](https://raw.githubusercontent.com/rhardih/by/master/public/images/screenshot.png)

In short, **by** is a small web application, which provides an exhaustive
overview of available **stand** containers images, based on combinations of what
*NDK*, *platform* and *toolchain* each include. It also provides information
about whether an image with a specific combination is already available to be
pulled, or has yet to be built.

For images not yet built, **by** also provides a means for creating not yet
existing combinations, by triggering builds on [Github](https://github.com/),
which subsequently pushes the resulting container images to [Docker
Hub](https://hub.docker.com/r/rhardih/stand/tags)

An instance is currently is currently hosted on a free plan on
[Render](https://render.com) and is automatically deployed from the `master`
branch. It is available at:

[https://standby.rhardih.io](https://standby.rhardih.io)

## Disclaimer

Please note that the use the Android NDK is subject to the Terms and Conditions
laid forth by Google. For the full text, please see:

[https://developer.android.com/ndk/downloads/](https://developer.android.com/ndk/downloads/index.html)
