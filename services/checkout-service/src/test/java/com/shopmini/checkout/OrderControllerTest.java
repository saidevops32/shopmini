package com.shopmini.checkout;

import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(OrderController.class)
class OrderControllerTest {
    private static final String BODY = "{\"items\":[{\"productId\":1,\"quantity\":2}]}";

    @Autowired MockMvc mvc;
    @MockitoBean JwtVerifier jwt;
    @MockitoBean CatalogueClient catalogue;
    @MockitoBean OrderService service;
    @MockitoBean OrderRepository orders;

    @Test
    void noTokenIs401() throws Exception {
        mvc.perform(post("/api/checkout/orders").contentType(MediaType.APPLICATION_JSON).content(BODY))
           .andExpect(status().isUnauthorized());
    }

    @Test
    void emptyItemsIs400() throws Exception {
        when(jwt.verify("Bearer t")).thenReturn(Optional.of("7"));
        mvc.perform(post("/api/checkout/orders").header("Authorization", "Bearer t")
                .contentType(MediaType.APPLICATION_JSON).content("{\"items\":[]}"))
           .andExpect(status().isBadRequest());
    }

    @Test
    void unknownProductIs400() throws Exception {
        when(jwt.verify("Bearer t")).thenReturn(Optional.of("7"));
        mvc.perform(post("/api/checkout/orders").header("Authorization", "Bearer t")
                .contentType(MediaType.APPLICATION_JSON).content(BODY))
           .andExpect(status().isBadRequest());
    }

    @Test
    void catalogueDownIs503() throws Exception {
        when(jwt.verify("Bearer t")).thenReturn(Optional.of("7"));
        when(catalogue.find(1L)).thenThrow(new CatalogueClient.CatalogueUnavailableException(new RuntimeException("x")));
        mvc.perform(post("/api/checkout/orders").header("Authorization", "Bearer t")
                .contentType(MediaType.APPLICATION_JSON).content(BODY))
           .andExpect(status().isServiceUnavailable());
    }

    @Test
    void validOrderIs201() throws Exception {
        when(jwt.verify("Bearer t")).thenReturn(Optional.of("7"));
        when(catalogue.find(1L)).thenReturn(Optional.of(
                new CatalogueClient.Product(1L, "Mouse", "test", new BigDecimal("599.00"), 5)));
        ShopOrder saved = mock(ShopOrder.class);
        when(saved.getId()).thenReturn(42L);
        when(saved.getTotal()).thenReturn(new BigDecimal("1198.00"));
        when(service.create(eq("7"), anyList())).thenReturn(saved);
        mvc.perform(post("/api/checkout/orders").header("Authorization", "Bearer t")
                .contentType(MediaType.APPLICATION_JSON).content(BODY))
           .andExpect(status().isCreated())
           .andExpect(jsonPath("$.orderId").value(42));
    }

    @Test
    void someoneElsesOrderIs404() throws Exception {
        when(jwt.verify("Bearer t")).thenReturn(Optional.of("7"));
        // the repository finds nothing for (order 9, user 7), so it must not leak that order 9 exists
        mvc.perform(get("/api/checkout/orders/9").header("Authorization", "Bearer t"))
           .andExpect(status().isNotFound());
    }
}
