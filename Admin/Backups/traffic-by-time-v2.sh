#!/bin/bash

############################################
#                                          #
#          traffic-by-time.sh              #
#                  v 2                     #
#                                          #
############################################

# Establish the start date and time
start=$(date --date="5 min ago" +"%Y-%m-%dT%H:%M:00Z")
start=$(sed 's/:/%3A/g' <<< "$start")
echo $start

# Establish the end date and time
end=$(date +"%Y-%m-%dT%H:%M:00Z")
end=$(sed 's/:/%3A/g' <<< "$end")
echo $end

# Make the initial call
#http -p 'b' --auth-type edgegrid -a default: ':/reporting-api/v1/reports/todaytraffic-by-time/versions/1/report-data?start=2022-11-16T04%3A00%3A00Z&end=2022-11-16T04%3A05%3A00Z&interval=FIVE_MINUTES&objectIds=1350261,1350262,1376394,1360975'

# Using start and end variables
http -p 'b' --auth-type edgegrid -a default: ':/reporting-api/v1/reports/todaytraffic-by-time/versions/1/report-data?start=2022-11-17T19%3A00%3A00Z&end=2022-11-17T19%3A05%3A00Z&interval=FIVE_MINUTES&objectIds=1350261,1350262,1376394,1360975'



# Isolate the data of interest
bytesOffload=$(cat apidata | awk '{print $9}' | awk -F',' '{print $8}' | awk -F'"' '{print $4}')
edgeBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $9}' | awk -F'"' '{print $4}')
edgeHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $10}' | awk -F'"' '{print $4}')
hitsOffload=$(cat apidata | awk '{print $9}' | awk -F',' '{print $11}' | awk -F'"' '{print $4}')
midgressBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $12}' | awk -F'"' '{print $4}')
midgressHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $13}' | awk -F'"' '{print $4}')
originBitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $14}' | awk -F'"' '{print $4}')
originHitsPerSecond=$(cat apidata | awk '{print $9}' | awk -F',' '{print $15}' | awk -F'"' '{print $4}')

# Display the data for sanity check
echo "bytesOffload = $bytesOffload"
echo "edgeBitsPerSecond = $edgeBitsPerSecond"
echo "edgeHitsPerSecond = $edgeHitsPerSecond"
echo "hitsOffload = $hitsOffload"
echo "midgressBitsPerSecond = $midgressBitsPerSecond"
echo "midgressHitsPerSecond = $midgressHitsPerSecond"
echo "originBitsPerSecond = $originBitsPerSecond"
echo "originHitsPerSecond = $originHitsPerSecond"

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

exit 0
