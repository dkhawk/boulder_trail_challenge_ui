// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//

// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to access Firestore.
const admin = require('firebase-admin');
admin.initializeApp();

const GeographicLib = require("geographiclib");
var geod = GeographicLib.Geodesic.WGS84, r;

// const Gpx = require('gpx-parser-builder');
// import Gpx from "gpx-parser-builder";

const grid = require('./grid-data.json');
const encodedSegments = require('./encoded-segments.json');

const minLat = grid.bounds.minLatitude;
const minLng = grid.bounds.minLongitude;

const latDegrees = grid.bounds.maxLatitude - grid.bounds.minLatitude;
const lngDegrees = grid.bounds.maxLongitude - grid.bounds.minLongitude;

const width = grid.width;
const height = grid.height;

const escapeHtml = require('escape-html');

const testActivity = require('./testActivity.json');

var rp = require('request-promise');

const MATCH_THRESHOLD = 0.90;

var segmentData = {};

var trailSegments = {};

const stravaApiCredentials = {
    client_id: '43792',
    client_secret: 'b5cc7b11df2bf0390406f4bcc88592f7944880e9',
};

const db = admin.firestore();

var btcApi = {
    getStravaInfo: async (athleteId) => {
    	return db.collection('athletes').doc(athleteId).get().then(documentSnapshot => {
    	    if (documentSnapshot.exists) {
    		var athlete = documentSnapshot.data();
    		var tokenInfo = athlete.tokenInfo;
    		var accessToken = tokenInfo.access_token;
    		console.log(`tokenInfo.expires_at ${tokenInfo.expires_at}`);
    		var expirationTimeMillis = tokenInfo.expires_at * 1000;

		if (Date.now() >= expirationTimeMillis) {
		    console.log('token has expired');
		    tokenInfo = stravaApi.refreshToken(tokenInfo.refresh_token);
		    accessToken = tokenInfo.access_token;
		    console.log(`New token received: ${accessToken}`);
		}

		console.log(`athlete: ${tokenInfo.athlete.lastname}`);

		return { athlete: tokenInfo.athlete, accessToken: accessToken };
		
    	    } else {
		throw new Error('Failed to get strava token for athlete');
	    }
	})},
    getTrailStats: async (athleteId) => {
	const trailStats = await db.collection('athletes').doc(athleteId).collection('trailStats').get();
	
	var results = {};
	trailStats.forEach(stats => {
	    results[stats.id] = stats.data();
	});

	return results;
    },
    updateStats: async (athleteId, updatedTrails, updatedStats) => {
	// Get a new write batch
	const batch = db.batch();

	const athleteRef = db.collection('athletes').doc(athleteId);
	const trailStatsRef =  athleteRef.collection('trailStats');

	batch.update(athleteRef, {'overallStats': updatedStats});
	for (let trailId in updatedTrails) {
	    let trail = updatedTrails[trailId];
	    let trailDoc = trailStatsRef.doc(trailId);
	    batch.set(trailDoc, trail);
	}

	// Commit the batch
	await batch.commit();
    },
    writeCompletedSegments: async (segments, athleteId, activityId, timestamp) => {
	const batch = db.batch();
	const athleteRef = db.collection('athletes').doc(athleteId);
	const completedRef =  athleteRef.collection('completed');

	segments.forEach(segment => {
	    let completedSegment = {
		activityId: activityId,
		segmentId: segment.segmentId,
		length: segment.length,
		timestamp: timestamp,
		trailId: segment.trailId,
		trailName: segment.trailName,
	    };
	    let compDoc = completedRef.doc(segment.segmentId);
	    batch.set(compDoc, completedSegment);
	});
	await batch.commit();
    },
}

var stravaApi = {
    credentials: stravaApiCredentials,
    getBearerToken: async (btcAthlete) => {
    	return admin.firestore().collection('athletes').doc(btcAthlete).get().then(documentSnapshot => {
    	    if (documentSnapshot.exists) {
    		var athlete = documentSnapshot.data();
    		var tokenInfo = athlete.tokenInfo;
    		var accessToken = tokenInfo.access_token;
    		console.log(`tokenInfo.expires_at ${tokenInfo.expires_at}`);
    		var expirationTimeMillis = tokenInfo.expires_at * 1000;

		if (Date.now() >= expirationTimeMillis) {
		    console.log('token has expired');
		    return 'TODO: this.refreshToken();'; 
		} else {
		    return accessToken;
		}
    	    } else {
		throw new Error('Failed to get strava token for athlete');
	    }
	})},

    refreshToken: async (athleteId, refresh_token) => {
	var options = {
	    method: 'POST',
	    uri: 'https://www.strava.com/api/v3/oauth/token',
	    headers: {
		'User-Agent': 'Request-Promise'
	    },
	    form: {
		client_id: stravaApi.credentials.client_id,
		client_secret: stravaApi.credentials.client_secret,
		refresh_token: refresh_token,
		grant_type: 'refresh_token',
	    },
	};

	rp(options)
	    .then(tokenInfo => {
		console.log('tokenInfo', tokenInfo);
		const tokenObj = JSON.parse(tokenInfo);
		const athleteRef = admin.firestore().collection('athletes').doc(athleteId)
		const res = athleteRef.set({ tokenInfo: tokenObj }, { merge: true });
		res.get();
		return tokenObj;
	    });
    },

    getStats: async (btcAthlete, activityId) => {
	var accessToken = await stravaApi.getBearerToken(btcAthlete);
	
	var options = {
	    method: 'GET',
	    // TODO: sanitize the input!
	    uri: `https://www.strava.com/api/v3/activities/${activityId}/streams`,
	    headers: {
		'User-Agent': 'Request-Promise',
		'accept': 'application/json',
		'authorization': `Bearer ${accessToken}`
	    },
	    qs: {
		keys: 'latlng',
		key_by_type: true 
	    },
	};
	return await rp(options)
	    .then(locationsString => {
		const locations = JSON.parse(locationsString);
		return locations;
	    }); // TODO: handle exception
    },
    
    getActivity: async (btcAthlete, activityId) => {
	var accessToken = await stravaApi.getBearerToken(btcAthlete);
	
	var options = {
	    method: 'GET',
	    // TODO: sanitize the input!
	    uri: `https://www.strava.com/api/v3/activities/${activityId}/streams`,
	    headers: {
		'User-Agent': 'Request-Promise',
		'accept': 'application/json',
		'authorization': `Bearer ${accessToken}`
	    },
	    qs: {
		keys: 'latlng',
		key_by_type: true 
	    },
	};
	return await rp(options)
	    .then(locationsString => {
		const locations = JSON.parse(locationsString);
		return locations;
	    }); // TODO: handle exception

    },
};

exports.helloHttp = functions.https.onRequest(async (req, res) => {
  res.send(`Hello ${escapeHtml(req.query.name || req.body.name || 'World')}!`);
});


// Take the text parameter passed to this HTTP endpoint and insert it into 
// Firestore under the path /messages/:documentId/original
exports.addMessage = functions.https.onRequest(async (req, res) => {
    // Grab the text parameter.
    const original = req.query.text;
    // Push the new message into Firestore using the Firebase Admin SDK.
    const writeResult = await admin.firestore().collection('messages').add({original: original});
    // Send back a message that we've successfully written the message
    res.json({result: `Message with ID: ${writeResult.id} added.`});
});

exports.getStravaInfo = functions.https.onRequest(async (request, response) => {
    const athleteId = request.query.athleteId;

    btcApi.getStravaInfo(athleteId).then(stravaInfo => {
	response.send(`lastname: ${stravaInfo.athlete.lastname}`);
    }).catch(error => {
	response.status(500).send(error);
    });
});

// Take the text parameter passed to this HTTP endpoint and insert it into 
// Firestore under the path /messages/:documentId/original
exports.getStats = functions.https.onRequest(async (request, response) => {
    const athlete = request.query.athlete;

    response.send(`Hello ${escapeHtml(request.query.athleteId || request.body.athleteId || 'World')}!`);

    return;

    // console.log('starting call to firestore');
    // response.send('Just work');

    // return;
    
    // const stats = await admin.firestore().collection('athletes').doc(athlete).get().then(documentSnapshot => {
    // 	console.log('got data from firestore');
    // 	if (documentSnapshot.exists) {
    // 	    console.log('Document retrieved successfully.');
    // 	    const result = documentSnapshot.data();
    // 	    response.send('Just shoot me!'); //.json({result: result});
    // 	} else {
    // 	    console.log('WTF.');
    // 	    response.status(500).send('somthing went wrong');
    // 	}
    // })
    // 	.catch(error => {
    // 	    response.status(500).send(error);
    // 	});
    
    // Push the new message into Firestore using the Firebase Admin SDK.
    // const writeResult = await admin.firestore().collection('messages').add({original: original});
    // Send back a message that we've successfully written the message
    // response.json({result: `stats: ${stats}.`});
});

exports.exchangeTokens = functions.https.onRequest(async (request, response) => {
    // curl http://localhost:5001/boulder-trail-challenge/us-central1/exchangeTokens?athleteId=dkhawk@gmail.com
    // &state=&
    // code=6df81a2936dd9f8d61efc5cb59106eadd16c79d0&scope=read,activity:read

    //  ======= IMPORTANT =======
    // Should probably read the athleteId from a request row in the database.  This would prevent someone from messing with the request flow.

    const btcAthlete = request.query.athleteId;
    const code = request.query.code;
    const scope = request.query.scope;

    var options = {
	method: 'POST',
	uri: 'https://www.strava.com/api/v3/oauth/token',
	headers: {
	    'User-Agent': 'Request-Promise'
	},
	form: {
	    client_id: '43792',
	    client_secret: 'b5cc7b11df2bf0390406f4bcc88592f7944880e9',
	    code: code,
	    grant_type: 'authorization_code',
	},
    };

    rp(options)
	.then(tokenInfo => {
	    console.log('tokenInfo', tokenInfo);
	    const tokenObj = JSON.parse(tokenInfo);
	    const athleteRef = admin.firestore().collection('athletes').doc('dkhawk@gmail.com')
	    const res = athleteRef.set({ tokenInfo: tokenObj }, { merge: true });
	    return res;
	})
	.then(ref => {
	    response.send('Success');
	})
	.catch(error => {
	    response.status(500).send(error);
	});
});

exports.refreshToken = functions.https.onRequest(async (request, response) => {
    const btcAthlete = request.query.athleteId;
    const force = request.query.force;

    console.log(`btcAthlete ${btcAthlete}`);
    console.log(`force ${force}`);

    admin.firestore().collection('athletes').doc('dkhawk@gmail.com').get().then(documentSnapshot => {
	if (documentSnapshot.exists) {
	    console.log('Document retrieved successfully.');
	    var athlete = documentSnapshot.data();
	    var tokenInfo = athlete.tokenInfo;
	    console.log(`tokenInfo.expires_at ${tokenInfo.expires_at}`);
	    var expirationTimeMillis = tokenInfo.expires_at * 1000;
	    console.log(Date.now());
	    if (Date.now() >= expirationTimeMillis) {
		console.log('token has expired');
		
		var options = {
		    method: 'POST',
		    uri: 'https://www.strava.com/api/v3/oauth/token',
		    headers: {
			'User-Agent': 'Request-Promise'
		    },
		    form: {
			client_id: '43792',
			client_secret: 'b5cc7b11df2bf0390406f4bcc88592f7944880e9',
			refresh_token: tokenInfo.refresh_token,
			grant_type: 'refresh_token',
		    },
		};

		rp(options)
		    .then(tokenInfo => {
			console.log('tokenInfo', tokenInfo);
			const tokenObj = JSON.parse(tokenInfo);
			const athleteRef = admin.firestore().collection('athletes').doc('dkhawk@gmail.com')
			const res = athleteRef.set({ tokenInfo: tokenObj }, { merge: true });
			return res;
		    })
		    .then(ref => {
			response.send('Success\n');
		    })
		    .catch(error => {
			response.status(500).send(error);
		    });
	    } else {
		response.send('Token does not need refresh\n');
	    }
	} else {
	    response.send('No such athlete');
	}
    });
});

exports.getActivities = functions.https.onRequest(async (request, response) => {
    const btcAthlete = request.query.athleteId;
    // const after = 1609459200;  // 2021-01-01 0:00.  Need to pass this in as a parameter.
    const after = 1610348400;  // Tuesday, January 11, 2021 12:00:00 AM GMT-07:00

    admin.firestore().collection('athletes').doc(btcAthlete).get().then(documentSnapshot => {
	if (documentSnapshot.exists) {
	    console.log('Document retrieved successfully.');
	    var athlete = documentSnapshot.data();
	    var tokenInfo = athlete.tokenInfo;
	    var accessToken = tokenInfo.access_token;
	    console.log(`tokenInfo.expires_at ${tokenInfo.expires_at}`);
	    var expirationTimeMillis = tokenInfo.expires_at * 1000;

	    // TODO: handle the expired token...
	    
	    //curl -X GET "https://www.strava.com/api/v3/athlete/activities?after=1609459200&per_page=30" -H "accept: application/json" -H "authorization: Bearer 0275e53d4c133d20f8fd628954b031faab7f9cfe"
 
	    var options = {
		method: 'GET',
		uri: 'https://www.strava.com/api/v3/athlete/activities',
		headers: {
		    'User-Agent': 'Request-Promise',
		    'accept': 'application/json',
		    'authorization': `Bearer ${accessToken}`
		},
		qs: {
		    after: after,
		    per_page: 3  // <= This should be 30 when ready
		},
	    };

	    rp(options)
		.then(activitiesString => {
		    // console.log('activities: ', activities);
		    const activities = JSON.parse(activitiesString);
		    // const athleteRef = admin.firestore().collection('athletes').doc('dkhawk@gmail.com')
		    // const res = athleteRef.set({ tokenInfo: tokenObj }, { merge: true });
		    // return res;

		    // TODO: limit this to running, hiking, walking, etc
		    // TODO: outdoor only?
		    // Write this to a work queue
		    // Filter activies that have already been processed!

		    console.log('##################################################################');
		    console.log(`activities ${activities}`);
		    console.log(typeof activities);
		    console.log('==================================================================');
		    console.log(`activities[1] ${activities[1]}`);
		    console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

		    console.log('Just before');
		    const activityIds = activities.map(x => x.id);
		    console.log('Just after');

		    console.log(`activityIds: ${activityIds}`);
		    return activityIds;
		})
		.then(activityIds => {
		    // Seriously, we should only be writing to the work queue here!!!!!
		    const aid = activityIds[1];
		    console.log(`activity to grab: ${aid}`);
		    
	     	    response.send('Success\n');
		})
		.catch(error => {
		    response.status(500).send(error);
		});
	    
	} else {
	    response.status(500).send('No such athlete');
	}
    });
});


exports.processActivity = functions.https.onRequest(async (request, response) => {
    // Check the token expiration first?
    const athleteId = request.query.athleteId;
    const activityId = request.query.activityId;
    const timestamp = admin.firestore.Timestamp.fromDate(new Date('January 20, 2021'));

    // fetchActivity(btcAthlete, activityId);

    await processActivity(testActivity, athleteId, activityId, timestamp);

    response.send('Done\n');
});

async function fetchActivity(btcAthlete, activityId) {
    // Grab the locations stream
    // For testing, just load the file
    
    console.log(`Fetching ${activityId} from Strava`);

    const locations = await stravaApi.getActivity(btcAthlete, activityId).then(activity => {
	return activity['latlng']['data'];
    });

    var str = JSON.stringify(locations, null, 2); // spacing level = 2
    
    console.log(`Got activity: ${str}`);

    // curl -X GET "https://www.strava.com/api/v3/activities/4614101013/streams?keys=latlng&key_by_type=true" -H "accept: application/json" -H "authorization: Bearer fdc42bd57a499c4b4f5db4f0fd43eaede0677323"
    

    // console.log(`${encodedSegments['244-130-127'].name}`);
    // console.log(`${encodedSegments['244-130-127'].length}`);
    // console.log(`${encodedSegments['244-130-127'].encodedLocations}`);

    // "file:///User/Danny/Desktop/javascriptWork/testing.txt"
//    const gpxTrack = readTextFile(
//	'file:///Users/dkhawk/IdeaProjects/boulder_trail_challenge_ui/boulder_trail_challenge_functions/functions/Wonderland_to_Eagle.gpx'
//    );
//
//    const ss = gpxTrack.substring(0,100);
//
//    console.log(`${ss}`);
//    const getTrackPoints = gpxTrack => {
 //     const parsedGpx = Gpx.parse(gpxTrack);
  //    return parsedGpx.trk[0].trkseg[0].trkpt;
   // };

    //console.log(`getTrackPoints: ${getTrackPoints['$'].creator}`);

    // process
    // return result
}


function candidateSegments(activity) {
    var coordsSet = new Set(activity.map(location => locationToCoordinates(location)));

    var segSet = new Set();
    var coords = coordsSet.forEach(function(cString) {
	var cellSegments = grid.coordinatesToSegments[cString];
	if (cellSegments) {
	    cellSegments.forEach(function(seg) {
		segSet.add(seg);
	    });
	}
    });

    return [...segSet];
}

function locationToCoordinates(location) {
    var y = Math.round(((location[0] - minLat) / latDegrees) * height);
    var x = Math.round(((location[1] - minLng) / lngDegrees) * width);

    return `${x},${y}`;
}

async function processActivity(activity, athleteId, activityId, timestamp) {
    // Load trail data from database
    let trailStats = await btcApi.getTrailStats(athleteId);

    var segments = candidateSegments(activity);
    var finishedSegments = scoreSegments(activity, segments);
    let completedSegments = [];
    if (finishedSegments.length > 0) {
	for (let segmentId of finishedSegments) {
	    completedSegments.push(mapToCompletedSegment(segmentId, activityId, timestamp));
	}
    }

    var updatedTrails = await calculateCompletedStats(completedSegments, trailStats);
    var updatedStats = calculateOverallStats(trailStats);

    btcApi.updateStats(athleteId, updatedTrails, updatedStats);
    btcApi.writeCompletedSegments(completedSegments, athleteId, activityId, timestamp);
}

function calculateOverallStats(trailStats) {
    var totalDistance = 0;
    var completedDistance = 0;
    for (let trailId in trailStats) {
	let trail = trailStats[trailId];
	totalDistance += trail.length;
	completedDistance += trail.completedDistance;
    };
    let percent = (completedDistance * 1.0) / totalDistance;

    return {
	completedDistance: completedDistance,
	totalDistance: totalDistance,
	percentDone: percent,
    };
}

async function calculateCompletedStats(completedSegments, trailStats) {
    let updatedTrails = {};
    completedSegments.forEach(segment => {
	// Look up the trail 
	var stats = trailStats[segment.trailId];
	if (!stats) {
	    var trail = getSegmentsForTrail(segment.trailId);
	    stats = {
		name: segment.trailName,
		length: trail.length,
		remaining: [...trail.segments],
		completed: [segmentId],
		completedDistance: 0,
		percentDone: 0,
	    };
	    trailStats[segment.trailId] = stats;
	}

	// Update
	const index = stats.remaining.indexOf(segment.segmentId);
	if (index > -1) {
	    stats.remaining.splice(index, 1);
	}
	const ci = stats.completed.indexOf(segment.segmentId);
	if (ci < 0) {
	    stats.completed.push(segment.segmentId);
	    stats.completedDistance += segment.length;
	    stats.percentDone = (stats.completedDistance * 1.0) / stats.length;
	}
	trailStats[segment.trailId] = stats;
	updatedTrails[segment.trailId] = stats;
    });

    return updatedTrails;
}

function getSegmentsForTrail(trailId) {
    let answer = trailSegments[trailId];
    if (answer) {
	return answer;
    }

    var trails = [];
    for (var segmentId in encodedSegments) {
	let segment = encodedSegments[segmentId];
	let trail = trails[segment.trailId] || {
	    trailId: segment.trailId,
	    name: segment.trailName,
	    segments: [],
	    length: 0,
	};

	trail.segments.push(segment.segmentId);
	trail.length += segment.length;
	segments[segment.trailId] = trail;
    };

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
    var locations = segmentData[segmentId];
    if (locations) {
	return locations;
    }

    var encoded = encodedSegments[segmentId].encodedLocations;
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
    var bounds = boundsForLocations(activity);
    var llGrid = new LatLngGrid(bounds);
    var tiles = new Set(activity.map(location => llGrid.locationToTileCoordinates(location).toString()));
    var fatTiles = new Set();

    for (let tile of tiles) {
	var neighbors = getNeighbors(tile);
	for (let neighbor of neighbors) {
	    fatTiles.add(neighbor.toString());
	}
    }

    var completedSegments = [];
    for (let segmentId of segments) {
	var locations = getSegmentLocations(segmentId);
	var count = 0;
	for (let location of locations) {
	    let coords = llGrid.locationToTileCoordinates(location).toString();
	    if (fatTiles.has(coords)) {
		count++;
	    }
	}

	var score = (count * 1.0) / locations.length;
	if (score >= MATCH_THRESHOLD) {
	    completedSegments.push(segmentId);
	}
    }
    return completedSegments;
}


class LatLngBounds {
    constructor(minLat, minLng, maxLat, maxLng) {
	this.minLat = minLat;
	this.minLng = minLng;
	this.maxLat = maxLat;
	this.maxLng = maxLng;

	// southwest to northwest
	r = geod.Inverse(minLat, minLng, maxLat, minLng);
	this.latSpanMeters = r.s12;

	// southwest to southeast
	r = geod.Inverse(minLat, minLng, minLat, maxLng);
	this.lngSpanMeters = r.s12;
    }

    getLatitudeSpanMeters() {
	return this.latSpanMeters;
    }

    getLongtitudeSpanMeters() {
	return this.lngSpanMeters;
    }
}

function boundsForLocations(locations) {
    var lats = locations.map(l => l[0]);
    var lngs = locations.map(l => l[1]);

    return new LatLngBounds(Math.min(...lats), Math.min(...lngs), Math.max(...lats), Math.max(...lngs));
}

class LatLngGrid {
    constructor(bounds) {
	const cellSizeMeters = 15;

	var latMeters = bounds.getLatitudeSpanMeters();
	var lngMeters = bounds.getLongtitudeSpanMeters();

	var northSouthDegrees = bounds.maxLat - bounds.minLat;
	var eastWestDegrees = bounds.maxLng - bounds.minLng;
	
	this.nsNumCells = Math.ceil(latMeters / cellSizeMeters);
	this.ewNumCells = Math.ceil(lngMeters / cellSizeMeters);

	var latDegreesPerCell = northSouthDegrees / this.nsNumCells;
	var lngDegreesPerCell = eastWestDegrees / this.ewNumCells;

	// This is to make the grid one cell bigger in each dimension

	this.minLat = bounds.minLat - latDegreesPerCell;
	var maxLat = bounds.maxLat + latDegreesPerCell;
	this.minLng = bounds.minLng - lngDegreesPerCell;
	var maxLng = bounds.maxLng + lngDegreesPerCell;

	this.latDegrees = maxLat - this.minLat;
	this.lngDegrees = maxLng - this.minLng;
    }

    locationToTileCoordinates(location) {
	var y = Math.round(((location[0] - this.minLat) / this.latDegrees) * this.nsNumCells);
	var x = Math.round(((location[1] - this.minLng) / this.lngDegrees) * this.ewNumCells);
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
	var y;
	var x;
	var result = [];
	for (y = this.y - 1;  y <= this.y + 1; ++y) {
	    for (x = this.x - 1;  x <= this.x + 1; ++x) {
		result.push(new Coordinates(x, y));
	    }
	}
	return result;
    }
}

function getNeighbors(locString) {
    var strs = locString.split(",");
    var x = parseInt(strs[0]);
    var y = parseInt(strs[1]);

    var c = new Coordinates(x, y);
    return c.getNeighbors();
}
