Fetchbeer
=========

A script for Eggdrop IRC bot that gets a list of beers from [Olutopas.info](http://www.olutopas.info) and updates it once per day. Requires CURL installed on the system.

Installation
------------

Just copy beer.tcl to your eggdrop scripts directory, set config parameters and add to your Eggdrop configuration file.

Commands
--------

**Public**
!olut
.olut
!beer
.beer

Executes a command on a public IRC channel and prints out for example:
*[botname] tarjoaa Sinebrychoff Karhu Ruis 4,6% -tuopin userille

**MSG**
Same commands also work as MSG to bot, with the difference that the reply will also be an MSG back to the user.

**DCC**
.updatebeer

This will manually update the beer list. List is updated automatically once per day, so you only need to use this, if there is something wrong with the cached list. This will cause some traffic to [Olutopas.info](http://www.olutopas.info), so don't abuse it.