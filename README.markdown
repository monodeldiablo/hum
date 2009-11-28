Hum -- The low calorie music manager
====================================

What is Hum?
------------
Hum aims to be a lightweight, quick, easy-to-use music manager with powerful
search, collection, and tagging abilities. 

'But wait!', Hum hears you plaintively cry, 'How can Hum have its cake and eat
it, too?'

Well, by standing on the shoulders of giants, that's how. To this end, Hum
plans on letting [Tracker](http://www.tracker-project.org/) manage the
collection, search, metadata, and tagging functionalities, while the equally
awesome [GStreamer](http://gstreamer.freedesktop.org) manages all the playback
nastiness. 

Smart, huh?

At the moment, however, Hum is a mere shadow. It is a hollow and barren shell
of what it could potentially be, barely capable of even the simplest tasks. It
yearns for love and care, the kind of tender nurturing that only other open
source developers with a passion for simplicity and usability can give.

Won't you help turn this homely little app into something your mother would
enjoy listening to her Benny Goodman on?

How can I get my grubby little hands on it?
-------------------------------------------
Ideally, a package for it exists within your Linux distribution's repository.
If, however, it does not, you may [download the latest source tarball](http://github.com/monodeldiablo/hum/downloads)
from the project site. Ensure that you have recent versions of Vala, Tracker,
GTK, and GStreamer, then invoke this:

  ./configure && make && make install

If that didn't work and you can't play with Hum, [file an issue](http://github.com/monodeldiablo/hum/issues)
at the project site and we'll get on it. Better yet, contribute a patch and we
can become best friends!

