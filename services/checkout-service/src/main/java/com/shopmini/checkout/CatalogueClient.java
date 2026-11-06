package com.shopmini.checkout;

import java.math.BigDecimal;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** Asks catalogue-service for the real price; the client's idea of the price is never trusted. */
@Component
public class CatalogueClient {

    // mirrors every field catalogue-service returns, so no unknown-property handling is needed
    public record Product(Long id, String name, String description, BigDecimal price, int stock) {}

    public static class CatalogueUnavailableException extends RuntimeException {
        public CatalogueUnavailableException(Throwable cause) {
            super("catalogue unavailable", cause);
        }
    }

    private final RestClient client;

    public CatalogueClient(@Value("${catalogue.base-url}") String baseUrl) {
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(3));
        this.client = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    /** empty = no such product; throws CatalogueUnavailableException if the catalogue cannot be reached */
    public Optional<Product> find(long id) {
        try {
            return Optional.ofNullable(client.get()
                    .uri("/api/catalogue/products/{id}", id)
                    .retrieve()
                    .body(Product.class));
        } catch (HttpClientErrorException.NotFound e) {
            return Optional.empty();
        } catch (RestClientException e) {
            throw new CatalogueUnavailableException(e);
        }
    }
}
