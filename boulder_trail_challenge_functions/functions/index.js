// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//

// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to access Firestore.
const admin = require('firebase-admin');
admin.initializeApp();

var rp = require('request-promise');

// exports.helloWorld = functions.https.onRequest((request, response) => {
//     functions.logger.info("Hello logs!", {structuredData: true});
//     response.send("Hello from Firebase!");
// });


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

// Take the text parameter passed to this HTTP endpoint and insert it into 
// Firestore under the path /messages/:documentId/original
exports.getStats = functions.https.onRequest(async (request, response) => {
    // Grab the text parameter.
    const athlete = request.query.athlete;
    var result = "";

    const stats = await admin.firestore().collection('athletes').doc('dkhawk@gmail.com').get().then(documentSnapshot => {
	if (documentSnapshot.exists) {
	    console.log('Document retrieved successfully.');
	    result = documentSnapshot.data();
	}
    });
    
    // Push the new message into Firestore using the Firebase Admin SDK.
    // const writeResult = await admin.firestore().collection('messages').add({original: original});
    // Send back a message that we've successfully written the message
    // response.json({result: `stats: ${stats}.`});
    response.json({result: result});
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
			code: tokenInfo.refresh_token,
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
    const after = 1609459200;  // 2021-01-01 0:00.  Need to pass this in as a parameter.

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


function processActivity(activityId) {
    // grab the locations stream
    
    // process
    // return result
}
