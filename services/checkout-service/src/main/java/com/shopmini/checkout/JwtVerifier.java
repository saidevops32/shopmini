package com.shopmini.checkout;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.crypto.MACVerifier;
import com.nimbusds.jwt.SignedJWT;
import java.nio.charset.StandardCharsets;
import java.text.ParseException;
import java.util.Date;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Verifies HS256 tokens issued by auth-service. Fails closed: any problem means "not authenticated". */
@Component
public class JwtVerifier {
    private final MACVerifier verifier;

    // no default value: if jwt-secret is missing the service refuses to start
    public JwtVerifier(@Value("${jwt-secret}") String secret) {
        try {
            this.verifier = new MACVerifier(secret.getBytes(StandardCharsets.UTF_8));
        } catch (JOSEException e) {
            throw new IllegalStateException("jwt-secret is unusable (must be at least 32 bytes)", e);
        }
    }

    /** @return the user id (the "sub" claim) for a valid, unexpired token, otherwise empty */
    public Optional<String> verify(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            return Optional.empty();
        }
        try {
            SignedJWT jwt = SignedJWT.parse(authorizationHeader.substring(7));
            if (!JWSAlgorithm.HS256.equals(jwt.getHeader().getAlgorithm())) return Optional.empty();
            if (!jwt.verify(verifier)) return Optional.empty();
            Date exp = jwt.getJWTClaimsSet().getExpirationTime();
            if (exp == null || exp.before(new Date())) return Optional.empty();
            return Optional.ofNullable(jwt.getJWTClaimsSet().getSubject());
        } catch (ParseException | JOSEException e) {
            return Optional.empty();
        }
    }
}
