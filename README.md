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

## FAQ

1. Why would you do this?

  There are many good reasons to split your project into modules.

  - The vast majority of websites have multiple entry-points (web pages). Javascript modules allow you to share code between these entry-points and with web-workers.
  - There is less code to push to the browser when you publish updates.
  - Debugging is easier because files are logically separated.
  - Processing your Javascript is easier with tools like [Webpack](http://webpack.github.io/) or [Browserify](http://browserify.org/).

2. Won't loading multiple files make my website slower?

  In short, no.  The longer answer is, if your server is configured to use SPDY or HTTPS2 and your target browser audience [supports one of them](http://caniuse.com/#feat=spdy), then the slow-down caused by multiple files is not even worth mentioning. To learn more about techniques of making your website load quickly, watch Jake Archibald's talk [here](https://vimeo.com/125479288).

## Caveats

- If you use Dead Code Elimination, you might end up with module files that do not include the functions you use in other modules that rely on them.  Generally speaking, DCE doesn't work well with modular-js.  Only use it in a controlled manner or not at all.
- Using `-debug` will not generate source-maps.  (But the javascript output is uncompressed and very readable so fixing this is a low priority)

## TODO

 - ES6 Modules
 - CommonJS Modules
