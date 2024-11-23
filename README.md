# bitmagnet-scripts
Yeah this is basically just one script, yeah its AI generated but frankly I just needed something that worked for me and I didnt want to spend an entire day trying to figure this out. 

## MagneticoJSONimport

Mostly broken shell script to auto import the json files that [magnetico2bitmagnet](https://github.com/DyonR/magnetico2bitmagnet/tree/main/magnetico2bitmagnet) spits out. 
Options:
1. Import all files automatically
2. Select files to import

Default delay per file: 5 minutes
This is done to give bitmagnet time to process and classify the batch before moving on. It should be used only if you have problems with "out of memory" errors with magnetico2bitmaget. Magnetico2database can also be used to pipe directly to the bitmagnet database and should be a viable option over this script. 
### Usage:
Change the bitmagnet URL at the top of the file, and then:

`./magneticoJSONimport /path/to/folder/with/jsons (--delay=300)`

## AnimeToshoImporter

Edit the file to imports name, and the output folder if you want. Should work by default. Requires `jq` to be installed (apt install jq). It doesnt check for duplicates or anything other than a valid "magnet:" link, and non empty values in all 3 fields. Warning: This has not been tested beyond the 11/22/24 AnimeTosho dump, also its pretty slow so hope you have some extra time on your hands.
