# Modular Javascript - A Custom Javascript Generator for Haxe

Quite simply, the modular-js generator will output AMD modules for each class in your Haxe application.  The filename is generated from the parent package of each class.

## Usage

1. Install modular-js with haxelib

  ```
  haxelib install modular-js
  ```

2. Add the generator in your HXML file.

  ```
  -lib modular-js
  ```

3. You must specify all of the classes of all the dynamic entry points in your hxml file. This tells the compiler to consider each class for Dead Code Elimination when outputting the files of the Haxe Standard Library.

## FAQ

1. Why would you do this?

  There are many good reasons to split your project into modules.

  - The vast majority of websites have multiple entry-points (web pages). Javascript modules allow you to share code between these entry-points, with existing code and with web-workers.
  - There is less code to push to the browser when you publish updates.
  - Debugging is easier because files are logically separated.
  - Processing your Javascript is easier with tools like [Webpack](http://webpack.github.io/) or [Browserify](http://browserify.org/).

2. Won't loading multiple files make my website slower?

  In short, no.  The longer answer is, if your server is configured to use SPDY or HTTPS2 and your target browser audience [supports one of them](http://caniuse.com/#feat=spdy), then the slow-down caused by multiple files is not even worth mentioning. To learn more about techniques of making your website load quickly, watch Jake Archibald's talk [here](https://vimeo.com/125479288).

## Known Issues

- Using `-debug` will not generate source-maps. (But the javascript output is uncompressed and
  very readable so fixing this is a low priority.)

## TODO

 - ES6 Modules
 - CommonJS Modules
