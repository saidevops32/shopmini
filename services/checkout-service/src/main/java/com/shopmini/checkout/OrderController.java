package com.shopmini.checkout;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/checkout")
public class OrderController {
    public record Item(Long productId, int quantity) {}
    public record OrderRequest(List<Item> items) {}
    public record Created(Long orderId, BigDecimal total) {}
    public record OrderView(Long orderId, BigDecimal total, Instant createdAt, List<OrderLine> lines) {}

    private static final Pattern USER = Pattern.compile("[A-Za-z0-9_-]{1,64}");

    private final JwtVerifier jwt;
    private final CatalogueClient catalogue;
    private final OrderService service;
    private final OrderRepository orders;

    public OrderController(JwtVerifier jwt, CatalogueClient catalogue, OrderService service, OrderRepository orders) {
        this.jwt = jwt;
        this.catalogue = catalogue;
        this.service = service;
        this.orders = orders;
    }

    private Optional<String> userFrom(String auth) {
        return jwt.verify(auth).filter(u -> USER.matcher(u).matches());
    }

    private static ResponseEntity<Map<String, String>> error(int status, String message) {
        return ResponseEntity.status(status).body(Map.of("error", message));
    }

    @PostMapping("/orders")
    public ResponseEntity<?> place(@RequestHeader(value = "Authorization", required = false) String auth,
                                   @RequestBody OrderRequest req) {
        Optional<String> user = userFrom(auth);
        if (user.isEmpty()) return error(401, "invalid or missing token");

        List<Item> items = req == null ? null : req.items();
        if (items == null || items.isEmpty() || items.size() > 20) {
            return error(400, "items must contain 1 to 20 entries");
        }
        List<OrderLine> lines = new ArrayList<>();
        for (Item item : items) {
            if (item == null || item.productId() == null || item.quantity() < 1 || item.quantity() > 100) {
                return error(400, "each item needs a productId and a quantity from 1 to 100");
            }
            CatalogueClient.Product product;
            try {
                product = catalogue.find(item.productId()).orElse(null);
            } catch (CatalogueClient.CatalogueUnavailableException e) {
                return error(503, "catalogue unavailable, please try again");
            }
            if (product == null) return error(400, "unknown product " + item.productId());
            if (product.stock() < item.quantity()) return error(409, "not enough stock for " + product.name());
            lines.add(new OrderLine(product.id(), product.name(), product.price(), item.quantity()));
        }
        ShopOrder order = service.create(user.get(), lines);
        return ResponseEntity.status(201).body(new Created(order.getId(), order.getTotal()));
    }

    @GetMapping("/orders/{id}")
    public ResponseEntity<?> get(@RequestHeader(value = "Authorization", required = false) String auth,
                                 @PathVariable Long id) {
        Optional<String> user = userFrom(auth);
        if (user.isEmpty()) return error(401, "invalid or missing token");
        return orders.findByIdAndUserId(id, user.get())
                .<ResponseEntity<?>>map(o -> ResponseEntity.ok(
                        new OrderView(o.getId(), o.getTotal(), o.getCreatedAt(), o.getLines())))
                .orElseGet(() -> error(404, "order not found"));
    }
}
