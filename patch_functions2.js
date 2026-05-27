const fs = require('fs');
const file = 'functions/src/index.ts';
let code = fs.readFileSync(file, 'utf8');

code = code.replace(/await _unlockBadgeInTx\(\s*tx,\s*uid,\s*userRef,\s*"primeiro_duelo",\s*unlockedBadgeIds\s*\);/, `if (!unlockedBadgeIds.includes("primeiro_duelo")) {
          updates.unlockedBadgeIds = admin.firestore.FieldValue.arrayUnion("primeiro_duelo");
        }`);

fs.writeFileSync(file, code);
