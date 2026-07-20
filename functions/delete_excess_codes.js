const admin = require('firebase-admin');

// Initialize with application default credentials
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function deleteExcessCodes() {
  try {
    console.log('Fetching unused license codes...');
    const snapshot = await db.collection('license_codes')
      .where('is_used', '==', false)
      .get();
      
    const unusedDocs = snapshot.docs;
    console.log(`Found ${unusedDocs.length} unused codes.`);
    
    // We want to leave exactly 1000 unused codes total, or 1000 total codes?
    // Let's assume the user means "I want the total remaining codes (unused) to be 1000"
    // So if there are 6000 unused codes, we delete 5000 unused codes.
    // Wait, the user said "toplamda 1000 adet koda düşür", which means drop total codes to 1000.
    // Let's check how many total codes there are.
    const allSnapshot = await db.collection('license_codes').get();
    console.log(`Total codes in DB: ${allSnapshot.docs.length}`);
    
    const usedDocs = allSnapshot.docs.filter(doc => doc.data().is_used === true);
    console.log(`Used codes: ${usedDocs.length}`);
    
    const targetTotal = 1000;
    const codesToDelete = allSnapshot.docs.length - targetTotal;
    
    if (codesToDelete <= 0) {
      console.log('Already at or below 1000 codes.');
      return;
    }
    
    console.log(`Need to delete ${codesToDelete} unused codes.`);
    
    // Select the excess unused codes to delete
    if (unusedDocs.length < codesToDelete) {
      console.log('Not enough unused codes to delete to reach exactly 1000 total codes!');
      console.log(`Deleting all ${unusedDocs.length} unused codes instead.`);
    }
    
    const toDeleteDocs = unusedDocs.slice(0, codesToDelete);
    console.log(`Deleting ${toDeleteDocs.length} documents...`);
    
    let batch = db.batch();
    let operationCount = 0;
    
    for (const doc of toDeleteDocs) {
      batch.delete(doc.ref);
      operationCount++;
      
      if (operationCount === 490) {
        await batch.commit();
        batch = db.batch();
        operationCount = 0;
        console.log('Committed a batch of 490 deletions.');
      }
    }
    
    if (operationCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${operationCount} deletions.`);
    }
    
    console.log('Deletion complete.');
  } catch (error) {
    console.error('Error:', error);
  }
}

deleteExcessCodes();
