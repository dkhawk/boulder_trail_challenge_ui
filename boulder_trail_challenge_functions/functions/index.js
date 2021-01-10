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

    let tokenExchange = {
	client_id: '43792',
	client_secret: 'b5cc7b11df2bf0390406f4bcc88592f7944880e9',
	code: code,
	grant_type: 'authorization_code',
    };

    console.log(JSON.stringify(tokenExchange));

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
