## L0G-101086 Automated log uploads

This repository contains several utilities designed to ease uploading logs
created by [ArcDPS](https://www.deltaconnected.com/arcdps/) to both the
[dps.report](https://dps.report/) and [GW2 Raidar](https://www.gw2raidar.com/)
websites.

It was originally intended for personal use, but some interested has been
shown for publicizing it.

It probably won't work on its out out of the box, so you may need to perform
some work to get it functioning.

In general the scripts are written with paths as if these scripts are stored at
"%UserProfile%\Documents\Guild Wars 2\addons\arcdps", so most paths are based
on this location. You may need to adjust these as necessary.

### update-arcdps.ps1

This script is the most likely to function out of the box. It is used to update
the ArcDPS dll and associated plugins. Because I happen to use GW2 Launch Buddy
somtimes in -nopatchui mode, it stores the dlls in both the top level and \bin64
directory of the Guild Wars 2 installation.

### upload-logs.ps1

This script is provided as a means to upload evtc files to both dps.report and
gw2raidar every time you click it. It stores the timestamp of last upload so
that it doesn't waste time re-uploading files that have already been uploaded.

Because of it's use in connection to format-encounters.ps1, it also uses the
simpleArcParse C++ program to parse the evtc files and store data into a special
folder. This can be configured as documented in the script.

Currently, the script finds all new evtc logs in the arcdps.cbtlogs folder,
scans them with simpleArcParse, uploads them to gw2raidar, and then uploads them
to dps.report

##### Finding files

To find the files, it assumes encounters are stored in arcdps.cbtlogs as defined
in the script. It will find only Zipped encounters, so you must check that box
in the arcdps settings. It recursively searches, so you can have any of the
options for enabling extra path sections enabled *or* disabled.

##### simpleArcParse

One of the major problems with this project was correlating dps.report links
with the gw2raidar links. Because the gw2raidar links are not generated right
away, but instead requested through a separate API, it was challenging to
correlate data for these files.

To do so, the simpleArcParse program was created. This program is used to scan
uncompressed evtc files and extract data such as player names, success/failure,
encounter type, and the encounter start time.

These are stored into the arcdps.uploadextras folder by default (configurable
within the upload-logs.ps1 and format-encounters.ps1 scripts) as JSON data.

##### uploading to gw2raidar

In order to upload to gw2raidar, you will need to get an account and generate an
API token. This can be done after logging in by using the online [API
site](https://www.gw2raidar.com/api/v2/swagger#/token "GW2 Raidar API")

You may need to visit [gw2raidar](https://gw2raidar.com) and login first.

This token must be set in both the upload-logs.ps1 and format-encounters.ps1
scripts.

The script will upload all logs to gw2raidar, and by default will not provide
tags or set the category. You may modify the script to automatically insert tags
and category information as shown in the comments of upload-logs.ps1

##### uploading to dps.report

The dps.report site does not use a formal account, so currently the dps.report
token is just a magic string which may be used in future API additions. You can
set this to any random string of sufficient length as far as I understand.

Currently, because it is rather hard to dig up the dps.report links, as compared
to gw2raidar, the script defaults to only uploading successful logs to
dps.report.


### format-encounters.ps1

This script is used to generate a report and post it to a discord webhook. This
report uses the discord webhook embeds API, and generates a nice fancy post with
links to each dps.report and gw2raidar encounter link. Additionally, it shows
the discord names (or usernames in italics, if no discord name is known) for all
the accounts which participated in the raids.

The format will combine multiple boss kills into one post if they occur on the
same day, and will spread out each different days logs to separate posts.

In order for this to function, you must set the gw2raidar API token up.
Additionally, you usually must wait a few minutes after running the
upload-logs.ps1 script before gw2raidar will be done processing logs and have
them available with permalinks.

This script is heavily dependent on the output of data created by
upload-logs.ps1, specfically the mapping data created between server time and
the local evtc file name.

### simpleArcParse

This program is a very simple bare bones parser based off of the data on
[arcdps](https://www.deltaconnected.com/arcdps/evtc/README.txt "arcdps evtc
README.txt")

It does minimal work to parse the events and find player names, the combat start
time, and the success/failure status of the encounter.

Rather than storing this data in a real database, it is stored in a series of
subfolders as described in the comments of upload-logs.ps1

It is not a complete parser and is intended only to run as efficiently as
possible to generate the required minimal output.

### configuration

These scripts are configured using a simple JSON based file format in a file
called "l0g-101086-config.json". The relevant variables should be well
documented in each script file. The "l0g-101086-config.sample.json" is provided
as a basic outline of what needs to be included. You *must* insert a gw2raidar
token, and a webhook URL, and you probably want to update several of the paths.

The scripts understand how to parse %UserProfile% in paths, but currently no
other folder shorthands are supported.

### Questions?

I'll probably respond to GitHub issues raised here, or you can find me on
discord at @serenamyr#8942, reddit at /u/platinummyr or in GuildWars 2 at
"Serena Sedai.3064"
