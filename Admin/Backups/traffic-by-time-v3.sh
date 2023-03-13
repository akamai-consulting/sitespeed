#!/bin/bash

############################################
#                                          #
#          traffic-by-time.sh              #
#                  v 3                     #
#                                          #
############################################

echo "|================================================================="
echo "| Start: $(TZ='America/New_York' date): $0"
echo "|================================================================="

# Establish start date and time
start=$(date --date="5 min ago" +"%Y-%m-%dT%H:%M:00Z")
startmin=$(date --date="5 min ago" +"%M")
startmin=$((($startmin%5)+5))
adjstart=$(date --date="$startmin min ago" +"%Y-%m-%dT%H:%M:00Z")
adjstart=$(sed 's/:/%3A/g' <<< "$adjstart")

# Establish end date and time
end=$(date +"%Y-%m-%dT%H:%M:00Z")
endmin=$(date +"%M")
endmin=$(($endmin%5))
adjend=$(date --date="$endmin min ago" +"%Y-%m-%dT%H:%M:00Z")
adjend=$(sed 's/:/%3A/g' <<< "$adjend")

# Assemble the HTTPie command
part1="/usr/local/bin/http --ignore-stdin -p 'b' -d -o apidata --auth-type edgegrid -a default: ':/reporting-api/v1/reports/todaytraffic-by-time/versions/1/report-data?"
part2="start=$adjstart&end=$adjend&interval=FIVE_MINUTES&objectIds=1350261,1350262,1376394,1360975'"
fullcmd=$part1$part2

# Execute the http API call
eval $fullcmd

# Isolate the data of interest
bytesOffload=$(cat apidata | awk '{print $9}' | awk -F',' '{print $8}' | awk -F'"' '{print $4}')
edgeBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $9}' | awk -F'"' '{print $4}')
edgeHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $10}' | awk -F'"' '{print $4}')
hitsOffload=$(cat apidata | awk '{print $9}' | awk -F',' '{print $11}' | awk -F'"' '{print $4}')
midgressBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $12}' | awk -F'"' '{print $4}')
midgressHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $13}' | awk -F'"' '{print $4}')
originBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $14}' | awk -F'"' '{print $4}')
originHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $15}' | awk -F'"' '{print $4}')

# Store data in Graphite
echo "traffic_by_day.bytesOffload $bytesOffload `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.edgeBitsPerSecond $edgeBitsPerSecond `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.edgeHitsPerSecond $edgeHitsPerSecond `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.hitsOffload $hitsOffload `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.midgressBitsPerSecond $midgressBitsPerSecond `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.midgressHitsPerSecond $midgressHitsPerSecond `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.originBitsPerSecond $originBitsPerSecond `date +%s`" | nc -q 1 localhost 2003
echo "traffic_by_day.originHitsPerSecond $originHitsPerSecond `date +%s`" | nc -q 1 localhost 2003

# Cleanup
rm apidata
