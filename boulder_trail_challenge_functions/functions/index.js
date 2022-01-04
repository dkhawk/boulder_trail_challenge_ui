"use strict";
Object.defineProperty(exports, "__esModule", {
    value: true
});
exports.processGencodedFiles = void 0;

// Cloud Functions for processing activities
// https://firebase.google.com/docs/functions/write-firebase-functions

// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to access Firestore.
const admin = require('firebase-admin');
admin.initializeApp();

const path = require('path');
const os = require('os');
const fs = require('fs');

const GeographicLib = require("geographiclib");
var geod = GeographicLib.Geodesic.WGS84, r;

const grid = require('./grid-data.json');
const encodedSegments = require('./encoded-segments.json');

const minLat = grid.bounds.minLatitude;
const minLng = grid.bounds.minLongitude;

const latDegrees = grid.bounds.maxLatitude - grid.bounds.minLatitude;
const lngDegrees = grid.bounds.maxLongitude - grid.bounds.minLongitude;

const width = grid.width;
const height = grid.height;

const MATCH_THRESHOLD = 0.80;

var segmentData = {};

var trailSegments = calculateAllTrailStats();

const db = admin.firestore();

var btcApi = {
    getTrailStats: async(athleteId) => {
        var results = new Map();

        const trailStatsRef = db.collection('athletes').doc(athleteId).collection('trailStats');
        const trailStats = await trailStatsRef.get();

        trailStats.forEach((doc) => {
            results.set(doc.id, doc.data());
        });

        return results;
    },
    updateStats: async(athleteId, updatedTrails, updatedStats) => {
        // Get a new write batch
        const batch = db.batch();

        const athleteRef = db.collection('athletes').doc(athleteId);
        const trailStatsRef = athleteRef.collection('trailStats');

        batch.update(athleteRef, {
            'overallStats': updatedStats
        });

        for (let[trailId, trail]of updatedTrails.entries()) {
            let trailDoc = trailStatsRef.doc(trailId);
            batch.set(trailDoc, trail);
        }

        // Commit the batch
        await batch.commit();
    },
    writeCompletedSegments: async(segments, athleteId) => {
        const batch = db.batch();
        const athleteRef = db.collection('athletes').doc(athleteId);
        const completedRef = athleteRef.collection('completed');

        segments.forEach(segment => {
            let completedSegment = {
                segmentId: segment.segmentId,
                length: segment.length,
                trailId: segment.trailId,
                trailName: segment.trailName,
            };

            let compDoc = completedRef.doc(segment.segmentId);
            batch.set(compDoc, completedSegment);

            console.log(`writeCompletedSegments: ${segment.trailName} segID: ${segment.segmentId} length: ${segment.length}`);
        });
        await batch.commit();
    },
}

exports.processGencodedFiles = functions.firestore
    .document('athletes/{athlete}/importedData/UploadStats')
    .onUpdate(async(change, context) => {

    var athleteId = context.params.athlete;
    console.log(`processGencodedFiles: processing imported data for athlete <==> ${athleteId}`);

    // console.log(`processGencodedFiles: latDegrees ${latDegrees}   lngDegrees ${lngDegrees}`);
    // console.log(`processGencodedFiles: minLat ${minLat}           minLng ${minLng}`);
    // console.log(`processGencodedFiles: width ${width}             height ${height}`);

    const importedSegsRef = db.collection('athletes').doc(athleteId).collection('importedData');
    let importedSegs = await importedSegsRef.get();

    var filesProcessed = 0;
    let totalCompletedSegments = [];
    await Promise.all(importedSegs.docs.map(async(doc) => {
            if (doc.id.endsWith('.gencoded') == true) {
                console.log(`gencoded importedSegs docId: ${doc.id} <==> ${doc.data().originalFileName} <> ${doc.data().processed} `);
            } else {
                console.log(`uploadStats: total number of files uploaded to date <==> ${doc.data().numFilesUploaded}`);
            }

            if ((doc.id.endsWith('.gencoded') == true) && (doc.data().processed == false)) {
                console.log(`... processing`);
                var timestamp = doc.data().gpxDateTime;
                var encoded = doc.data().encodedLocation;

                if ((encoded != null) && (encoded.length)) {
                    var locations = decode(encoded);
                    // console.log(`... locations: srt ${locations[0]}`);
                    // console.log(`... locations: end ${locations[locations.length - 1]}`);

                    let completedSegments = [];
                    completedSegments = await processActivity(locations, athleteId, 0, timestamp);
                    //console.log(`Number of completedSegments: ${completedSegments.length}`);

                    // write these completed segments into the database
                    // - note that only 500 segments can be written in one batch
                    await btcApi.writeCompletedSegments(completedSegments, athleteId);

                    // concatenate all completedSegments
                    totalCompletedSegments.push(...completedSegments);

                    filesProcessed = filesProcessed + 1;
                    console.log(`... done processing ${athleteId} activity at ${timestamp} ; completedSegments ${completedSegments.length} ${totalCompletedSegments.length}; filesProcessed ${filesProcessed}`);

                } else {
                    console.log(`... cannot process ${athleteId} activity at ${timestamp} ; encoded path is empty`);
                }
            }
        }));

    console.log(`totalCompletedSegments  length for this group of uploads ${totalCompletedSegments.length}`);
    console.log(`processGencodedFiles: processed file count <==> ${filesProcessed}`);

    // Load trail data from database
    let trailStats = await btcApi.getTrailStats(athleteId);

    // Write stats and segments
    var updatedTrails = await calculateCompletedStats(totalCompletedSegments, trailStats);
    var updatedStats = calculateOverallStats(updatedTrails);

    await btcApi.updateStats(athleteId, updatedTrails, updatedStats);

    // Delete processed files
    // const batch = db.batch();
    // importedSegs.forEach((doc) => {
    //     if (doc.id.endsWith('.gencoded') == true) {
    //         var docName = `${doc.id}`;
    //         console.log(`delete docName: ${docName}`);
    //         const res = db.collection('athletes').doc(athleteId).collection('importedData').doc(docName);
    //         batch.delete(res);
    //     }
    // })
    // await batch.commit();

    return filesProcessed;
});

function candidateSegments(activity) {
    const coordsSet = new Set(activity.map(location => locationToCoordinates(location)));

    const segSet = new Set();
    const coords = coordsSet.forEach(function (cString) {

        //console.log(`candidateSegments: cString ${cString}`);
        const cellSegments = grid.coordinatesToSegments[cString];

        if (cellSegments) {
            //console.log(`candidateSegments: cellSegments ${cellSegments}`);
            cellSegments.forEach(function (seg) {
                segSet.add(seg);
            });
        }
    });

    return [...segSet];
}

function locationToCoordinates(location) {

    const y = Math.floor(((location[0] - minLat) / latDegrees) * height);
    const x = Math.floor(((location[1] - minLng) / lngDegrees) * width);
    // console.log(`locationToCoordinates: location[0] ${location[0]}  location[1] ${location[1]}, x ${x} y ${y}`);

    return `${x},${y}`;
}

function processActivity(activity, athleteId, activityId, timestamp) {
    const segments = candidateSegments(activity);
    const finishedSegments = scoreSegments(activity, segments);
    let completedSegments = [];
    if (finishedSegments.length > 0) {
        for (let segmentId of finishedSegments) {
            //console.log(`processActivity: finishedSegment with ID ${segmentId}`);
            completedSegments.push(mapToCompletedSegment(segmentId, activityId, timestamp));
        }
    }

    console.log(`processActivity: ${completedSegments.length}`);
    return completedSegments;
}

function calculateOverallStats(trailStats) {
    let totalDistance = 0;
    let completedDistance = 0;
    for (let[trailId, trail]of trailStats) {
        totalDistance += trail.length;
        completedDistance += trail.completedDistance;
    }
    let percent = (completedDistance * 1.0) / totalDistance;

    return {
        completedDistance: completedDistance,
        totalDistance: totalDistance,
        percentDone: percent,
    };
}

async function calculateCompletedStats(completedSegments, trailStats) {
    // Create a map of all the trails
    let unfinishedTrails = new Map();
    for (const[key, trail]of Object.entries(trailSegments)) {
        let stats = {
            name: trail.name,
            length: trail.length,
            remaining: trail.segments,
            completed: [],
            completedDistance: 0,
            percentDone: 0,
            finishedTimeStamp: 0,
        };
        unfinishedTrails.set(trail.trailId, stats);
    }

    // Create a map of total progress using the old stats if they exist, otherwise the unfinished stats
    let trailProgress = new Map();
    for (const[key, trail]of unfinishedTrails) {
        if (trailStats.has(key)) {
            trailProgress.set(key, trailStats.get(key));
        } else {
            trailProgress.set(key, trail);
        }
    }

    completedSegments.forEach(segment => {
        // Look up the trail
        let stats = trailProgress.get(segment.trailId);

        // Update with the newly completed segments
        const index = stats.remaining.indexOf(segment.segmentId);
        if (index > -1) {
            stats.remaining.splice(index, 1);
        }
        const ci = stats.completed.indexOf(segment.segmentId);
        if (ci < 0) {
            stats.completed.push(segment.segmentId);
            stats.completedDistance += segment.length;
            stats.percentDone = (stats.completedDistance * 1.0) / stats.length;
            stats.finishedTimeStamp = segment.timestamp;
        }
        trailProgress.set(segment.trailId, stats);
    });

    return trailProgress;
}

function calculateAllTrailStats() {
    let tsegments = {};

    for (let segmentId in encodedSegments) {
        let segment = encodedSegments[segmentId];
        let trail = tsegments[segment.trailId] || {
            trailId: segment.trailId,
            name: segment.name,
            segments: [],
            length: 0,
        };

        trail.segments.push(segment.segmentId);
        trail.length += segment.length;
        tsegments[segment.trailId] = trail;
    }

    return tsegments;
}

function getSegmentsForTrail(trailId) {
    return trailSegments[trailId];
}

function mapToCompletedSegment(segmentId, activityId, timestamp) {
    let segment = encodedSegments[segmentId];
    let completedSegment = {
        activityId: activityId,
        segmentId: segmentId,
        trailId: segment.trailId,
        trailName: segment.name,
        timestamp: timestamp,
        length: segment.length,
    };

    return completedSegment;
}

function getSegmentLocations(segmentId) {
    let locations = segmentData[segmentId];
    if (locations) {
        return locations;
    }
    let encoded = encodedSegments[segmentId].encodedLocations;
    locations = decode(encoded);
    segmentData[segmentId] = locations;
    return locations;
}

function decode(encoded) {
    const mask = ~0x20;

    var part = [];
    var parts = [];
    for (var c of encoded) {
        var b = c.charCodeAt() - 63;
        part.push(b & mask);
        if ((b & 0x20) != 0x20) {
            parts.push(part);
            part = [];
        }
    }

    if (part.length) {
        parts.push(part);
    }

    var lastLat = 0.0;
    var lastLng = 0.0;
    var count = 0;

    var polyline = [];

    for (var p of parts) {
        let value = 0;
        let reversed = p.reverse();
        for (let b of reversed) {
            value = (value << 5) | b;
        }
        var invert = (value & 1) == 1;
        value = value >> 1;
        if (invert) {
            // value = -value;
            // this should be the ~ operator (rather than negative) to invert the encoding of the int but unfortunately
            // cannot get ~ to work correctly on Chrome w/o jumping through some hoops
            value = Number(~BigInt(value));
        }
        var result = value / 1E5;

        if (count % 2 == 0) {
            lastLat += result;
        } else {
            lastLng += result;
            polyline.push([lastLat, lastLng]);
        }
        count++;
    }

    return polyline;
}

function scoreSegments(activity, segments) {
    // Calculate the bounds of the activity
    let bounds = boundsForLocations(activity);
    let llGrid = new LatLngGrid(bounds);

    let tiles = new Set(activity.map(location => llGrid.locationToTileCoordinates(location).toString()));
    let fatTiles = new Set();

    for (let tile of tiles) {
        let neighbors = getNeighbors(tile);
        for (let neighbor of neighbors) {
            fatTiles.add(neighbor.toString());
            //console.log(`scoreSegments: fatTiles: tile ${tile.toString()}   neighbor ${neighbor.toString()}`);
        }
    }

    let completedSegments = [];
    let localcount = 0;
    for (let segmentId of segments) {

        console.log(`scoreSegments: testing segmentId ${segmentId}`);
        let locations = getSegmentLocations(segmentId);
        localcount = 0;
        for (let location of locations) {
          
            let coords = llGrid.locationToTileCoordinates(location).toString();

            if (fatTiles.has(coords)) {
                localcount = localcount + 1;
                // if(segmentId == '102-444-445')
                // {
                //    console.log(`    location ${location} match ${coords}`);
                // }                
            }
            // else
            // {
            //     if(segmentId == '102-444-445')
            //     {
            //        console.log(`    location ${location} no match ${coords}`);
            //     }
            // }
        }

        let score = 0;
        if (locations.length > 0)
            score = (localcount * 1.0) / locations.length;

        console.log(`                   ... score ${score} localcount ${localcount} length ${locations.length} for ${segmentId}`);

        if (score >= MATCH_THRESHOLD) {
            completedSegments.push(segmentId);
            console.log(`                   ... Completed ${segmentId} matched`);
        } else {
            console.log(`                   ... Completed ${segmentId} no match`);
        }
    }

    //console.log(`scoreSegments: scored a total of ${completedSegments.length} segments`);
    return completedSegments;
}

class LatLngBounds {
    constructor(minLat, minLng, maxLat, maxLng) {
        this.minLat = minLat;
        this.minLng = minLng;
        this.maxLat = maxLat;
        this.maxLng = maxLng;

        //console.log(`LatLngBounds: minLat minLng maxLat maxLng ${minLat}, ${minLng}, ${maxLat}, ${maxLng} `);

        // southwest to northwest
        r = geod.Inverse(minLat, minLng, maxLat, minLng);
        this.latSpanMeters = r.s12;

        // southwest to southeast
        r = geod.Inverse(minLat, minLng, minLat, maxLng);
        this.lngSpanMeters = r.s12;

        //console.log(`LatLngBounds: latSpanMeters lngSpanMeters ${this.latSpanMeters}, ${this.lngSpanMeters} `);
    }

    getLatitudeSpanMeters() {
        return this.latSpanMeters;
    }

    getLongitudeSpanMeters() {
        return this.lngSpanMeters;
    }
}

function boundsForLocations(locations) {
    const lats = locations.map(l => l[0]);
    const lngs = locations.map(l => l[1]);

    //console.log(`boundsForLocations: ${Math.min(...lats)}, ${Math.min(...lngs)}, ${Math.max(...lats)}, ${Math.max(...lngs)} `);
    return new LatLngBounds(Math.min(...lats), Math.min(...lngs), Math.max(...lats), Math.max(...lngs));
}

class LatLngGrid {
    constructor(bounds) {
        const cellSizeMeters = 20;

        let latMeters = bounds.getLatitudeSpanMeters();
        let lngMeters = bounds.getLongitudeSpanMeters();

        //console.log(`LatLngGrid latMeters lngMeters: ${latMeters}, ${lngMeters} `);

        let northSouthDegrees = bounds.maxLat - bounds.minLat;
        let eastWestDegrees = bounds.maxLng - bounds.minLng;

        //console.log(`LatLngGrid northSouthDegrees eastWestDegrees: ${northSouthDegrees}, ${eastWestDegrees} `);

        this.nsNumCells = Math.ceil(latMeters / cellSizeMeters);
        this.ewNumCells = Math.ceil(lngMeters / cellSizeMeters);


        //console.log(`LatLngGrid nsNumCells ewNumCells: ${this.nsNumCells}, ${this.ewNumCells} `);

        let latDegreesPerCell = northSouthDegrees / this.nsNumCells;
        let lngDegreesPerCell = eastWestDegrees / this.ewNumCells;

        //console.log(`LatLngGrid latDegreesPerCell lngDegreesPerCell: ${latDegreesPerCell}, ${lngDegreesPerCell} `);

        // This is to make the grid one cell bigger in each dimension

        this.minLat = bounds.minLat - latDegreesPerCell;
        let maxLat = bounds.maxLat + latDegreesPerCell;
        this.minLng = bounds.minLng - lngDegreesPerCell;
        let maxLng = bounds.maxLng + lngDegreesPerCell;

        this.latDegrees = maxLat - this.minLat;
        this.lngDegrees = maxLng - this.minLng;

        //console.log(`LatLngGrid latDegrees lngDegrees: ${this.latDegrees}, ${this.lngDegrees} `);

    }

    locationToTileCoordinates(location) {
        let y = Math.round(((location[0] - this.minLat) / this.latDegrees) * this.nsNumCells);
        let x = Math.round(((location[1] - this.minLng) / this.lngDegrees) * this.ewNumCells);

        //console.log(`locationToTileCoordinates y x : ${y}, ${x} location ${location[0]} ${location[1]} minLat ${this.minLat} latDeg ${this.latDegrees} nsNumCells ${this.nsNumCells}`);
        return new Coordinates(x, y);
    }
}

class Coordinates {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }

    toString() {
        return `${this.x},${this.y}`;
    }

    getNeighbors() {
        let yy;
        let xx;

        const result = [];
        for (yy = this.y - 1; yy <= this.y + 1; ++yy) {
            for (xx = this.x - 1; xx <= this.x + 1; ++xx) {
                result.push(new Coordinates(xx, yy));
            }
        }
        return result;
    }
}

function getNeighbors(locString) {
    const coordString = locString.split(",");
    const x = parseInt(coordString[0]);
    const y = parseInt(coordString[1]);

    const c = new Coordinates(x, y);
    return c.getNeighbors();
}
