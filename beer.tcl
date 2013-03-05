###############################################################
#
#    Fetch Beer script for Eggdrop
#    by teel
#
#    Get a list of beers from http://olutopas.info/ and
#    serve random beer to the user from the list.
#
#    Usage:
#    !olut
#    !beer
#
#    DCC commands:
#    .updatebeer - force beer list update
#    
#    Changelog:
#    1.5 Temp dir as parameter
#    1.4 Added list URL and regexps as config variables
#    1.3 Fixed Regexps for new format & fixed "too many open 
#       files bug"
#    1.2 Use commandline curl instead of TclCurl
#    1.1 Fixed update & improved formatting
#    1.0    Initial version
#
#    Todo:
#    - Switch to seasonal lists automatically
#
###############################################################

namespace eval FetchBeer {
    # CONFIG
    # cache location
    set cachefile "./cache/beerlist.cache"
    # location for temp files while parsing
    set tempdir "./temp/"
    # words
    set verbs [list "noutaa" "hakee" "tarjoaa" "ojentaa" "antaa"]
    set containers [list "-tuopin" "-pullon"]
    # channels where the script is active
    set channels [list "#testchannel"]
    # CONFIG END

    # LISTS
    # normal
    set listUrl "http://olutopas.info/bycat.php?cat=abc"
    # xmas list: 
    set xmasListUrl "http://olutopas.info/selaa.php?class=kausi&id=1"
    # easter:
    set easterListUrl "http://olutopas.info/selaa.php?class=kausi&id=2"
    # summer:
    set summerListUrl "http://olutopas.info/selaa.php?class=kausi&id=3"
    # oktoberfest: 
    set oktoberfestListUrl "http://olutopas.info/selaa.php?class=kausi&id=4"
    # regular expressions to parse lists (don't change these)
    set resultregexp {<a href=\"\?resultpage=([0-9]*)}
    set beerregexp {<a href=\"\/olut\/([0-9]*)\/[^\"]*\" target=\"leftFrame\">([^\<]*)<\/a>}

    # BINDS
    bind pub - !olut FetchBeer::beerpub
    bind pub - .olut FetchBeer::beerpub
    bind pub - !beer FetchBeer::beerpub
    bind pub - .beer FetchBeer::beerpub
    bind msg - !olut FetchBeer::beermsg
    bind msg - !beer FetchBeer::beermsg
    bind msg - .olut FetchBeer::beermsg
    bind msg - .beer FetchBeer::beermsg
    bind dcc m updatebeer FetchBeer::update
    bind time - "00 00 % % %" FetchBeer::update
    
    # SCRIPT
    set scriptVersion 1.5
    
    # Send message to channel
    proc beerpub {nick uhost handle chan text} {
        variable channels
        if {[lsearch $channels $chan] > -1} {
            # use argument as nick if defined, else use nick
            if {$text == ""} {
                set outnick $nick
            } else {
                set outnick $text
            }
            putserv "PRIVMSG $chan :ACTION [FetchBeer::randombeer $outnick]";
        }
    }
    
    # Send message to nick
    proc beermsg {nick uhost handle text} {
        # putlog "Beer requested by $nick"
        putserv "PRIVMSG $nick :[FetchBeer::randombeer $nick]";
    }
    
    # Get random beer from list
    proc randombeer {nick} {
        # putlog "Random beer for $nick"
        variable cachefile
        variable verbs
        variable containers
        set cachefileHandle [open $cachefile]
        set beerlist [read $cachefileHandle]
        set index [expr {round([expr {rand() * ([llength $beerlist] - 1)}])}]
        # set index 10
        set id [lindex [lindex $beerlist $index] 0]
        set beer [lindex [lindex $beerlist $index] 1]
        close $cachefileHandle
        unset cachefileHandle
        set verb [lindex $verbs [expr {round([expr {rand() * ([llength $verbs] - 1)}])}]]
        set container [lindex $containers [expr {round([expr {rand() * ([llength $containers] - 1)}])}]]
        if {[string index $nick [expr [string length $nick] - 1]] == "a" ||
                [string index $nick [expr [string length $nick] - 1]] == "e" ||
                [string index $nick [expr [string length $nick] - 1]] == "i" ||
                [string index $nick [expr [string length $nick] - 1]] == "o" ||
                [string index $nick [expr [string length $nick] - 1]] == "u" ||
                [string index $nick [expr [string length $nick] - 1]] == "y" ||
                [string index $nick [expr [string length $nick] - 1]] == "ä" ||
                [string index $nick [expr [string length $nick] - 1]] == "ö" ||
                [string index $nick [expr [string length $nick] - 1]] == "å"} {
            set fmt1 "%s %s %s %slle"
        } else {
            set fmt1 "%s %s %s %s:lle"
        }
        set output [format $fmt1 $verb $beer $container $nick]
        return $output
    }

    # Refresh beer list
    proc update {args} {
        set startTime [clock clicks -milliseconds]
        variable listUrl
        variable cachefile
        variable resultregexp
        variable beerregexp
        variable tempdir
        putlog "Update beerlist from $listUrl"
        # open cache file (and create if doesn't exist)
        set cachefileHandle [open $cachefile w+]
        # get first page
        set pagelist [list]
        set tempfile "olutopas.html"
        if {[catch {exec curl --url $listUrl --output $tempdir$tempfile} results]} {
            set f [open $tempdir$tempfile]
            set listfile [read $f]
            # get pagenumbers
            foreach {full submatch} [regexp -all -nocase -inline $resultregexp $listfile] {
                lappend pagelist $submatch
            }
            lsort -integer $pagelist
            # get beer from first page
            foreach {full id name} [regexp -all -nocase -inline $beerregexp $listfile] {
                puts $cachefileHandle [list [list $id $name]]
            }
            # close & delete temp file
            close $f
            unset f
            file delete -force $tempdir$tempfile
        }
        # get beers from all the pages (remove last page because the "next page" link)
        foreach page [lrange $pagelist 0 end-1] {
            set page "&resultpage=$page"
            set tempfile "olutopas$page.html"
            if {[catch {exec curl --url $listUrl$page --output $tempdir$tempfile} results]} {
                set pagefile [open $tempdir$tempfile]
                set pagedata [read $pagefile]
                foreach {full id name} [regexp -all -nocase -inline {\<a href=\"\/olut\/([0-9]*)\/[^\"]*\" target=\"leftFrame\"\>([^\<]*)\<\/a\>} $pagedata] {
                    puts $cachefileHandle [list [list $id $name]]
                }
                # close & delete tempfile
                close $pagefile
                unset pagefile
                file delete -force $tempdir$tempfile
            }
        }
        # close cachefile
        close $cachefileHandle
        unset cachefileHandle
        putlog "Beerlist updated in [expr ([clock clicks -milliseconds] - $startTime) / 1000] seconds"
    }
    putlog "Initialize FetchBeer v$scriptVersion"
    FetchBeer::update
}
