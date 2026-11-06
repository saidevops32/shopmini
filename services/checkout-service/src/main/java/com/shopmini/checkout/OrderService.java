package com.shopmini.checkout;

import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {
    private final OrderRepository orders;
    private final OutboxRepository outbox;

    public OrderService(OrderRepository orders, OutboxRepository outbox) {
        this.orders = orders;
        this.outbox = outbox;
    }

    /** The order and its outbox row are saved in ONE transaction: both exist, or neither does. */
    @Transactional
    public ShopOrder create(String userId, List<OrderLine> lines) {
        BigDecimal total = lines.stream()
                .map(l -> l.getUnitPrice().multiply(BigDecimal.valueOf(l.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        ShopOrder order = orders.save(new ShopOrder(userId, total, lines));
        // Locale.ROOT: %d must never print locale-specific digits
        String payload = String.format(Locale.ROOT,
                "{\"orderId\":%d,\"userId\":\"%s\",\"total\":\"%s\"}",
                order.getId(), userId, total.toPlainString());
        outbox.save(new OutboxEvent(payload));
        return order;
    }
}
