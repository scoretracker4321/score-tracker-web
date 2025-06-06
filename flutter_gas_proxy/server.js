const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto'); // For guest link token generation

// Firebase Admin SDK imports
const admin = require('firebase-admin');

// --- Global Variables & Configuration ---
const __app_id = process.env.APP_ID || 'scoretrackerapp-16051';
const BACKUP_DIR = path.join(__dirname, 'backups'); // Ensure this matches your actual backup directory
const MAX_BACKUPS = 10; // <<<--- SET YOUR DESIRED LIMIT HERE (e.g., 5, 10, 20)

// IMPORTANT: Adjust this path based on the *relative path* from your server.js to your Flutter project's build/web directory.
// Given your structure (server.js, build, data folders in C:\Users\amulr\score_tracker), this should be correct:
const FLUTTER_WEB_BUILD_PATH = path.join(__dirname, 'build', 'web');
const PORT = 3000;

// Firebase Admin SDK initialization variables (from Canvas environment)
const __firebase_config = process.env.FIREBASE_CONFIG || '{}';
const __initial_auth_token = process.env.INITIAL_AUTH_TOKEN || '';

let firebaseConfig;
try {
    firebaseConfig = JSON.parse(__firebase_config);
    if (!firebaseConfig.projectId) {
        console.warn('projectId missing in __firebase_config. Using __app_id as fallback for Admin SDK.');
        firebaseConfig.projectId = __app_id;
    }
} catch (e) {
    console.error('Failed to parse __firebase_config for Node.js server:', e);
    firebaseConfig = { projectId: __app_id }; // Fallback with projectId
}

// Initialize Firebase Admin SDK directly with service account key content
try {
    const serviceAccount = {
  "type": "service_account",
  "project_id": "scoretrackerapp-16051",
  "private_key_id": "3d590f72bfe4efcbaf4b86a29ab169e214c5b8b6",
  // IMPORTANT: Ensure your private_key is correctly formatted within backticks.
  "private_key": `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCbNl3JvCF5Kt5M
kTBrC3izk+5ek6zuNeElnvC+e3fWCNogjdNVazNGVAtNtBALcHGDezPbrwS+Y0uE
RjjtdNiXHceeNVTWHxnTuuMIa29bZazys73ElJoaPgQTTh3A9eJTJjxcOpTephZp
ixDjDNP1PR4twV4C5m/gVZwEjzK4ec3E4PcdsgAO0Dxf6FBT4ZTDHVDy4yvuMKGL
HUiypq0RAmkyWWwUb0YE5q0PsBlxJ91qmRfh6KZ9eowXMqz+gV0zPcJEwvzvd+9B
0gT+bVML7hl7Or6GXOQv6GFxCo+2wZXQAH72DnQ6xAw46bQlreDyTxiTEkhc7nGn
U5Qr4GEBAgMBAAECggEADudgiB+Fg1IHeIi0goLeezfoOrKpd1I7JVamvVOzxRyi
fV/A/EHH8afeUf7JT5/jdoGdECo1JWb5eGEZ1EtVBOW6JknutITWAQvAAy31ymvv
+Hoj7b1rMrvjvkrQ9pdlvSA9yYlihCKkokvVOkggDjtpK3GW6mZgNcVirtllQGtj
eyL3GTyVrOdIX/uGe+PUh6jV7m6V4hdC5ZoAjkAttupEm9uMeheT4ZDYHs0tkqXN
Aj44X27mgS/c0bPXYoKQKvjorsL+3glNoBHtNXPZcKBGYlWxeNILX00ASmKC+I2v
df984CVtJHDEfsWJI9nFZhjcsQbUCeQVTdZSjrjh8QKBgQDJh2NgnK/pY+asUBK/
LWlQF+QM6PfcYgfuXmItqD0bwgo59yZ7KOkNqNgmUEvXUH4Cs+NAR/TfPw1KWXyF
xq28xcrayFk1JWo8TSDFKjPYGCpgojEQh27jRr3TAhR2sEgnTR7z/fFwroKtktdi
+YN2QecZJt/EnSEkvIxc9q2q7QKBgQDFKiY89XKSmaAAc0KxWh7q6JhaE5R8jYlG
ZtOB3qbAflzOSRCDGSpIv3MPSNZuo4QoaTSTjsENfq+6VapkoXmdWtBxHsfZE7fg
tK4bCeuAOKXH9LziKuJHo7XHxtajNogTcPveNzIn4XF0zCWaYYqn4JoAkPN1Mnlo
/VfwgQIH5QKBgEBHDXxYHYd8VKurEn+llUx1gkhX2g6RuePeeMQFQBBlcGuSl9R6
dPLlYqO9wqLXSonEJHxxNvopmyyWpC/q8akfERd9BW79EwhOtWANmOGYu5N8x9d0
yvp0qsDtjedZTHo0j+XUnjiJgKaqCkbIPJTwaixMiNymHVchSEeyaiv1AoGBAKtR
rpw1YnLEDmWVwZO9jTPtG8TZUqLPkUKdQpeMUjTdF+MfVbu0eCtyP5Y+YiUM7F74
23iECHejZypwGXkLXlM+f/RrHJghLBuSo95Wxk1J67NNk3qqbKh3NhL7UbHMRn0u
JYy3RVul5yHn6Zy1uPeaj/aB/SoOy7RQvsL6NjuJAoGBAIWfhh+sEs1x3QgnWsm+
jVzeLkEVXWfMAUrVMrXSHq0u2gvgy9PJl53PfoHUsnX1Tb0W9EdBjs7L+ajttNG9
JVUNY3aHQ5cZzRt7oL1qEiHW/IL7bnZfE45VrZWGUavPn6OkCqQf3ALzuKfLYi63
GDwiEjq/+nnRw92OzdZMxw2L
-----END PRIVATE KEY-----`,
  "client_email": "firebase-adminsdk-fbsvc@scoretrackerapp-16051.iam.gserviceaccount.com",
  "client_id": "115978522603167722494",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://www.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40scoretrackerapp-16051.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
};

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: firebaseConfig.projectId,
    });
    console.log('Firebase Admin SDK initialized successfully using service account key.');
} catch (e) {
    console.error('Failed to initialize Firebase Admin SDK with service account key:', e);
    console.error('--- IMPORTANT ---');
    console.error('Please ensure you have correctly copied the entire content of your service account key JSON file into the "serviceAccount" object in server.js.');
    console.error('Error details:', e);
    process.exit(1);
}

const db = admin.firestore(); // Firestore instance

// --- File System Paths (ONLY for server-side backups) ---
const BACKUPS_DIR = path.join(__dirname, 'data', 'backups');

async function ensureDataDirectories() {
    console.log('Ensuring backup directories exist...');
    try {
        await fs.mkdir(BACKUPS_DIR, { recursive: true });
        console.log('Backup directories checked/created.');
    } catch (err) {
        console.error('Failed to ensure backup directories:', err);
        throw err;
    }
}

// Helper function to log activity to Firestore
async function logActivity(action, details = {}) {
    console.log(`Logging activity to Firestore: ${action}`);
    try {
        await db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('activityLog').add({
            action: action,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            details: details,
        });
        console.log('Activity logged successfully to Firestore.');
    } catch (e) {
        console.error('Failed to write activity log to Firestore:', e);
    }
}

// --- Express App Setup ---
const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.text({ type: 'text/csv' }));

// --- API ROUTES (Define all your specific API endpoints first!) ---

// Manual Backup (reads from Firestore, saves to server's file system)
app.post('/backup', async (req, res) => {
    try {
        const studentsCollectionRef = admin.firestore().collection('artifacts').doc(__app_id).collection('public').doc('data').collection('students');
        const winnersCollectionRef = admin.firestore().collection('artifacts').doc(__app_id).collection('public').doc('data').collection('winners');
        const activityLogCollectionRef = admin.firestore().collection('artifacts').doc(__app_id).collection('public').doc('data').collection('activityLog');
        const guestLinksCollectionRef = admin.firestore().collection('artifacts').doc(__app_id).collection('public').doc('data').collection('guestLinks');

        const [studentsSnapshot, winnersSnapshot, activityLogSnapshot, guestLinksSnapshot] = await Promise.all([
            studentsCollectionRef.get(),
            winnersCollectionRef.get(),
            activityLogCollectionRef.get(),
            guestLinksCollectionRef.get()
        ]);

        const allStudents = studentsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        const allWinners = winnersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        const allActivities = activityLogSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        const allGuestLinks = guestLinksSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        const backupData = {
            timestamp: new Date().toISOString(),
            students: allStudents,
            winners: allWinners,
            activityLog: allActivities,
            guestLinks: allGuestLinks
        };

        const timestamp = new Date().toISOString().replace(/:/g, '-').split('.')[0];
        const filename = `backup_${timestamp}.json`;
        const filepath = path.join(BACKUP_DIR, filename);

        await fs.writeFile(filepath, JSON.stringify(backupData, null, 2));
        console.log(`Backup created: ${filename}`);

        // --- NEW: Backup Limit Logic ---
        let files = await fs.readdir(BACKUP_DIR);
        let backupFiles = [];
        for (const file of files) {
            if (file.startsWith('backup_') && file.endsWith('.json')) {
                const filePath = path.join(BACKUP_DIR, file);
                const stats = await fs.stat(filePath);
                backupFiles.push({ name: file, path: filePath, ctime: stats.ctime.getTime() });
            }
        }

        backupFiles.sort((a, b) => a.ctime - b.ctime);

        if (backupFiles.length > MAX_BACKUPS) {
            const filesToDelete = backupFiles.slice(0, backupFiles.length - MAX_BACKUPS);
            for (const file of filesToDelete) {
                await fs.unlink(file.path);
                console.log(`Deleted old backup: ${file.name}`);
            }
        }
        // --- END NEW: Backup Limit Logic ---

        res.status(200).json({ status: 'success', message: 'Backup created successfully.' });
    } catch (error) {
        console.error('Error creating backup:', error);
        res.status(500).json({ status: 'error', message: 'Failed to create backup.', error: error.message });
    }
});
app.post('/log-error', (req, res) => {
    const errorLog = req.body; // Expecting a JSON body with error details
    const timestamp = new Date().toISOString();
    const logFilePath = path.join(__dirname, 'app_errors.log'); // Log to a file in the server directory

    const logEntry = `[${timestamp}] - ERROR: ${JSON.stringify(errorLog)}\n`;

    fs.appendFile(logFilePath, logEntry, (err) => {
        if (err) {
            console.error('Failed to write error log to file:', err);
            return res.status(500).json({ status: 'error', message: 'Failed to write log' });
        }
        console.log('Error log received and saved.');
        res.status(200).json({ status: 'success', message: 'Error log received' });
    });
});
// Endpoint to retrieve guest view data - NOW USES QUERY PARAMETER
app.get('/guest/view-data', async (req, res) => { // Changed from /guest/view-data/:token to /guest/view-data
    const { token } = req.query; // Access token from query parameters
    console.log(`GET /guest/view-data?token=${token} endpoint hit.`);

    if (!token) {
        return res.status(400).json({ status: 'error', message: 'Token is required as a query parameter.' });
    }

    try {
        const guestLinksRef = db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('guestLinks');
        const studentsRef = db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('students');

        const guestLinkSnapshot = await guestLinksRef.where('token', '==', token).limit(1).get();

        if (guestLinkSnapshot.empty) {
            console.log(`Guest link not found for token: ${token}`);
            return res.status(404).json({ status: 'error', message: 'Invalid or expired guest link.' });
        }

        const guestLinkDoc = guestLinkSnapshot.docs[0].data();
        const expiryTime = guestLinkDoc.expiry.toDate();

        if (new Date() > expiryTime) {
            console.log(`Guest link expired for token: ${token}`);
            await guestLinkSnapshot.docs[0].ref.delete();
            return res.status(401).json({ status: 'error', message: 'Guest link has expired.' });
        }

        const classId = guestLinkDoc.classId;
        const studentsInClassSnapshot = await studentsRef.where('classId', '==', classId).get();

        const classData = studentsInClassSnapshot.docs.map(doc => {
            const data = doc.data();
            const history = data.history ? data.history.map(entry => ({
                ...entry,
                timestamp: entry.timestamp.toDate().toISOString()
            })) : [];
            return {
                id: doc.id,
                name: data.name,
                isGroup: data.isGroup,
                score: data.score,
                history: history,
                classId: data.classId,
                memberIds: data.memberIds || null,
            };
        });

        console.log(`Successfully fetched ${classData.length} items for class ${classId}.`);
        res.status(200).json({ status: 'success', classId: classId, data: classData });

    } catch (error) {
        console.error('Error fetching guest view data:', error);
        res.status(500).json({ status: 'error', message: 'Failed to load guest data.', error: error.message });
    }
});

// Get list of backups (from server's file system)
app.get('/backups', async (req, res) => {
    console.log('GET /backups endpoint hit (server-side list).');
    try {
        const files = await fs.readdir(BACKUP_DIR);
        const backups = [];
        for (const file of files) {
            if (file.startsWith('backup_') && file.endsWith('.json')) {
                const filePath = path.join(BACKUP_DIR, file);
                const stats = await fs.stat(filePath);
                backups.push({
                    filename: file,
                    timestamp: stats.mtime.toISOString(),
                });
            }
        }
        backups.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        res.status(200).json({ status: 'success', backups });
        console.log(`GET /backups successful. Found ${backups.length} backups.`);
    } catch (error) {
        console.error('Error listing server-side backups:', error);
        res.status(500).json({ status: 'error', message: 'Failed to retrieve backup list.' });
    }
});

// Get specific backup data (from server's file system)
app.get('/backup/:filename', async (req, res) => {
    console.log(`GET /backup/${req.params.filename} endpoint hit (server-side data).`);
    try {
        const { filename } = req.params;
        const backupFilePath = path.join(BACKUP_DIR, filename);
        const data = JSON.parse(await fs.readFile(backupFilePath, 'utf8'));
        res.status(200).json({ status: 'success', data });
        console.log(`GET /backup/${filename} successful.`);
    } catch (error) {
        console.error('Error retrieving specific server-side backup:', error);
        res.status(500).json({ status: 'error', message: 'Failed to retrieve backup data.' });
    }
});

// Restore from a specific backup (reads from server's file system, writes to Firestore)
app.post('/restore-specific/:filename', async (req, res) => {
    console.log(`POST /restore-specific/${req.params.filename} endpoint hit (server-side restore).`);
    try {
        const { filename } = req.params;
        const backupFilePath = path.join(BACKUP_DIR, filename);
        const backupData = JSON.parse(await fs.readFile(backupFilePath, 'utf8'));

        // Clear existing students collection in Firestore
        const currentStudentsSnapshot = await db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('students').get();
        const deleteBatch = db.batch();
        currentStudentsSnapshot.docs.forEach(doc => {
            deleteBatch.delete(doc.ref);
        });
        await deleteBatch.commit();
        console.log('Existing students collection cleared in Firestore.');

        // Add data from backup to Firestore
        const writeBatch = db.batch();
        let restoredCount = 0;
        // Assuming backupData is an array of student objects
        for (const item of backupData.students) { // Access backupData.students
            const docRef = db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('students').doc(item.id || uuidv4());
            const { id, ...dataWithoutId } = item;
            writeBatch.set(docRef, dataWithoutId);
            restoredCount++;
        }
        await writeBatch.commit();

        await logActivity('Restored from Backup (Server-side)', { filename, restoredCount });
        res.status(200).json({ status: 'success', message: `Data restored from ${filename} to Firestore successfully.` });
        console.log(`POST /restore-specific/${filename} successful. Restored ${restoredCount} items.`);
    } catch (error) {
        console.error('Error restoring from server-side backup:', error);
        res.status(500).json({ status: 'error', message: 'Failed to restore data from backup.' });
    }
});

// Generate guest view link (stores in Firestore, returns token)
app.post('/guest/generate-link', async (req, res) => {
    console.log('POST /guest/generate-link endpoint hit.');
    try {
        const { classId } = req.body;
        if (!classId) {
            return res.status(400).json({ status: 'error', message: 'Class ID is required to generate a guest link.' });
        }

        const guestLinksRef = db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('guestLinks');

        const existingLinkSnapshot = await guestLinksRef
            .where('classId', '==', classId)
            .where('expiry', '>', new Date())
            .limit(1)
            .get();

        if (!existingLinkSnapshot.empty) {
            const existingLink = existingLinkSnapshot.docs[0].data();
            // Changed link format to point to index.html with query params
            const fullLink = `${req.protocol}://${req.get('host')}/index.html?view=guest&token=${existingLink.token}`;
            console.log('Existing valid guest link found in Firestore.');
            return res.status(200).json({ status: 'success', message: 'Existing valid link found.', link: fullLink });
        }

        const token = crypto.randomBytes(16).toString('hex');
        const expiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days expiry

        const newGuestLink = { token, classId, expiry };
        await guestLinksRef.add(newGuestLink);

        // Changed link format to point to index.html with query params
        const fullLink = `${req.protocol}://${req.get('host')}/index.html?view=guest&token=${token}`;
        await logActivity('Generated Guest Link', { classId, token });
        res.status(200).json({ status: 'success', message: 'Guest link generated.', link: fullLink });
        console.log('POST /guest/generate-link successful.');
    } catch (error) {
        console.error('Error generating guest link:', error);
        res.status(500).json({ status: 'error', message: 'Failed to generate guest link.' });
    }
});

// Upload class template (CSV) - processes CSV and writes to Firestore
app.post('/upload-class-template', async (req, res) => {
    console.log('POST /upload-class-template endpoint hit.');
    try {
        const csvData = req.body;
        console.log('Received CSV data length:', csvData.length);

        const lines = csvData.split('\n').filter(line => line.trim() !== '');

        if (lines.length === 0) {
            console.error('CSV file is empty for upload.');
            return res.status(400).json({ status: 'error', message: 'CSV file is empty.' });
        }

        const headers = lines[0].split(',').map(h => h.trim());
        if (!headers.includes('name') || !headers.includes('isGroup (true/false)') || !headers.includes('classId')) {
            console.error('Missing required CSV headers.');
            return res.status(400).json({ status: 'error', message: 'CSV must contain "name", "isGroup (true/false)", and "classId" columns.' });
        }

        const newEntries = [];
        const errors = [];

        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            const entry = {};
            headers.forEach((header, index) => {
                entry[header] = values[index];
            });

            const isGroupString = entry['isGroup (true/false)'];
            const isGroup = isGroupString.toLowerCase() === 'true';

            if (!entry.name || !entry.classId) {
                errors.push(`Row ${i + 1}: Missing name or classId.`);
                continue;
            }

            const newStudentGroup = {
                name: entry.name,
                isGroup: isGroup,
                score: 100,
                history: [],
                classId: entry.classId,
                memberIds: isGroup ? [] : null,
            };
            newEntries.push(newStudentGroup);
        }

        if (errors.length > 0) {
            console.error('Errors found in CSV upload:', errors.join('; '));
            return res.status(400).json({ status: 'error', message: 'Errors in CSV: ' + errors.join('; ') });
        }

        const batch = db.batch();
        const studentsCollectionRef = db.collection('artifacts').doc(__app_id).collection('public').doc('data').collection('students');
        for (const entry of newEntries) {
            const newDocRef = studentsCollectionRef.doc();
	        batch.set(newDocRef, entry);
        }
        await batch.commit();

        await logActivity('Uploaded Class Template (Server-side)', { newEntriesCount: newEntries.length });
        res.status(200).json({ status: 'success', message: `${newEntries.length} entries added successfully to Firestore.` });
        console.log('POST /upload-class-template successful.');
    } catch (error) {
        console.error('Error uploading class template:', error);
        res.status(500).json({ status: 'error', message: 'Failed to upload class template.' });
    }
});

// --- STATIC FILE SERVING FOR FLUTTER WEB ---
// This should be the ONLY route serving your Flutter frontend.
// It will serve index.html for the root path and other assets.
app.use(express.static(FLUTTER_WEB_BUILD_PATH));
console.log(`Serving static files from: ${FLUTTER_WEB_BUILD_PATH}`);
// --- END STATIC FILE SERVING ---


// Initialize data directories and start server
ensureDataDirectories().then(() => {
    app.listen(PORT, () => {
        console.log(`Server running on http://localhost:${PORT}`);
    });
}).catch(err => {
    console.error('Failed to initialize server data directories:', err);
    process.exit(1);
});
