function validEmail(e) {
  return typeof e === 'string' && e.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
}

// bcrypt only uses the first 72 bytes, so longer passwords are rejected
function validPassword(p) {
  return typeof p === 'string' && p.length >= 8 && p.length <= 72;
}

module.exports = { validEmail, validPassword };
