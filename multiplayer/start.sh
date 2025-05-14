#!/bin/bash

# make sure we got a baseurl argument
if [ -z "$1" ]; then
    echo "Usage: $0 <baseurl>"
    exit 1
fi

# first make sure all players have folders
mkdir -p blueos1 blueos2 blueos3 blueos4
# then copy eeprom.bin and bag-of-holding to individual player folders
cp eeprom.bin bag-of-holding blueos1/
cp eeprom.bin bag-of-holding blueos2/
cp eeprom.bin bag-of-holding blueos3/
cp eeprom.bin bag-of-holding blueos4/

# now, for each file, replace $IFRAME_URL with the base url, followed by `?player=1`, `?player=2`, `?player=3`, or `?player=4`
sed -i '' "s,\$IFRAME_URL,$1?player=1," blueos1/bag-of-holding
sed -i '' "s,\$IFRAME_URL,$1?player=2," blueos2/bag-of-holding
sed -i '' "s,\$IFRAME_URL,$1?player=3," blueos3/bag-of-holding
sed -i '' "s,\$IFRAME_URL,$1?player=4," blueos4/bag-of-holding

# then start the docker compose
docker compose up -d