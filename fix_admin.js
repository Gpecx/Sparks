const admin = require('firebase-admin');
const app = admin.initializeApp({ projectId: 'spark-v1-e0eb5' });
const db = admin.firestore();

async function fix() {
  const clanId = '1Bn9AgioRmDZaLzSCBtd';
  const uid = 'UK0YSmASDJbXjq6XMTwTGJFr2ah1';
  
  await db.collection('clans').doc(clanId).collection('members').doc(uid).set({
    role: 'admin'
  }, { merge: true });
  
  console.log('Done fixing role.');
}
fix().catch(console.error).finally(() => process.exit(0));
