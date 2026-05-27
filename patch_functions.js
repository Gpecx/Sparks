const fs = require('fs');
const file = 'functions/src/index.ts';
let code = fs.readFileSync(file, 'utf8');

code = code.replace(/async function _unlockBadgeInTx[\s\S]*?return true;\n}/, `// Removido _unlockBadgeInTx para evitar multiplos updates na mesma transacao`);

code = code.replace(/tx\.update\(userRef, {\s*xp: admin\.firestore\.FieldValue\.increment\(amount\),[\s\S]*?updatedAt: admin\.firestore\.FieldValue\.serverTimestamp\(\),\s*}\);/, `const userUpdates: Record<string, any> = {
        xp: admin.firestore.FieldValue.increment(amount),
        weeklyXp: admin.firestore.FieldValue.increment(amount),
        monthlyXp: admin.firestore.FieldValue.increment(amount),
        level: newLevel,
        tensionLevel: newTension,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };`);

code = code.replace(/const badgesToCheck = xpBadgesEarned\(newXp\);\s*const badgesUnlocked: string\[\] = \[\];\s*for \(const badge of badgesToCheck\) {[\s\S]*?}\s*result = { newXp, newLevel, newTension, leveledUp, badgesUnlocked };/, `const badgesToCheck = xpBadgesEarned(newXp);
      const badgesUnlocked: string[] = [];

      const newBadges = badgesToCheck.filter(b => !unlockedBadgeIds.includes(b));
      if (newBadges.length > 0) {
        userUpdates.unlockedBadgeIds = admin.firestore.FieldValue.arrayUnion(...newBadges);
        badgesUnlocked.push(...newBadges);
      }

      // Executa o update unico
      tx.update(userRef, userUpdates);

      result = { newXp, newLevel, newTension, leveledUp, badgesUnlocked };`);

// Also fix unlockBadge to avoid _unlockBadgeInTx
code = code.replace(/unlocked = await _unlockBadgeInTx\([\s\S]*?\);/, `if (!unlockedBadgeIds.includes(badgeId)) {
        tx.update(userRef, {
          unlockedBadgeIds: admin.firestore.FieldValue.arrayUnion(badgeId),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        unlocked = true;
      }`);

fs.writeFileSync(file, code);
