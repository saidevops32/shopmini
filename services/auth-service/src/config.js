const fs = require('fs');

// Secrets come from files mounted by the Key Vault CSI driver.
// Environment variables are only a fallback for local testing.
function secret(fileName, envName) {
  try {
    return fs.readFileSync(`/mnt/secrets/${fileName}`, 'utf8').trim();
  } catch {
    return process.env[envName] || '';
  }
}

module.exports = { secret };
