package com.shopmini.checkout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import org.junit.jupiter.api.Test;

class JwtVerifierTest {
    private static final String KEY = "k".repeat(40);
    private final JwtVerifier verifier = new JwtVerifier(KEY);

    private static String token(String key, String sub, Date expires) throws Exception {
        JWTClaimsSet claims = new JWTClaimsSet.Builder().subject(sub).expirationTime(expires).build();
        SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claims);
        jwt.sign(new MACSigner(key.getBytes(StandardCharsets.UTF_8)));
        return jwt.serialize();
    }

    private static Date in(long ms) { return new Date(System.currentTimeMillis() + ms); }

    @Test
    void acceptsValidToken() throws Exception {
        assertEquals("7", verifier.verify("Bearer " + token(KEY, "7", in(60_000))).orElseThrow());
    }

    @Test
    void rejectsTokenSignedWithAnotherKey() throws Exception {
        assertTrue(verifier.verify("Bearer " + token("w".repeat(40), "7", in(60_000))).isEmpty());
    }

    @Test
    void rejectsExpiredToken() throws Exception {
        assertTrue(verifier.verify("Bearer " + token(KEY, "7", in(-60_000))).isEmpty());
    }

    @Test
    void rejectsMissingOrMalformedHeader() {
        assertTrue(verifier.verify(null).isEmpty());
        assertTrue(verifier.verify("Basic abc").isEmpty());
        assertTrue(verifier.verify("Bearer not-a-jwt").isEmpty());
    }
}
