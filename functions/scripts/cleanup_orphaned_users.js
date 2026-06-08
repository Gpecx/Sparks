const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

async function runCleanup() {
  const isDryRun = process.argv.includes("--dry-run");
  console.log(`Starting cleanup... Dry Run: ${isDryRun}`);

  // 1. Get all Auth users
  console.log("Fetching all Firebase Auth users...");
  const authUids = new Set();
  let nextPageToken;
  do {
    const listUsersResult = await auth.listUsers(1000, nextPageToken);
    listUsersResult.users.forEach((userRecord) => authUids.add(userRecord.uid));
    nextPageToken = listUsersResult.pageToken;
  } while (nextPageToken);
  console.log(`Found ${authUids.size} users in Firebase Auth.`);

  // 2. Scan `users` collection to find orphans
  console.log("Scanning 'users' collection in Firestore...");
  const usersSnapshot = await db.collection("users").get();
  console.log(`Found ${usersSnapshot.size} documents in 'users' collection.`);

  const orphanedUids = [];
  usersSnapshot.forEach((doc) => {
    if (!authUids.has(doc.id)) {
      orphanedUids.push(doc.id);
    }
  });

  console.log(`Found ${orphanedUids.length} orphaned UIDs:`, orphanedUids);

  if (orphanedUids.length === 0) {
    console.log("No orphaned users found. Exiting.");
    return;
  }

  // 3. Scan other collections
  for (const uid of orphanedUids) {
    console.log(`\nProcessing orphaned UID: ${uid}`);

    // A. Users collection and its subcollections (simplified, deleting doc only for dry run or if not recursive)
    // Note: To fully delete subcollections in Firestore, we should list them.
    if (!isDryRun) {
      await db.collection("users").doc(uid).delete();
      console.log(` - Deleted users/${uid}`);
    } else {
      console.log(` - [DRY RUN] Would delete users/${uid}`);
    }

    // B. Public Profiles
    const profileRef = db.collection("public_profiles").doc(uid);
    const profileSnap = await profileRef.get();
    if (profileSnap.exists) {
      if (!isDryRun) {
        await profileRef.delete();
        console.log(` - Deleted public_profiles/${uid}`);
      } else {
        console.log(` - [DRY RUN] Would delete public_profiles/${uid}`);
      }
    }

    // C. Clans (check if member)
    const clansQuery = await db.collection("clans").where("members", "array-contains", uid).get();
    for (const clanDoc of clansQuery.docs) {
      const clanData = clanDoc.data();
      if (!isDryRun) {
        await clanDoc.ref.update({
          members: admin.firestore.FieldValue.arrayRemove(uid)
        });
        console.log(` - Removed from clan ${clanDoc.id}`);
        // If leader, we might need a leadership transfer, but ignoring for now.
        if (clanData.leaderId === uid) {
          console.log(`   WARNING: Orphaned user was leader of clan ${clanDoc.id}!`);
        }
      } else {
        console.log(` - [DRY RUN] Would remove from clan ${clanDoc.id}`);
        if (clanData.leaderId === uid) {
          console.log(`   [DRY RUN] WARNING: Orphaned user is leader of clan ${clanDoc.id}!`);
        }
      }
    }

    // D. Global Rankings
    // Iterate through some known ranking documents
    const rankingDocs = ["all_time", "current_month", "current_week"];
    for (const rDoc of rankingDocs) {
      const rRef = db.collection("rankings").doc(rDoc).collection("users").doc(uid);
      const rSnap = await rRef.get();
      if (rSnap.exists) {
        if (!isDryRun) {
          await rRef.delete();
          console.log(` - Deleted from ranking ${rDoc}`);
        } else {
          console.log(` - [DRY RUN] Would delete from ranking ${rDoc}`);
        }
      }
    }
  }

  console.log("\nCleanup script finished!");
}

runCleanup().catch(console.error);
