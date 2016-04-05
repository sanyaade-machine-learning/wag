basename     = require('path').basename
css          = require 'css'
dirname      = require('path').dirname
findType     = require './find-type'
fs           = require 'fs'
hash         = require './hash'
join         = require('path').join
minifyImage  = require './minify-image'
minifyScript = require './minify-javascript'
parsePath    = require('path').parse
parseCssUrl  = require './parse-css-url'
extname      = require('path').extname

ren  = require './rename-css-refs'
ren2 = require './rename-html-refs'


# parse asset graph, minifying and renaming based on md5 hash
#
# @param string outputPath  absolute path to the directory minified/renamed
#                           assets are written to
# @param string assetsPath  absolute path to location where assets currently
#                           exist
# @param object htmlRefs    key is an absolute path to an html file, value is
#                           an array of absolute filepaths referenced by the
#                           html file
# @param object styleRefs   key is an absolute path to a css file, value is an
#                           array of absolute filepaths referenced by the css
#                           file
# @param string cdnPrefix   a url path to prepend to all assets when re-written
#                           e.g., '//cdn.somedomain.com' will re-write abc.css
#                           to '//cdn.somedomain.com/abc-<MD5 file hash>.css'
module.exports = optimize = (outputPath, assetsPath, htmlRefs, styleRefs, cdnPrefix='') ->
  # maintain a list of assets that are renamed. key is original path, value is
  # renamed path
  renamed = {}

  # renaming assets based on MD5 hash must be done in order because any assets
  # that depend on that renamed file will mean the reference to that asset has
  # to be updated, which will cascade through the graph! the solution is to
  # traverse through all dependencies, and rename leaf nodes first, then work 
  # backwards.  HTML -> CSS -> images, javascripts, fonts

  for path, refs of htmlRefs
    for absPath in refs
      # ensure the asset hasn't already been optimized
      if not renamed[absPath]
        type = findType(absPath)
        if type is 'image'
          image = fs.readFileSync absPath
          minified = minifyImage(absPath, image)
          hashed = hash(minified)
          
          # include original file name in hashed filename
          parsed = parsePath absPath
          out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
          fs.writeFileSync out, minified
          renamed[absPath] = out
        else if type is 'javascript'
          script = fs.readFileSync absPath, 'utf8'
          minified = minifyScript(absPath, script)
          hashed = hash(minified)
          
          # include original file name in hashed filename
          parsed = parsePath absPath
          out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
          fs.writeFileSync out, minified
          renamed[absPath] = out
        else if type is 'font'
          font = fs.readFileSync absPath, 'utf8'
          hashed = hash(font)

          # include original file name in hashed filename
          parsed = parsePath absPath
          out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
          fs.writeFileSync out, font
          renamed[absPath] = out

  for path, refs of styleRefs
    for absPath in refs
      if not renamed[absPath]
        #console.log 'handle css ref:', absPath
        type = findType(absPath)
        if type is 'image'
          image = fs.readFileSync absPath
          minified = minifyImage(absPath, image)
          hashed = hash(minified)
          
          # include original file name in hashed filename
          parsed = parsePath absPath
          out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
          fs.writeFileSync out, minified
          renamed[absPath] = out

        else if type is 'font'
          font = fs.readFileSync absPath, 'utf8'
          hashed = hash(font)

          # include original file name in hashed filename
          parsed = parsePath absPath
          out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
          fs.writeFileSync out, font
          renamed[absPath] = out

  # now all of the leaf nodes (images, fonts, javascripts) are processed.

  # update all css files to point at leaf node references
  for path, refs of styleRefs
    text = fs.readFileSync path, 'utf8'
    minified = ren path, text, assetsPath, renamed, cdnPrefix
    hashed = hash(minified)
    parsed = parsePath path
    out = join outputPath, "#{parsed.name}-#{hashed}#{parsed.ext}"
    fs.writeFileSync out, minified, 'utf8'
    renamed[path] = out

  # update all html files to point at leaf node and css file references
  for path, refs of htmlRefs
    text = fs.readFileSync path, 'utf8'
    html = ren2 path, text, assetsPath, renamed, cdnPrefix
    console.log 'updating', path
    # update the html in-place
    fs.writeFileSync path, html, 'utf8'
