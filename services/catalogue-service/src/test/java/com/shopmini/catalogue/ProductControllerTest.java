package com.shopmini.catalogue;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ProductController.class)
class ProductControllerTest {

    @Autowired MockMvc mvc;
    @MockitoBean ProductRepository repo;

    @Test
    void listReturnsProducts() throws Exception {
        Product p = new Product("Mouse", "test", new BigDecimal("599.00"), 3);
        when(repo.findAll(PageRequest.of(0, 100))).thenReturn(new PageImpl<>(List.of(p)));
        mvc.perform(get("/api/catalogue/products"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[0].name").value("Mouse"));
    }

    @Test
    void unknownIdReturns404() throws Exception {
        when(repo.findById(99L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/catalogue/products/99"))
           .andExpect(status().isNotFound());
    }
}
