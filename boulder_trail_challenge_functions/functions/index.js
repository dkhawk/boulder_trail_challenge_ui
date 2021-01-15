// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//

// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to access Firestore.
const admin = require('firebase-admin');
admin.initializeApp();

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

// const gpxParser = require('./GPXParser.js');

var rp = require('request-promise');

// exports.helloWorld = functions.https.onRequest((request, response) => {
//     functions.logger.info("Hello logs!", {structuredData: true});
//     response.send("Hello from Firebase!");
// });

const stravaApiCredentials = {
    client_id: '43792',
    client_secret: 'b5cc7b11df2bf0390406f4bcc88592f7944880e9',
};

var btcApi = {
    getStravaInfo: async (athleteId) => {
    	return admin.firestore().collection('athletes').doc(athleteId).get().then(documentSnapshot => {
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
    const btcAthlete = request.query.athleteId;
    const activityId = request.query.activityId;

    // fetchActivity(btcAthlete, activityId);

    processActivity(testActivity);

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

    return segSet;
}

function locationToCoordinates(location) {
    var y = Math.round(((location[0] - minLat) / latDegrees) * height);
    var x = Math.round(((location[1] - minLng) / lngDegrees) * width);

    return `${x},${y}`;
}

function processActivity(activity) {
    var segments = candidateSegments(activity);

    // console.log(segments);

    var scores = scoreSegments(activity, segments);
}

function scoreSegments(activity, segments) {
    
}
