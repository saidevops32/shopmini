package com.shopmini.checkout;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.math.BigDecimal;

@Embeddable
public class OrderLine {
    @Column(name = "product_id")
    private Long productId;
    private String name;
    @Column(name = "unit_price")
    private BigDecimal unitPrice;
    private int quantity;

    protected OrderLine() {}

    public OrderLine(Long productId, String name, BigDecimal unitPrice, int quantity) {
        this.productId = productId;
        this.name = name;
        this.unitPrice = unitPrice;
        this.quantity = quantity;
    }

    public Long getProductId() { return productId; }
    public String getName() { return name; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public int getQuantity() { return quantity; }
}
