#!/usr/bin/perl
#  ipod_sync
# (c) Edouard Lafargue <address@hidden>
# 13/03/2010
#
# Bits of this come from the Squeezebox Server software, thanks
# to Logitech for making it (mostly) Open Source. A future version of this routine
# could actually be written as a plugin for Squeezebox Server.
#
# How it works:
# - Load the ipod's GNUTunes Database
# - Initialize the 'to be deleted' list with all songs on iPod
# - Scan the local repository
# - For each song in the local repository:
#   - Get the tags
#   - Remap/clean the tags to our own internal tag names
#   - Find the song on iPod:
#       * If it exists: remove from 'to be deleted' list
#       * Otherwise: add to 'to be added' list
#   - Delete all songs remaining in the 'to be deleted' list
#   - Add all songs in the 'to be added' list
#   - Write GNUPodDB database
#
#####################
#  TODO:
#    - Debug!!!
#    - Cover Art support
#    - Use only Audio::Scan for all tag operations
#    - debug output switch
#    - Support for FLAC & transcode
#    - Use Perldoc format for script documentation
#
######################
#   Operations (eventually):
#     - Synchronize
#     - Update Cover Art only
#     - Simulation mode (no actual add/delete)
#     - Only add / Only delete
#     - Debug
#

my $VERSION=0.1;

# Requires the GNUpod perl packages
use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::FileMagic;
use GNUpod::ArtworkDB;
use Getopt::Long;
use File::Copy;
use File::Glob ':glob';
use Date::Parse;
use Encode;

use vars qw(%opts @keeplist %rename_tags);
use constant MACTIME => GNUpod::FooBar::MACTIME;

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

# This lib seems to be the best with current (2010) ID2 tag versions...
#  but GNUpod uses MP3::Info
use Audio::Scan;

# Taken straight from http://svn.slimdevices.com/repos/slim/7.4/trunk/server/Slim/Formats/MP3.pm
#  and added MP4 tag names as well (no overlap apparently ?)
my %tagMapping = (
    'MUSICBRAINZ ALBUM ARTIST'          => 'ALBUMARTIST',
    'MUSICBRAINZ ALBUM ARTIST ID'       => 'MUSICBRAINZ_ALBUMARTIST_ID',
    'MUSICBRAINZ ALBUM ID'              => 'MUSICBRAINZ_ALBUM_ID',
    'MUSICBRAINZ ALBUM STATUS'          => 'MUSICBRAINZ_ALBUM_STATUS',
    'MUSICBRAINZ ALBUM TYPE'            => 'MUSICBRAINZ_ALBUM_TYPE',
    'MUSICBRAINZ ARTIST ID'             => 'MUSICBRAINZ_ARTIST_ID',
    'MUSICBRAINZ TRM ID'                => 'MUSICBRAINZ_TRM_ID',

    # J.River Media Center uses messed up tags. See Bug 2250
    'MEDIA JUKEBOX: REPLAY GAIN'        => 'REPLAYGAIN_TRACK_GAIN',
    'MEDIA JUKEBOX: ALBUM GAIN'         => 'REPLAYGAIN_ALBUM_GAIN',
    'MEDIA JUKEBOX: PEAK LEVEL'         => 'REPLAYGAIN_TRACK_PEAK',
    'MEDIA JUKEBOX: ALBUM ARTIST'       => 'ALBUMARTIST',

    # bug 10724 - foobar2000 users like to use "ALBUM ARTIST" (instead of
    "ALBUMARTIST")
'ALBUM ARTIST'                      => 'ALBUMARTIST',

# MP4 Tags
ALB => "ALBUM",
ART => "ARTIST",
NAM => "TITLE",
TRKN => "TRACKNUM",

# ID3v2 frame ID mapping to our keywords
# Notes:
# Audio::Scan via libid3tag already converts everything to ID3v2.4 IDs
# so that's all we have to worry about here.
# Non-standard v2.3 tags are prefixed with 'Y'
COMM => "COMMENT",
TALB => "ALBUM",
TBPM => "BPM",
TCOM => "COMPOSER",
TCMP => "COMPILATION",
YTCP => "COMPILATION", # non-standard v2.3 frame
TCON => "GENRE",
TYER => "YEAR",
TDRC => "YEAR",
TDOR => "YEAR",
XDOR => "YEAR",
TIT2 => "TITLE",
TPE1 => "ARTIST",
TPE2 => "BAND",
TPE3 => "CONDUCTOR",
TPOS => "SET",
TRCK => "TRACKNUM",
TSOA => "ALBUMSORT",
YTSA => 'ALBUMSORT',
TSOP => "ARTISTSORT",
YTSP => "ARTISTSORT",      # non-standard iTunes tag
TSOT => "TITLESORT",
YTST => "TITLESORT",       # non-standard iTunes tag
'TST ' => "TITLESORT",     # broken iTunes tag
TSO2 => "ALBUMARTISTSORT",
YTS2 => "ALBUMARTISTSORT", # non-standard iTunes tag
TSOC => "COMPOSERSORT",
YTSC => "COMPOSERSORT",    # non-standard iTunes tag
YRVA => "RVAD",
UFID => "MUSICBRAINZ_ID",
USLT => "LYRICS",
XSOP => "ARTISTSORT",
);

GetOptions (\%opts, "h|help", "s|sync", "mount|m=s", "d|debug",
    "f|front=s", 'b|back=s',
    'c|covers|addcovers',"disable-v2", "disable-v1", "decode",
    "disable-ape-tag", "replaygain-album");

# Check volume adjustment options for sanity
my $min_vol_adj = int($opts{'min-vol-adj'});
my $max_vol_adj = int($opts{'max-vol-adj'});

die &usage if (! scalar @ARGV or $opts{h});
die &usage unless ($opts{s} );

# Native GNUpod version:
GNUpod::FooBar::GetConfig(\%opts, {'replaygain-album'=>'b', 'decode'=>'s',
        'disable-v1'=>'b',
        'disable-v2'=>'b', 'disable-ape-tag'=>'b', 'view'=>'s', mount=>'s',
        'match-once'=>'b', 'automktunes'=>'b', model=>'s'}, "gnupod_search");
$opts{view} ||= 'ialt'; #Default view

usage()   if $opts{help};
version() if $opts{version};

my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

print "Connected\n";

# This array contains all the songs in the ipod, indexed by ID
my @allSongs;
my $idx;

print "Scanning the GNUpod database\n";
# Now parse the GNUTunes XML file. The "newfile" subfunction is called for each song
GNUpod::XMLhelper::doxml($connection->{xml}) or usage("Failed to parse
    $connection->{xml}, did you run gnupod_INIT.pl?\n");
print "...done\n";

print "Found " . scalar @allSongs . " on iPod\n";

#invert the array so that we can easily remove the elements:
my %songList;
foreach my $el (@allSongs) {
    $songList{$el->{id}} = 1 if defined $el;
}

my @newSongs; # List of all songs to add to the iPod

# Then once we scan, we will:
#  - Find all the tracks which exist on the ipod, and remove the correspondig
#     id from the @songs array.
#   - Once this is done, we will delete all the remaining songs on the iPod, since
#     they do not exist on the jukebox
#   - Last, we will copy all the songs which were not found on the iPod from the
#     jukebox to the iPod.
#
#   -> This way we won't need a local DB on the jukebox, and not double-scanning

foreach my $f (@ARGV) {
    if (-d $f) {
        recurse_dir($f);
        next;
    }
    go($f);
}

print "Remaining songs which we should delete: " ;
my $idx = 0;
print "----- DELETING NOW ------\n";
while ( my($id,$exists) = each %songList) {
    $idx++;
    # Should delete the song here...
    my $path = $allSongs[$id]->{path};
    print "$id: $path\n";
    # -> Remove file as requested. If all went well, it is not in the
    # XML database which we'll write later on anyway
    unlink(GNUpod::XMLhelper::realpath($opts{mount},$path)) or warn "[!!] Remove failed: $!\n";
}

print $idx . "\n";

print "----- Now adding those songs ----\n";
my $addcount = 0;
foreach my $song (@newSongs) {
    # The method below is totally outdated, it's still better
    # to add through gnupod_addsong.pl...
    add_song($song);
}

# Now write the iPod database:
GNUpod::XMLhelper::writexml($connection,{automktunes=>$opts{automktunes}});

exit;


#############################################
# Eventhandler for FILE items
#
# Build idx array for quick searching
#
sub newfile {
    my($file)= @_;
    # Add to file index
    @allSongs[$file->{file}->{id}] = $file->{file};
    # Make indexes, convert to utf8
    for (keys %{$file->{file}}) {
        # Don't index the id or uniq (redundant!)
        #print $_ . "\n";
        next if $_ eq 'id' or $_ eq 'uniq';
        push @{$idx->{$_}->{$file->{file}->{$_}}}, $file->{file}->{id};
        warnings::warnif $@ if not defined $file->{file}->{$_};
    }

}

##########
# Main function
#
sub go {
    my $f = shift;
    my $root = shift;

    # Only work on files that end in .mp3
    return if $f eq '.';
    return if $f eq '..';
    return unless -r $f and $f =~ /\.(mp3|m4a)$/i;

    my $s = Audio::Scan->scan( $f );
    my $info = $s->{info};
    my $tags = $s->{tags};
    if ($opts{d}) {
        while (my($tag,$val) = each %$tags) {
            print "Tag: $tag  => " . encode('utf8',$val) . "\n" unless
            ($tag eq
                "APIC" | $tag eq "COVR");
        }
    }

    if ($opts{d}) { print "****** Remapping ******\n";}
    doTagMapping($tags,1);
    if ($opts{d}) {
        while (my($tag,$val) = each %$tags) {
            print "Tag: $tag  => " . encode('utf8',$val) . "\n" unless
            ($tag eq "APIC" | $tag eq "COVR");
        }
    }

    #        s : synchronize the ipod
    # TODO: also use the bitrate as search info, since a track might be identical but
    #       updated with a diferent bitrate on the main repository
    if ($opts{s}) {
        my $goodTrack;
        my @ids;
        # Why why why do I have to explicitely encode to UTF8 ??? The tags seem
        to
        # always be converted to Latin1 ????
        my $artist = encode('utf8',$tags->{ARTIST});
        my $album = encode('utf8',$tags->{ALBUM});
        my $title = encode('utf8',$tags->{TITLE});
        my $track = $tags->{TRACKNUM};
        print "------\nArtist: $artist\nAlbum: $album\nTrack: $track\nTitle:
        $title\n";
        if (nb($track) ) {
            # Track can be weirdly formatted on mp3 tags, so we are
            transforming it into an integer
            $track =~ s/\/[0-9]*//;
            $goodTrack = int($track);
        } else {
            $goodTrack = 0;
        }
        # Now, sometimes the Album is not known, in which case we should not
        include it into the seach terms
        if (nb($album)) {
            @ids = ip_search(artist => $artist, album => $album, title =>
                $title, songnum => $goodTrack, exact =>1);
        } else {
            @ids = ip_search(artist => $artist, title => $title, songnum
                => $goodTrack, exact =>1);
        }
        if (scalar @ids) {
            foreach my $id (@ids) {
                print "----> Found on iPod: ID $id <-----";
                # Remove from deletion db
                delete $songList{$id};
                # Add to the XML to be written at the end:
                my $el;
                $el->{file} = @allSongs[$id];
                GNUpod::XMLhelper::mkfile($el);
            }
        } else {
            print " ***** Not on iPod ! *****";
            push(@newSongs, $f);
        }
        print "\n";
    }
}

sub recurse_dir {
    my $root = shift;

    print "Entering $root\n";

    # bsd_glob handles spaces in file names/paths
    my @files = bsd_glob("$root/*",GLOB_QUOTE);
    foreach my $f (@files) {
        if (-d $f) {
            recurse_dir($f);
            next;
        }
        go($f,$root);
    }
}


### Search for a song in the @allSongs array
# Get a list of ids by search terms
sub ip_search {
    my (%terms) = @_;

    # Pick opts out from terms
    my %opts;
    for ('nocase', 'nometachar', 'exact') {
        $opts{$_} = delete $terms{$_};
    }

    # Main searches
    my %count;
    my $term = 0;
    while (my ($key, $val) = each %terms) {
        for my $idxval (keys %{$idx->{$key}}) {
            if (matches($idxval, $val, %opts)) {
                $count{$_}++ for @{$idx->{$key}->{$idxval}};
            }
        }
        $term++;
    }

    # Get the list of everyone that matched
    # Sort by Artist > Album > Cdnum > Songnum > Title
    return
    sort {
        $allSongs[$a]->{uniq} cmp $allSongs[$b]->{uniq}
    } grep {
        $count{$_} == $term
    } keys %count;
}

# Find if two things match, w/ opts
sub matches {
    my ($left, $right, %opts) = @_;
    no warnings 'uninitialized';
    if ($opts{nocase}) {
        $left = lc $left;
        $right = lc $right;
    }
    if ($opts{nometachar}) {
        $right = quotemeta $right;
    }

    if ($opts{exact}) {
        return $left eq $right;
    }
    else {
        return $left =~ /$right/;
    }
}



# not blank or undef
sub nb {
    my $string = shift;
    return 0 unless defined $string;
    return 0 if $string =~ /^\s*$/;
    return 1;
}

# Add a new song to the database
sub add_song {
    my ($file) = @_;
    #Get the filetype
    my ($fh,$media_h,$converter) =  GNUpod::FileMagic::wtf_is($file,
        {noIDv1=>$opts{'disable-v1'},

            noIDv2=>$opts{'disable-v2'},

            noAPE=>$opts{'disable-ape-tag'},

            rgalbum=>$opts{'replaygain-album'},

            decode=>$opts{'decode'}},$connection);

    unless($fh) {
        warn "* [****] Skipping '$file', unknown file type\n";
        next;
    }

    my $wtf_ftyp = $media_h->{ftyp};      #'codec' .. maybe ALAC
    my $wtf_frmt = $media_h->{format};    #container ..maybe M4A
    my $wtf_ext  = $media_h->{extension}; #Possible extensions (regexp!)
    #Set the addtime to unixtime(now)+MACTIME (the iPod uses mactime)
    #This breaks perl < 5.8 if we don't use int(time()) !
    #Use fixed addtime for autotests
    $fh->{addtime} = int($connection->{autotest} ? 42 :
        time())+MACTIME;

    #Ugly workaround to avoid a warning while running mktunes.pl:
    #All (?) int-values returned by wtf_is won't go above 0xffffffff
    #Thats fine because almost everything inside an mhit can handle this.
    #But bpm and srate are limited to 0xffff
    # -> We fix this silently to avoid ugly warnings while running mktunes.pl
    $fh->{bpm}   = 0xFFFF if $fh->{bpm}   > 0xFFFF;
    $fh->{srate} = 0xFFFF if $fh->{srate} > 0xFFFF;

    # Clamp volume, if any
    my $vol = $fh->{volume} || 0;
    $vol = $min_vol_adj if ($vol < $min_vol_adj);
    $vol = $max_vol_adj if ($vol > $max_vol_adj);
    $fh->{volume} = $vol;

    #Get a path
    ($fh->{path}, my $target) =
    GNUpod::XMLhelper::getpath($connection,
        $file,  {format=>$wtf_frmt, extension=>$wtf_ext,
            keepfile=>$opts{restore}});

    if(!defined($target)) {
        warn "*** FATAL *** Skipping '$file' , no target
        found!\n";
    }
    elsif( File::Copy::copy($file, $target)) {

        # Note to myself: Using utf8() works around some obscure
        # glibc/perl/linux problem
        printf("+ [%-4s][%3d] %-32s | %-32s | %-24s\n",
            uc($wtf_ftyp),1+$addcount,
            Unicode::String::utf8($fh->{title})->utf8,
            Unicode::String::utf8($fh->{album})->utf8,
            Unicode::String::utf8($fh->{artist})->utf8);
        my $id =
        GNUpod::XMLhelper::mkfile({file=>$fh},{addid=>1}); #Try to add an id
        $addcount++;
    }
    else { #We failed..
        warn "*** FATAL *** Could not copy '$file' to
        '$target': $!\n";
        unlink($target); #Wipe broken file
    }
}


# Taken straight from the Squeezebox Server source (http://svn.slimdevices.com/repos/slim/7.4/trunk/server/Slim/Formats/MP3.pm)
sub doTagMapping {
    my ( $tags, $no_overwrite ) = @_;

    $tagMapping{TPE2} = 'BAND';

    while ( my ($old, $new) = each %tagMapping ) {
        if ( exists $tags->{$old} ) {
            # Caller can set $no_overwrite if ID3 tags should not
            replace
            # existing tags, i.e. FLAC tags
            next if $no_overwrite && exists $tags->{$new};

            $tags->{$new} = delete $tags->{$old};
        }
    }

    # Special handling for UFID, pull out ID from array
    if ( exists $tags->{MUSICBRAINZ_ID} && ref $tags->{MUSICBRAINZ_ID} eq
        'ARRAY' ) {
        # Sometimes UFID might be swapped, check every element
        for my $id ( @{ delete $tags->{MUSICBRAINZ_ID} } ) {
            if ( length($id) == 36 ) {
                $tags->{MUSICBRAINZ_ID} = $id;
                last;
            }
        }
    }

    # We only want a 4-digit year
    if ( defined $tags->{YEAR} ) {
        my $year = $tags->{YEAR};

        # In the case where multiple YEAR elements are
        # present (eg multi-value ID3v2.4) we only use
        # the first.
        $year = $year->[0] if ref $year eq 'ARRAY';

        if ( $year =~ /(\d\d\d\d)/ ) {
            $year = $1;
        }

        $tags->{YEAR} = $year;
    }

    # Clean up comments
    if ( $tags->{COMMENT} && ref $tags->{COMMENT} eq 'ARRAY' ) {
        my $fixed = [];

        if ( ref $tags->{COMMENT}->[0] eq 'ARRAY' ) {
            for my $comment ( @{ $tags->{COMMENT} } ) {
                if ( $comment->[2] ) {
                    # Comment has a description
                    push @{$fixed}, $comment->[2] . ': ' .
                    $comment->[3];
                }
                else {
                    push @{$fixed}, $comment->[3];
                }
            }
        }
        else {
            if ( $tags->{COMMENT}->[2] ) {
                push @{$fixed}, $tags->{COMMENT}->[2] . ': ' .
                $tags->{COMMENT}->[3];
            }
            else {
                push @{$fixed}, $tags->{COMMENT}->[3];
            }
        }

        $tags->{COMMENT} = $fixed;
    }

    # Clean up lyrics
    if ( $tags->{LYRICS} && ref $tags->{LYRICS} eq 'ARRAY' ) {
        $tags->{LYRICS} = $tags->{LYRICS}->[3];
    }

    # Flag if we have embedded cover art
    $tags->{HAS_COVER} = 1 if $tags->{APIC};
}


sub usage {
    return << "end_usage";
USAGE: $0 <dir> <cmd> [options]

sync_ipod.pl Version $VERSION

This script is used to synchronize the contents of an iPod with
a local repository.

It does not have any requirement on the local repository (in particular
no local database to maintain).

NOTE: this is a work in progress! Don't use if you don't know what you
are doing.

<COMMANDS>
    -s | --sync      - synchronize the ipod with the local repository


[OPTIONS]
    -d | --debug     - Additional debug output
        -m | --mount     - iPod mountpoint

Edouard Lafargue <address@hidden> 2010.03.13
end_usage
}
