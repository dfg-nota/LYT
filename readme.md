# LYT

Source written in [CoffeeScript](http://jashkenas.github.com/coffee-script/)
Stylesheets written in [SASS](http://sass-lang.com/)
Inline docs written for [Docco](http://jashkenas.github.com/docco/)  
Tests run with [QUnit](http://docs.jquery.com/QUnit)

## Development

First, [read the style guide](/Notalib/LYT/wiki/Style-Guide).

To compile the CoffeeScript source files, issue the following from the repo's root:

    $ cake src

The compiled `.js` files will end up in `build/javascript`

To compile (concatenate, really) the HTML files, use:

    $ cake html

This also copies the contents of `assets/` into the `build/` directory, and compiles `sass/` to `build/css`

To see what else you can build, issue `cake` with no arguments:

    $ cake

To run a local webserver for testing purposes, issue the following (again from the repo's root):

    $ tools/server

This will start a (very simple) webserver that listens on http://127.0.0.1:7357, so you can check things out in a browser.
