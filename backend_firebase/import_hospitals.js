const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const geohash = require('ngeohash');

// Initialize Firebase Admin (uses default credentials or requires serviceAccount.json)
// For local execution, ensure GOOGLE_APPLICATION_CREDENTIALS is set, 
// or initialize with a service account key if needed.
// If run locally in an initialized firebase project, admin.initializeApp() works.

admin.initializeApp();
const db = admin.firestore();

const CSV_FILE = '../hospital_directory.csv';

async function importHospitals() {
    const hospitals = [];
    console.log('Reading CSV...');

    return new Promise((resolve, reject) => {
        fs.createReadStream(CSV_FILE)
            .pipe(csv())
            .on('data', (row) => {
                // Parse coordinates
                const coordsRaw = row['Location_Coordinates'];
                if (!coordsRaw || coordsRaw === 'NA') return; // Skip invalid
                
                const parts = coordsRaw.split(',');
                if (parts.length !== 2) return;
                
                const lat = parseFloat(parts[0].trim());
                const lng = parseFloat(parts[1].trim());

                if (isNaN(lat) || isNaN(lng)) return;

                // Build hospital map
                const hash = geohash.encode(lat, lng, 9);
                const hospital = {
                    name: row['Hospital_Name'] || 'Unknown Hospital',
                    location: {
                        latitude: lat,
                        longitude: lng
                    },
                    geoMap: {
                        geohash: hash,
                        geopoint: new admin.firestore.GeoPoint(lat, lng)
                    },
                    totalBeds: parseInt(row['Total_Num_Beds']) || 0,
                    availableBeds: parseInt(row['Total_Num_Beds']) || 0, // initially assume all are available
                    icuBeds: 0,
                    ventilators: 0,
                    hasTraumaCenter: (row['Specialties'] || '').toLowerCase().includes('trauma'),
                };

                hospitals.push(hospital);
            })
            .on('end', async () => {
                console.log(`Parsed ${hospitals.length} valid hospitals.`);
                
                // Firestore batch upload
                const batchSize = 400; // max batch is 500
                const colRef = db.collection('hospitals');
                
                let processed = 0;
                while (processed < hospitals.length) {
                    const batch = db.batch();
                    const currentChunk = hospitals.slice(processed, processed + batchSize);
                    
                    for (const hosp of currentChunk) {
                        const docRef = colRef.doc(); // Auto ID
                        batch.set(docRef, hosp);
                    }
                    
                    await batch.commit();
                    processed += currentChunk.length;
                    console.log(`Uploaded ${processed} / ${hospitals.length} hospitals...`);
                }
                
                console.log('Successfully imported all hospitals!');
                resolve();
            })
            .on('error', (err) => {
                console.error('Error parsing CSV', err);
                reject(err);
            });
    });
}

importHospitals().catch(console.error);
